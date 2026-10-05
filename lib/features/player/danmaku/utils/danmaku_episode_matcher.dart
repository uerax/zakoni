/// 弹幕集数实体接口
abstract interface class DanmakuEpisodeEntry {
  int get episodeId;
  String get episodeTitle;
}

/// 简单集数数据模型
class DanmakuEpisodeItem implements DanmakuEpisodeEntry {
  const DanmakuEpisodeItem({
    required this.episodeId,
    required this.episodeTitle,
  });

  @override
  final int episodeId;

  @override
  final String episodeTitle;
}

/// 弹幕集数智能匹配与解析工具类 (1:1 对齐 animaku matchDanmakuEpisode)
class DanmakuEpisodeMatcher {
  DanmakuEpisodeMatcher._();

  static final RegExp _epPattern1 = RegExp(
    r'(?:第|ep|e)\s*0*(\d+)\s*(?:话|集|期)?',
    caseSensitive: false,
  );

  static final RegExp _epPattern2 = RegExp(
    r'^0*(\d+)(?:\s|$|[-_.、:])',
    caseSensitive: false,
  );

  static final RegExp _epPattern3 = RegExp(
    r'(?:^|\D)0*(\d+)(?:话|集)(?:\D|$)',
    caseSensitive: false,
  );

  /// 从分集标题解析集数数字（支持 0 话、第00话、01、E01、第 1 集等）
  static int? parseEpisodeNumber(String title) {
    final t = title.trim();
    if (t.isEmpty) return null;

    final m1 = _epPattern1.firstMatch(t);
    if (m1 != null) {
      final n = int.tryParse(m1.group(1) ?? '');
      if (n != null) return n;
    }

    final m2 = _epPattern2.firstMatch(t);
    if (m2 != null) {
      final n = int.tryParse(m2.group(1) ?? '');
      if (n != null) return n;
    }

    final m3 = _epPattern3.firstMatch(t);
    if (m3 != null) {
      final n = int.tryParse(m3.group(1) ?? '');
      if (n != null) return n;
    }

    return null;
  }

  /// 智能匹配分集：
  /// 1. 优先通过正则表达式在 episodeTitle 中匹配对应目标集数 targetEpisode（支持 0 话，如 "第00话", "00 PROLOGUE", "EP0"）；
  /// 2. 若标题未正则命中，则降级为下标：
  ///    - targetEpisode == 0: 降级为第 1 个元素 (episodes[0])
  ///    - targetEpisode >= 1: 降级为 0-based 索引 (episodes[targetEpisode - 1])，越界时取第 1 个元素
  static T? matchEpisode<T extends DanmakuEpisodeEntry>(
    List<T> episodes,
    int targetEpisode,
  ) {
    if (episodes.isEmpty) return null;
    if (targetEpisode < 0) return episodes.first;

    // 1. 正则匹配标题
    for (final ep in episodes) {
      final title = ep.episodeTitle.trim();
      final num = parseEpisodeNumber(title);
      if (num != null && num == targetEpisode) {
        return ep;
      }
    }

    // 2. 降级为下标查找
    if (targetEpisode == 0) {
      return episodes.first;
    }

    final index = targetEpisode - 1;
    if (index >= 0 && index < episodes.length) {
      return episodes[index];
    }

    return episodes.first;
  }
}
