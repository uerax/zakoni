import 'package:zakoni/core/models/bangumi/bangumi_episode.dart';
import '../models/source_models.dart';
import '../source_keyword_matcher.dart';

/// 统一标准化可播放集数槽位 (1:1 严格对齐 animaku PlayableSlot 规范)
class PlayableSlot {
  /// 权威集数编号 (0, 1, 2, ...)，由 Layer 1 官方 Bangumi sort 决定或 Layer 2 保守抽取
  final int canonicalEp;

  /// Bangumi 官方单集副标题 (如 "冬之日", "序章")，Layer 2 模式下为空
  final String officialTitle;

  /// 播放器/选集面板统一标准展示标题 (如 "第 01 话", "第 00 话 序章")
  final String displayTitle;

  /// 视频源线路中的原始物理数组下标 (0-based)
  final int sourceIndex;

  /// 视频源当前集真实播放页面地址
  final String pageUrl;

  /// 视频源原始抓取分集标题
  final String sourceTitle;

  /// 是否运行在 Layer 2 降级/溢出/离线回退模式
  final bool isLayer2;

  /// 选集卡片专用简短编号标签 (严格对应映射到的 Bangumi 对应集数，如 "第 01 话", "第 00 话")
  String get cardLabel {
    if (canonicalEp == 0) return '第 00 话';
    if (canonicalEp > 0 && canonicalEp < 10) return '第 0$canonicalEp 话';
    return '第 $canonicalEp 话';
  }

  const PlayableSlot({
    required this.canonicalEp,
    required this.officialTitle,
    required this.displayTitle,
    required this.sourceIndex,
    required this.pageUrl,
    required this.sourceTitle,
    this.isLayer2 = false,
  });
}

class FilteredSourceItem {
  final int originalIndex;
  final String title;

  const FilteredSourceItem({
    required this.originalIndex,
    required this.title,
  });
}

/// Bangumi 权威位置对齐与 PlayableSlot 双层对齐引擎 (1:1 对齐 animaku episode-alignment.ts)
/// 核心解决：
/// 1. 彻底解决《86 不存在的战区》《100万生命》《第十天恶魔》等标题带数字被错误正则解析的顽疾；
/// 2. 自动过滤源站中夹杂的 PV/预告/花絮/特典，确保集数 100% 对应；
/// 3. 当官方数据离线或源站集数溢出时，平滑降级至 Layer 2 模式。
class PlayableSlotEngine {
  PlayableSlotEngine._();

  static final RegExp _nonMainPattern = RegExp(
    r'(?:^|[\s_#\-\[\(（【])(?:PV\d*|预告|預告|花絮|OVA|OAD|SP\d*|特别篇|特別篇|总集篇|總集篇|特典|特报|特報|NC[OE]D|EXTRA)',
    caseSensitive: false,
  );

  /// 过滤明显非正片内容 (PV, 预告, 特典, 花絮等)
  static List<FilteredSourceItem> filterOutObviousNonMainContent(
    List<SourceEpisode> episodes,
  ) {
    final out = <FilteredSourceItem>[];
    for (var i = 0; i < episodes.length; i++) {
      final title = episodes[i].name.trim();
      if (!_nonMainPattern.hasMatch(title)) {
        out.add(FilteredSourceItem(originalIndex: i, title: title));
      }
    }
    return out;
  }

  /// 格式化集数展示标题
  static String formatEpisodeDisplayTitle(int canonicalEp, [String? officialTitle]) {
    String base;
    if (canonicalEp == 0) {
      base = '第 00 话';
    } else if (canonicalEp > 0 && canonicalEp < 10) {
      base = '第 0$canonicalEp 话';
    } else {
      base = '第 $canonicalEp 话';
    }

    final trimmedSub = (officialTitle ?? '').trim();
    if (trimmedSub.isNotEmpty) {
      return '$base $trimmedSub';
    }
    return base;
  }

