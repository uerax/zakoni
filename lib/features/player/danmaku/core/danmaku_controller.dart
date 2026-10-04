import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zakoni/features/player/danmaku/models/danmaku_item.dart';

/// 弹幕事件监听接口，由视图层 DanmakuView 实现并绑定
abstract interface class DanmakuListener {
  /// 时间轴同步（跳进度或周期性矫正）
  void onDanmakuTimeSync(Duration position);

  /// 弹幕播放倍速改变
  void onDanmakuPlaybackRateChanged(double rate);

  /// 弹幕数据源重新加载或全量变更
  void onDanmakuItemsChanged();

  /// 用户实时注入新弹幕（自己发的或外部推送）
  void onDanmakuInject(DanmakuItem item);

  /// 弹幕设置变更
  void onDanmakuSettingsChanged(DanmakuSettings next, DanmakuSettings previous);

  /// 暂停
  void onDanmakuPause();

  /// 恢复播放
  void onDanmakuResume();

  /// 重置清屏
  void onDanmakuReset();
}

/// 预编译的过滤规则
class _CompiledFilter {
  _CompiledFilter.regex(this.regex) : text = null;
  _CompiledFilter.substring(this.text) : regex = null;

  final RegExp? regex;
  final String? text;

  bool matches(String target) {
    if (regex != null) {
      return regex!.hasMatch(target);
    }
    if (text != null && text!.isNotEmpty) {
      return target.contains(text!);
    }
    return false;
  }
}

/// 弹幕业务调度控制器
class DanmakuController extends ChangeNotifier {
  DanmakuController({
    DanmakuSettings? initialSettings,
  }) : _settings = initialSettings ?? const DanmakuSettings() {
    _recompileFilters();
  }

  final List<DanmakuItem> _items = <DanmakuItem>[];
  DanmakuSettings _settings;
  DanmakuListener? _listener;

  bool _playing = false;
  double _playbackRate = 1.0;
  List<_CompiledFilter> _compiledFilters = const [];

  /// 当前所有已就绪并排序的弹幕列表
  List<DanmakuItem> get items => List.unmodifiable(_items);

  /// 当前弹幕配置
  DanmakuSettings get settings => _settings;

  /// 是否正在播放
  bool get playing => _playing;

  /// 播放倍速
  double get playbackRate => _playbackRate;

  /// 挂载视图监听器
  void attach(DanmakuListener listener) {
    _listener = listener;
  }

  /// 解绑视图监听器
  void detach(DanmakuListener listener) {
    if (identical(_listener, listener)) {
      _listener = null;
    }
  }

  /// 批量载入全集弹幕数据（内部自动按时间轴毫秒排序）
  void loadItems(List<DanmakuItem> newItems) {
    _items.clear();
    _items.addAll(newItems);
    _items.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    _listener?.onDanmakuItemsChanged();
    notifyListeners();
  }

  /// 动态发射/注入单条弹幕
  void inject(DanmakuItem item) {
    _listener?.onDanmakuInject(item);
  }

  /// 更新弹幕配置项
  void updateSettings(DanmakuSettings newSettings) {
    final previous = _settings;
    if (previous == newSettings) return;
    _settings = newSettings;
    _recompileFilters();
    _listener?.onDanmakuSettingsChanged(_settings, previous);
    notifyListeners();
  }

  /// 同步视频时间轴
  void syncTime(Duration position) {
    _listener?.onDanmakuTimeSync(position);
  }

  /// 播放倍速联动
  void setPlaybackRate(double rate) {
    if (_playbackRate == rate) return;
    _playbackRate = math.max(0.1, rate);
    _listener?.onDanmakuPlaybackRateChanged(_playbackRate);
    notifyListeners();
  }

  /// 播放状态控制：播放
  void resume() {
    _playing = true;
    _listener?.onDanmakuResume();
    notifyListeners();
  }

  /// 播放状态控制：暂停
  void pause() {
    _playing = false;
    _listener?.onDanmakuPause();
    notifyListeners();
  }

  /// 清空当前屏幕与状态
  void reset() {
    _listener?.onDanmakuReset();
  }

  /// 清空所有数据
  void clearAll() {
    _items.clear();
    reset();
    notifyListeners();
  }

  /// 检查某条文本是否命中屏蔽过滤规则
  bool isBlocked(String text) {
    for (final filter in _compiledFilters) {
      if (filter.matches(text)) return true;
    }
    return false;
  }

  void _recompileFilters() {
    final filters = _settings.filters;
    if (filters.isEmpty) {
      _compiledFilters = const [];
      return;
    }

    final list = <_CompiledFilter>[];
    for (final rule in filters) {
      if (rule.isEmpty) continue;
      // 检查是否为 /pattern/flags 正则格式
      if (rule.startsWith('/') && rule.lastIndexOf('/') > 0) {
        try {
          final lastSlash = rule.lastIndexOf('/');
          final pattern = rule.substring(1, lastSlash);
          final flags = rule.substring(lastSlash + 1);
          final caseSensitive = !flags.contains('i');
          final isMultiLine = flags.contains('m');
          list.add(_CompiledFilter.regex(RegExp(
            pattern,
            caseSensitive: caseSensitive,
            multiLine: isMultiLine,
          )));
          continue;
        } catch (_) {
          // 正则解析失败则回退为普通子串匹配
        }
      }
      list.add(_CompiledFilter.substring(rule));
    }
    _compiledFilters = list;
  }
}
