import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zakoni/core/services/network_connectivity_service.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

const String _kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

/// 自适应网络分级缓存策略：
/// 1. Wi-Fi / 有线宽带环境：开启 150MB 解复用缓冲与 50MB 回退缓存。
///    一集 1080p 动画(约 250~450MB)在起播数分钟内即可预载 35%~60% 以上，前后拖拽免重新建连，秒切即播。
/// 2. 移动蜂窝网络环境：降级为 16MB 解复用缓冲与 4MB 回退缓存。
///    提供 1~2 分钟平滑防抖窗口的同时，防止点开即退时偷跑数十乃至上百兆宝贵的流量。
const int _kWifiBufferSize = 150 * 1024 * 1024; // 150MB
const int _kWifiMaxBytes = 150 * 1024 * 1024; // 150MB
const int _kWifiMaxBackBytes = 50 * 1024 * 1024; // 50MB

const int _kMobileBufferSize = 16 * 1024 * 1024; // 16MB
const int _kMobileMaxBytes = 16 * 1024 * 1024; // 16MB
const int _kMobileMaxBackBytes = 4 * 1024 * 1024; // 4MB

/// zakoni 视频播放引擎控制器
/// 封装 media_kit (libmpv) 底层驱动，支持 250ms 节流解耦、倍速变调修正、切片断流自动重试与弹幕联动
class ZakoniPlaybackController {
  ZakoniPlaybackController({
    this.danmakuController,
  });

  /// 关联的弹幕控制器
  final DanmakuController? danmakuController;

  /// 低频宏观控制状态
  final ValueNotifier<PlaybackCoreState> core =
      ValueNotifier<PlaybackCoreState>(const PlaybackCoreState());

  /// 高频时间线状态（250ms 节流）
  final ValueNotifier<PlaybackTimelineState> timeline =
      ValueNotifier<PlaybackTimelineState>(const PlaybackTimelineState());

  /// 视频渲染控制器（提供给 Video 组件）
  final ValueNotifier<VideoController?> videoControllerNotifier =
      ValueNotifier<VideoController?>(null);

  Player? _player;
  VideoController? _videoController;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _timelineThrottleTimer;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  Duration _lastBuffer = Duration.zero;

  Duration _pendingStart = Duration.zero;
  bool _disposed = false;
  String? _currentUri;
  double _preMuteVolume = 1.0;

  bool get isDisposed => _disposed;
  Player? get rawPlayer => _player;
  String? get currentUri => _currentUri;

  /// 初始化底层播放器实例与 mpv 原生配置
  Future<void> initialize() async {
    if (_player != null || _disposed) return;

    final isMetered = NetworkConnectivityService.instance.isMetered;
    core.value = core.value.copyWith(isMeteredNetwork: isMetered);
    final initialBufferSize = isMetered ? _kMobileBufferSize : _kWifiBufferSize;

    final player = Player(
      configuration: PlayerConfiguration(
        bufferSize: initialBufferSize,
        title: 'zakoni Player',
      ),
    );
    _player = player;

    _videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    videoControllerNotifier.value = _videoController;

    // 绑定底层播放器流事件与网络环境动态监听
    _subscriptions.addAll([
      player.stream.playing.listen(_onPlayingChanged),
      player.stream.buffering.listen(_onBufferingChanged),
      player.stream.completed.listen(_onCompletedChanged),
      player.stream.position.listen(_onPositionChanged),
      player.stream.duration.listen(_onDurationChanged),
      player.stream.buffer.listen(_onBufferChanged),
      player.stream.rate.listen(_onRateChanged),
      player.stream.error.listen(_onErrorChanged),
      NetworkConnectivityService.instance.onMeteredChanged.listen(_onNetworkMeteredChanged),
    ]);

    // 注入底层 mpv 增强属性
    await _configureNativeMpvProperties();
  }

