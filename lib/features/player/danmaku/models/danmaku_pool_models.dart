import 'danmaku_item.dart';

/// 独立的弹幕数据池标识（对应各数据源）
enum DanmakuPoolId {
  /// 弹弹 play 主题库
  dandan('dandan', '弹弹'),

  /// 关联 Bangumi 自动匹配的 Bilibili 番剧弹幕
  bilibiliAuto('bilibili_auto', 'B站'),

  /// 用户在面板手动粘贴的 BV号/番剧链接/分P弹幕
  bilibiliManual('bilibili_manual', 'bilibili'),

  /// 用户本地选取的 XML 弹幕文件
  upload('upload', '本地上传');

  const DanmakuPoolId(this.code, this.label);

  final String code;
  final String label;

  static DanmakuPoolId fromCode(String code) {
    for (final id in DanmakuPoolId.values) {
      if (id.code == code) return id;
    }
    return DanmakuPoolId.dandan;
  }
}

/// 单个弹幕池分片状态
class DanmakuPoolSlice {
  const DanmakuPoolSlice({
    this.items = const <DanmakuItem>[],
    this.enabled = true,
    this.meta,
    this.timeOffsetMs = 0,
  });

  /// 当前池中加载的弹幕列表
  final List<DanmakuItem> items;

  /// 该源是否参与合并与渲染
  final bool enabled;

  /// 简短描述信息（如文件名、分P名称、BV号、epId等）
  final String? meta;

  /// 该数据源专属的时间轴毫秒偏移（例如 +3500 表示延后 3.5s，-2000 表示提前 2s）
  final int timeOffsetMs;

  DanmakuPoolSlice copyWith({
    List<DanmakuItem>? items,
    bool? enabled,
    String? meta,
    int? timeOffsetMs,
  }) {
    return DanmakuPoolSlice(
      items: items ?? this.items,
      enabled: enabled ?? this.enabled,
      meta: meta ?? this.meta,
      timeOffsetMs: timeOffsetMs ?? this.timeOffsetMs,
    );
  }
}

/// 底部源池状态栏展示用的 Chip 模型
class DanmakuSourceChip {
  const DanmakuSourceChip({
    required this.id,
    required this.label,
    required this.count,
    required this.enabled,
    required this.loaded,
    this.meta,
    required this.timeOffsetMs,
  });

  final DanmakuPoolId id;
  final String label;
  final int count;
  final bool enabled;
  final bool loaded;
  final String? meta;
  final int timeOffsetMs;
}