  /// 保守提取单集数字 (用于 Layer 2 模式)
  static int extractConservativeEpisodeNumber(
    String rawTitle,
    int fallbackValue, {
    bool isFirstItem = false,
  }) {
    final title = rawTitle.trim();
    if (title.isEmpty) return fallbackValue;

    // 1. 显式 0 集模式 (如 "第00话", "第0话", "EP00", "序章", "PROLOGUE")
    if (RegExp(
          r'(?:第\s*0+[\s集话話回期]|(?:^|[\s_#\-\[\(（【])(?:EP|Ep|E)\.?\s*0+(?:[\s_#\-\]\)）】]|$|\D)|^[\[\(（【]?\s*0+\s*[\]\)）】]?$|^0+[\s_#\-\.、:])',
          caseSensitive: false,
        ).hasMatch(title) ||
        (isFirstItem && RegExp(r'(?:序章|PROLOGUE|前传|前傳)', caseSensitive: false).hasMatch(title))) {
      return 0;
    }

    // 2. 显式 "第01集", "第12话", "第一集", "第十二话"
    final cjkMatch = RegExp(r'第\s*([0-9一二两兩三四五六七八九十]+(?:\.\d+)?)\s*[集话話回期]').firstMatch(title);
    if (cjkMatch != null && cjkMatch.group(1) != null) {
      final raw = cjkMatch.group(1)!;
      final direct = int.tryParse(raw);
      if (direct != null && direct >= 0) return direct;
      final cn = SourceKeywordMatcher.parseChineseNumber(raw);
      if (cn != null && cn >= 0) return cn;
    }

    // 3. 显式 "EP01", "Ep. 02", "E03"
    final epMatch = RegExp(r'(?:^|[\s_#\-\[\(（【])(?:EP|Ep|E)\.?\s*(\d+(?:\.\d+)?)(?:[\s_#\-\]\)）】]|$|\D)', caseSensitive: false).firstMatch(title);
    if (epMatch != null && epMatch.group(1) != null) {
      final n = double.tryParse(epMatch.group(1)!);
      if (n != null && n >= 0) return n.toInt();
    }

    // 4. 括号数字 "[01]", "(02)", "【03】"
    final bracketMatch = RegExp(r'^[\[\(（【]\s*(\d+(?:\.\d+)?)\s*[\]\)）】]').firstMatch(title);
    if (bracketMatch != null && bracketMatch.group(1) != null) {
      final n = double.tryParse(bracketMatch.group(1)!);
      if (n != null && n >= 0) return n.toInt();
    }

    // 5. 独立前置数字 "01", "12", "01 1080P"
    final leadingNumMatch = RegExp(r'^(\d+(?:\.\d+)?)(?:[\s_#\-\.\(（\[【集话話回vV]|$)').firstMatch(title);
    if (leadingNumMatch != null && leadingNumMatch.group(1) != null) {
      final n = double.tryParse(leadingNumMatch.group(1)!);
      if (n != null && n >= 0) return n.toInt();
    }

    return fallbackValue;
  }

  /// 为视频线路构建权威、标准化的 PlayableSlot 列表
  static List<PlayableSlot> buildPlayableSlots({
    required List<SourceEpisode> episodes,
    List<BangumiEpisode>? officialEpisodes,
  }) {
    if (episodes.isEmpty) return const [];

    // 1. 提取 Bangumi 权威正片列表 (type == 0: 本篇)
    final officialMain = (officialEpisodes ?? [])
        .where((e) => e.type == 0)
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));

    // 2. 过滤源站播放列表中的明显非正片 (PV/预告/花絮/特典)
    final filteredSource = filterOutObviousNonMainContent(episodes);
    final sourceItems = filteredSource.isNotEmpty
        ? filteredSource
        : List.generate(
            episodes.length,
            (i) => FilteredSourceItem(originalIndex: i, title: episodes[i].name.trim()),
          );

    // Layer 1: Bangumi 权威位置对齐 (1:1 映射)
    // 条件：官方正片列表存在，且其数量能够覆盖过滤后的源站剧集
    if (officialMain.isNotEmpty && officialMain.length >= sourceItems.length) {
      return List.generate(sourceItems.length, (i) {
        final item = sourceItems[i];
        final bgm = officialMain[i];
        final canonicalEp = bgm.ep?.toInt() ?? bgm.sort.toInt();
        final officialTitle = (bgm.nameCn.isNotEmpty ? bgm.nameCn : bgm.name).trim();
        final displayTitle = formatEpisodeDisplayTitle(canonicalEp, officialTitle);
        final epObj = episodes[item.originalIndex];

        return PlayableSlot(
          canonicalEp: canonicalEp,
          officialTitle: officialTitle,
          displayTitle: displayTitle,
          sourceIndex: item.originalIndex,
          pageUrl: epObj.url,
          sourceTitle: item.title.isNotEmpty ? item.title : epObj.name,
          isLayer2: false,
        );
      });
    }

    // Layer 2: 源站保守模式 (溢出/离线回退)
    final firstRawTitle = sourceItems.first.title;
    // 使用 -1 作为哨兵值检测是否显式命中 0 集模式 (如 "第00话", "序章")
    final firstIsZero = extractConservativeEpisodeNumber(firstRawTitle, -1, isFirstItem: true) == 0;

    return List.generate(sourceItems.length, (i) {
      final item = sourceItems[i];
      final fallbackVal = firstIsZero ? item.originalIndex : item.originalIndex + 1;
      final canonicalEp = extractConservativeEpisodeNumber(
        item.title,
        fallbackVal,
        isFirstItem: i == 0,
      );
      final epObj = episodes[item.originalIndex];
      final sourceTitle = item.title.isNotEmpty ? item.title : '第 $canonicalEp 话';
      final displayTitle = formatEpisodeDisplayTitle(canonicalEp);

      return PlayableSlot(
        canonicalEp: canonicalEp,
        officialTitle: '',
        displayTitle: displayTitle,
        sourceIndex: item.originalIndex,
        pageUrl: epObj.url,
        sourceTitle: sourceTitle,
        isLayer2: true,
      );
    });
  }
}