  /// 配置底层 mpv 属性（变速变调不变音、断流自动重连、确保网络流可拖拽定位、自适应分级缓冲）
  Future<void> _configureNativeMpvProperties() async {
    final player = _player;
    if (player == null) return;

    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        // 1. scaletempo2 滤镜：倍速播放（1.25x~3.0x）时自动修正音高，人声音质不失真
        await platform.setProperty('af', 'scaletempo2=max-speed=8');

        // 2. 特殊处理说明：
        // 严禁在此处给 demuxer-lavf-o 覆盖注入 ignidx / igndts 等忽略索引参数。
        // ignidx 会导致 FFmpeg 丢弃 MP4/切片索引表，当用户点击或拖拽进度条时，底层找不到对应
        // 时间戳直接抛出 AVERROR_EOF，导致 mpv 误判为播放结束 (completed=true) 异常终止。
        // 维持 media_kit 原生协议白名单与重试策略，并显式声明网络流可 Seek 与启用默认精确定位。
        await platform.setProperty('force-seekable', 'yes');
        await platform.setProperty('hr-seek', 'default');

        // 3. 自适应分级解复用缓冲：
        // Wi-Fi 环境下预读 150MB + 后退 50MB，大幅减少拉条卡顿；
        // 移动网络下自适应降级为 16MB + 4MB，节约手机流量。
        final isMetered = NetworkConnectivityService.instance.isMetered;
        final maxBytes = isMetered ? _kMobileMaxBytes : _kWifiMaxBytes;
        final maxBackBytes = isMetered ? _kMobileMaxBackBytes : _kWifiMaxBackBytes;

        await platform.setProperty('demuxer-max-bytes', maxBytes.toString());
        await platform.setProperty('demuxer-max-back-bytes', maxBackBytes.toString());
        await platform.setProperty('network-timeout', '30');
        await platform.setProperty('volume-max', '100');
        await platform.setProperty('user-agent', _kDefaultUserAgent);

        if (Platform.isAndroid) {
          // Android 平台默认音频输出
          await platform.setProperty('ao', 'opensles');
        }
      }
    } catch (e) {
      debugPrint('[ZakoniPlayback] 配置 mpv 属性失败: $e');
    }
  }

  /// 网络环境动态变更（如播放中从 Wi-Fi 切换至 4G/5G 蜂窝数据或反之）：在线热更新 mpv 缓冲水线
  Future<void> _onNetworkMeteredChanged(bool isMetered) async {
    if (_disposed) return;
    core.value = core.value.copyWith(isMeteredNetwork: isMetered);

    final player = _player;
    if (player == null) return;

    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        final maxBytes = isMetered ? _kMobileMaxBytes : _kWifiMaxBytes;
        final maxBackBytes = isMetered ? _kMobileMaxBackBytes : _kWifiMaxBackBytes;
        await platform.setProperty('demuxer-max-bytes', maxBytes.toString());
        await platform.setProperty('demuxer-max-back-bytes', maxBackBytes.toString());
        debugPrint(
          '[ZakoniPlayback] 网络类型动态变更，已热更新解复用缓冲: '
          '${isMetered ? "移动蜂窝数据模式(16MB)" : "高速Wi-Fi/有线模式(150MB)"}',
        );
      }
    } catch (e) {
      debugPrint('[ZakoniPlayback] 动态热更新解复用缓冲失败: $e');
    }
  }

  /// 打开媒体流并起播
  /// [uri] 媒体播放直链（mp4 / m3u8 等）
  /// [httpHeaders] 防盗链请求头（如 Referer / User-Agent）
  /// [start] 起播定位时间戳（用于历史进度记忆断点续播）
  Future<void> open(
    String uri, {
    Map<String, String>? httpHeaders,
    Duration? start,
    bool autoplay = true,
  }) async {
    if (_disposed) return;
    await initialize();
    final player = _player;
    if (player == null || _disposed) return;

    _currentUri = uri;
    _pendingStart = start ?? Duration.zero;

    core.value = core.value.copyWith(
      loading: true,
      buffering: false,
      completed: false,
      clearError: true,
    );

    timeline.value = PlaybackTimelineState(
      position: _pendingStart,
      duration: Duration.zero,
      buffer: Duration.zero,
    );

    try {
      await player.open(
        Media(
          uri,
          httpHeaders: httpHeaders ?? const <String, String>{},
          start: start,
        ),
        play: autoplay,
      );

      core.value = core.value.copyWith(loading: false);
    } catch (e) {
      core.value = core.value.copyWith(
        loading: false,
        buffering: false,
        errorMessage: '视频播放失败: $e',
      );
    }
  }

  /// 播放 / 暂停切换
  Future<void> togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (core.value.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    final player = _player;
    if (player == null) return;
    await player.play();
    danmakuController?.resume();
  }

  Future<void> pause() async {
    final player = _player;
    if (player == null) return;
    await player.pause();
    danmakuController?.pause();
  }

  /// 跳转至指定播放进度
  Future<void> seek(Duration target) async {
    final targetPosition = target < Duration.zero ? Duration.zero : target;
    timeline.value = timeline.value.copyWith(
      position: targetPosition,
      clearPreview: true,
    );

    // Seek 时主动清除前序偶发错误与 completed 状态，确保平滑恢复与继续播放
    if (core.value.hasError || core.value.completed) {
      core.value = core.value.copyWith(
        clearError: true,
        completed: false,
      );
    }

    final player = _player;
    if (player != null) {
      await player.seek(targetPosition);
    }
    danmakuController?.syncTime(targetPosition);
  }

  /// 进度条拖拽中实时更新预览位置（手指不松开不调用底层的 seek）
  void updateSeekPreview(Duration previewTarget) {
    timeline.value = timeline.value.copyWith(previewPosition: previewTarget);
  }

  /// 结束拖拽，真正落地 seek
  Future<void> endSeekPreview() async {
    final preview = timeline.value.previewPosition;
    if (preview != null) {
      await seek(preview);
    }
  }

  /// 步进跳转（快进 / 快退）
  Future<void> seekBy(Duration offset) async {
    final current = timeline.value.position;
    final target = current + offset;
    await seek(target);
  }

  /// 设置播放倍速
  Future<void> setPlaybackRate(double rate) async {
    final clampedRate = math.max(0.25, math.min(3.0, rate));
    core.value = core.value.copyWith(playbackRate: clampedRate);
    final player = _player;
    if (player != null) {
      await player.setRate(clampedRate);
    }
    danmakuController?.setPlaybackRate(clampedRate);
  }

  /// 设置音量 (0.0 ~ 1.0)
  Future<void> setVolume(double vol) async {
    final clamped = math.max(0.0, math.min(1.0, vol));
    core.value = core.value.copyWith(
      volume: clamped,
      muted: clamped <= 0.001,
    );
    final player = _player;
    if (player != null) {
      // media_kit volume 范围为 0 ~ 100
      await player.setVolume(clamped * 100.0);
    }
  }

  /// 切换静音
  Future<void> toggleMute() async {
    if (core.value.muted) {
      await setVolume(_preMuteVolume > 0.05 ? _preMuteVolume : 0.7);
    } else {
      _preMuteVolume = core.value.volume;
      await setVolume(0.0);
    }
  }

  /// 切换画面缩放模式
  void setVideoFit(BoxFit fit) {
    core.value = core.value.copyWith(videoFit: fit);
  }

  // ==========================
  // 底层事件流响应与 250ms 节流
  // ==========================

  void _onPlayingChanged(bool isPlaying) {
    if (core.value.playing != isPlaying) {
      core.value = core.value.copyWith(
        playing: isPlaying,
        clearError: isPlaying,
      );
      if (isPlaying) {
        danmakuController?.resume();
      } else {
        danmakuController?.pause();
      }
    }
  }

  void _onBufferingChanged(bool isBuffering) {
    if (core.value.buffering != isBuffering) {
      core.value = core.value.copyWith(buffering: isBuffering);
    }
  }

  void _onCompletedChanged(bool isCompleted) {
    if (core.value.completed != isCompleted) {
      core.value = core.value.copyWith(completed: isCompleted);
    }
  }

  void _onRateChanged(double rate) {
    if (core.value.playbackRate != rate) {
      core.value = core.value.copyWith(playbackRate: rate);
    }
  }

  void _onErrorChanged(String error) {
    if (error.isEmpty) return;

    // 过滤底层网络断开/Seek重连/EOF良性日志 (如 FFmpeg AVERROR_EOF = -541478725 / 0xdfb9b0bb)
    final lower = error.toLowerCase();
    if (lower.contains('0xdfb9b0bb') ||
        lower.contains('ffurl_read returned') ||
        lower.contains('end of file') ||
        lower.contains('connection reset by peer')) {
      debugPrint('[ZakoniPlayback] 忽略底层网络断流/Seek良性重连日志: $error');
      return;
    }

    core.value = core.value.copyWith(errorMessage: error);
  }

  void _onPositionChanged(Duration pos) {
    // 门禁：规避起播瞬间 mpv 抛出的 0 秒事件覆盖真实断点进度
    if (_pendingStart > Duration.zero) {
      if (pos + const Duration(seconds: 1) < _pendingStart) {
        return;
      }
      _pendingStart = Duration.zero;
    }

    // 当播放进度正常前进时，说明媒体解码通畅，自动抹除瞬态错误
    if (core.value.hasError && pos > Duration.zero) {
      core.value = core.value.copyWith(clearError: true);
    }

    _lastPosition = pos;
    _scheduleTimelineEmit();
  }

  void _onDurationChanged(Duration dur) {
    _lastDuration = dur;
    _scheduleTimelineEmit();
  }

  void _onBufferChanged(Duration buf) {
    _lastBuffer = buf;
    _scheduleTimelineEmit();
  }

  /// 250ms 节流触发时间线更新，杜绝高频重绘
  void _scheduleTimelineEmit() {
    if (_timelineThrottleTimer != null && _timelineThrottleTimer!.isActive) {
      return;
    }

    _timelineThrottleTimer = Timer(const Duration(milliseconds: 250), () {
      if (_disposed) return;
      timeline.value = timeline.value.copyWith(
        position: _lastPosition,
        duration: _lastDuration,
        buffer: _lastBuffer,
      );
      // 联动同步弹幕时间
      danmakuController?.syncTime(_lastPosition);
    });
  }

  /// 资源销毁
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _timelineThrottleTimer?.cancel();
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();

    final player = _player;
    _player = null;
    videoControllerNotifier.value = null;

    if (player != null) {
      // 特殊处理说明：
      // 在页面 Pop 退出或销毁时，libmpv (media_kit) 若正处于网络缓冲或 demux 状态，
      // 同步等待 player.stop()/dispose() 会阻塞原生线程与 PlatformChannel 达数秒导致界面卡死。
      // 因此此处先立即触发非阻塞 pause，并将真正的 stop/dispose 脱钩至后台微任务中异步释放。
      unawaited(() async {
        try {
          await player.pause();
          await player.stop();
        } catch (_) {}
        try {
          await player.dispose();
        } catch (_) {}
      }());
    }

    core.dispose();
    timeline.dispose();
    videoControllerNotifier.dispose();
  }
}
