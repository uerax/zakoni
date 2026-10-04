import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

const String _kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

const String _kNetworkDemuxerLavfOptions =
    'reconnect=1,multiple_requests=1,retry_open=3,hls_wrap=0,hls_allow_cache=1,'
    'fflags=+igndts+ignidx,tls_verify=0';

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

    final player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 16 * 1024 * 1024, // 16MB 内存缓冲
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

    // 绑定底层播放器流事件
    _subscriptions.addAll([
      player.stream.playing.listen(_onPlayingChanged),
      player.stream.buffering.listen(_onBufferingChanged),
      player.stream.completed.listen(_onCompletedChanged),
      player.stream.position.listen(_onPositionChanged),
      player.stream.duration.listen(_onDurationChanged),
      player.stream.buffer.listen(_onBufferChanged),
      player.stream.rate.listen(_onRateChanged),
      player.stream.error.listen(_onErrorChanged),
    ]);

    // 注入底层 mpv 增强属性
    await _configureNativeMpvProperties();
  }

  /// 配置底层 mpv 属性（变速变调不变音、断流自动重连、忽略坏时间戳）
  Future<void> _configureNativeMpvProperties() async {
    final player = _player;
    if (player == null) return;

    try {
      final platform = player.platform;
      if (platform is NativePlayer) {
        // 1. scaletempo2 滤镜：倍速播放（1.25x~3.0x）时自动修正音高，人声音质不失真
        await platform.setProperty('af', 'scaletempo2=max-speed=8');

        // 2. 切片断流自动重连与坏时间戳自愈：针对第三方 m3u8 切片源的核心容错
        await platform.setProperty('demuxer-lavf-o', _kNetworkDemuxerLavfOptions);

        // 3. 解复用缓冲与超时
        await platform.setProperty('demuxer-max-bytes', '16777216'); // 16MB
        await platform.setProperty('demuxer-max-back-bytes', '4194304'); // 4MB
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

    // Seek 时主动清除前序偶发错误状态，确保拖拽平滑恢复
    if (core.value.hasError) {
      core.value = core.value.copyWith(clearError: true);
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
