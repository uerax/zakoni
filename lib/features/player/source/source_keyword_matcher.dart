import 'dart:math' as math;
import 'package:zakoni/core/models/bangumi/bangumi_item.dart';
import 'models/source_models.dart';
import 'utils/chinese_s2t_converter.dart';

/// 视频源标题语言偏好 (1:1 严格对齐 animaku TitlePreference)
enum TitlePreference {
  /// 标准中文名优先 (带空格，如 "间谍过家家 第二季")
  chinese,

  /// 紧凑中文名优先 (去除季数前空格，如 "间谍过家家第二季"，适用于 mifun 等源)
  chineseCompact,

  /// 日文原名优先 (如 "SPY×FAMILY"，适用于 xifan-next, moonci, omofun, libvio)
  original,

  /// 繁体中文优先 (自动简转繁，适用于 anime1 等源)
  traditional,
}

/// 标题预清洗与关键词候选池生成引擎 (1:1 严格对齐 animaku packages/shared/src/plugin.ts 规范)
class SourceKeywordMatcher {
  SourceKeywordMatcher._();

  static final RegExp _seasonPattern = RegExp(
    r'\s*(?:第\s*[一二三四五六七八九十\d]+\s*[季期部]|Season\s*\d+|S\d+|Part\s*\d+|[第上下][季期]|[上下前后]篇?|[一二三四五六七八九十\d]+章|特别篇|总集篇|番外篇|剧场版|[一-龥]{2,6}[篇編])\s*$',
    caseSensitive: false,
  );

  static final RegExp _bracketPattern = RegExp(
    r'\s*[\(\[（【][^\)\]）】]+[\)\]）】]\s*$',
  );

  static final RegExp _modifierPattern = RegExp(
    r'第\s*[一二三四五六七八九十\d]+\s*[季期部]|season\s*\d+|s\d+|part\s*\d+|剧场版|劇場版|特别篇|特別編|ova|oad|movie|映画',
    caseSensitive: false,
  );

  static const Map<String, int> _chineseDigits = {
    '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
  };

  static const Map<String, int> _romanNumerals = {
    'Ⅰ': 1, 'Ⅱ': 2, 'Ⅲ': 3, 'Ⅳ': 4, 'Ⅴ': 5, 'Ⅵ': 6, 'Ⅶ': 7, 'Ⅷ': 8, 'Ⅸ': 9, 'Ⅹ': 10,
    'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6,
  };

  static final RegExp _seasonNumPattern = RegExp(
    r'第\s*([一二三四五六七八九十\d]+)\s*[季期部]|season\s*(\d+)|\bs(\d+)\b|part\s*(\d+)|([ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ])|\b(II|III|IV|V|VI)\b',
    caseSensitive: false,
  );

  /// 过滤无效的超短前缀黑名单 (对齐 animaku SHORT_PREFIX_BLACKLIST)
  static const Set<String> _shortPrefixBlacklist = {
    're', 'fate', 'ova', 'oad', 'sp', 'part', '剧场版', '特别篇', '总集篇',
  };

  /// 解析中文数字 (1~99)
  static int? parseChineseNumber(String raw) {
    if (raw.isEmpty) return null;
    final direct = int.tryParse(raw);
    if (direct != null) return direct;
    final tenIndex = raw.indexOf('十');
    if (tenIndex == -1) return _chineseDigits[raw];
    final tens = tenIndex == 0 ? 1 : (_chineseDigits[raw[0]] ?? 1);
    final onesPart = raw.substring(tenIndex + 1);
    final ones = onesPart.isNotEmpty ? (_chineseDigits[onesPart] ?? 0) : 0;
    return tens * 10 + ones;
  }

  /// 提取标准化的季数序号 (1:1 对齐 animaku extractSeason 规范)
  static int? extractSeason(String? title) {
    if (title == null || title.isEmpty) return null;
    final m = _seasonNumPattern.firstMatch(title);
    if (m == null) return null;
    if (m.group(1) != null) return parseChineseNumber(m.group(1)!);
    final numStr = m.group(2) ?? m.group(3) ?? m.group(4);
    if (numStr != null) return int.tryParse(numStr);
    if (m.group(5) != null) return _romanNumerals[m.group(5)!];
    if (m.group(6) != null) return _romanNumerals[m.group(6)!.toLowerCase()];
    return null;
  }

  /// 获取指定视频源的默认标题语言偏好
  static TitlePreference getPreferenceForSource(String? sourceId) {
    final sId = sourceId?.toLowerCase().trim();
    if (sId == 'anime1') {
      return TitlePreference.traditional;
    }
    if (sId == 'mifun') {
      return TitlePreference.chineseCompact;
    }
    if (sId == 'xifan-next' || sId == 'moonci' || sId == 'omofun' || sId == 'libvio') {
      return TitlePreference.original;
    }
    return TitlePreference.chinese;
  }

  /// 依据视频源语言偏好解析最优单关键词 (1:1 严格对齐 animaku resolvePluginDefaultKeyword 规范)
  static String resolveDefaultKeyword({
    required String defaultTitle,
    BangumiItem? item,
    String? sourceId,
    TitlePreference? preference,
  }) {
    final pref = preference ?? getPreferenceForSource(sourceId);
    final name = (item?.name ?? '').trim();
    final nameCn = (item?.nameCn ?? '').trim();
    final fb = defaultTitle.trim();

    if (pref == TitlePreference.original) {
      if (name.isNotEmpty) return name;
      if (nameCn.isNotEmpty) return nameCn;
      return fb;
    }

    final chineseTitle = nameCn.isNotEmpty ? nameCn : (name.isNotEmpty ? name : fb);

    if (pref == TitlePreference.chineseCompact) {
      // 移除 "第X季" 前面的空格：例如 "碧蓝之海 第二季" -> "碧蓝之海第二季"
      return chineseTitle.replaceAllMapped(
        RegExp(r'\s+(第\s*[一二三四五六七八九十\d]+\s*[季期部])'),
        (m) => m.group(1)!,
      );
    }

    if (pref == TitlePreference.traditional) {
      return ChineseS2TConverter.convert(chineseTitle);
    }

    return chineseTitle;
  }

  /// 递归剥离章篇与季数后缀 (对齐 animaku extractBaseTitle)
  static String extractBaseTitle(String fullTitle) {
    if (fullTitle.isEmpty) return '';
    var base = fullTitle.trim();
    if (_bracketPattern.hasMatch(base)) {
      base = base.replaceAll(_bracketPattern, '').trim();
    }
    if (_seasonPattern.hasMatch(base)) {
      base = base.replaceAll(_seasonPattern, '').trim();
    }
    return base.isNotEmpty ? base : fullTitle;
  }

  /// 剥离特殊标点符号 (对齐 animaku stripSymbols)
  static String stripSymbols(String text) {
    return text
        .replaceAll(
          RegExp(r'[!@#$%^&*()_+\-=\[\]{};\x27:"\\|,.<>/?~～·・：；（）【】「」]'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 依据视频源语言偏好生成多级关键词候选池 (对齐 animaku buildSearchKeywords)
  static List<String> buildCandidates({
    required String defaultTitle,
    BangumiItem? item,
    String? sourceId,
  }) {
    final nameCn = item?.nameCn.trim() ?? '';
    final nameOriginal = item?.name.trim() ?? '';
    final aliases = (item?.alias ?? []).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final titles = [
      if (nameCn.isNotEmpty) nameCn,
      if (nameOriginal.isNotEmpty) nameOriginal,
      defaultTitle.trim(),
      ...aliases,
    ];

    final variants = <String>[];

    void push(String s) {
      final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.length < 2) return;
      if (t.length < 4 && _shortPrefixBlacklist.contains(t.toLowerCase())) return;
      if (t.length > 60) return;
      if (!variants.any((v) => v.toLowerCase() == t.toLowerCase())) {
        variants.add(t);
      }
    }

    for (final title in titles) {
      // 1. 完整原名 (Tier 1)
      push(title);

      // 2. 紧凑季数 (Tier 2/3)
      final compactSeason = title.replaceAllMapped(
        RegExp(r'\s+(第\s*[一二三四五六七八九十\d]+\s*[季期部])'),
        (m) => m.group(1)!,
      );
      if (compactSeason != title) {
        push(compactSeason);
      }

      // 3. 剥离章篇副标题
      final baseWithSeason = extractBaseTitle(title);
      if (baseWithSeason != title) {
        push(baseWithSeason);
        push(baseWithSeason.replaceAllMapped(
          RegExp(r'\s+(第\s*[一二三四五六七八九十\d]+\s*[季期部])'),
          (m) => m.group(1)!,
        ));
      }

      // 4. 纯主名（彻底剥离季数）
      final basePure = extractBaseTitle(baseWithSeason);
      if (basePure != baseWithSeason) {
        push(basePure);
      }

      // 5. 波浪号副标题清洗（如 "无职转生～到了异世界就拿出真本事～" -> "无职转生"）
      final noTilde = title.replaceAll(RegExp(r'[～~].*?[～~]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (noTilde.isNotEmpty && noTilde != title) {
        push(noTilde);
        final noTildeBase = extractBaseTitle(noTilde);
        if (noTildeBase.isNotEmpty && noTildeBase != noTilde) {
          push(noTildeBase);
          push(noTildeBase.replaceAllMapped(
            RegExp(r'\s+(第\s*[一二三四五六七八九十\d]+\s*[季期部])'),
            (m) => m.group(1)!,
          ));
        }
      }

      // 6. 括号副标题清洗
      final noBracket = title.replaceAll(RegExp(r'[（(][^）)]*[）)]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (noBracket.isNotEmpty && noBracket != title) {
        push(noBracket);
      }

      // 7. 冒号前缀提取 (长度必须 >= 4 且不在黑名单中)
      final colonHead = title.split(RegExp(r'[\s　:：\-–—·・]')).first.trim();
      if (colonHead.length >= 4 && !_shortPrefixBlacklist.contains(colonHead.toLowerCase())) {
        push(colonHead);
      }
    }

    // 针对偏好日语原名的源（如 xifan-next, moonci），在候选池中将日文原名排到首位
    // 特殊处理说明：
    // 当从播放历史等入口启动时，传入的 BangumiItem 常常是 name == nameCn（如均等于番剧标题）。
    // 若先 insert 原名再 remove 中文名，会导致刚刚插入的原名被误删造成列表为空，
    // 紧接着执行 insert(1, ...) 会抛出 RangeError (Invalid value: Only valid value is 0: 1) 导致整页红屏崩溃。
    // 因此这里先判断 nameCn != nameOriginal 并优先将其置于头部，最后将 nameOriginal 插入索引 0；
    // 两次均为 insert(0, ...)，在任何列表长度下均绝对安全，且原名稳居首位，中文名顺延至次席。
    final pref = getPreferenceForSource(sourceId);
    if (pref == TitlePreference.original && nameOriginal.isNotEmpty) {
      variants.remove(nameOriginal);
      if (nameCn.isNotEmpty && nameCn != nameOriginal) {
        variants.remove(nameCn);
        variants.insert(0, nameCn);
      }
      variants.insert(0, nameOriginal);
    } else if (pref == TitlePreference.traditional) {
      // 繁体源优先全量繁体化候选词
      final tradList = variants.map(ChineseS2TConverter.convert).toList();
      for (final t in tradList) {
        if (!variants.contains(t)) variants.insert(0, t);
      }
    }

    return variants;
  }

  /// 展开单个搜索关键词为由短至长的出站备选词列表 (1:1 对齐 animaku expandKeywordCandidates)
  static List<String> expandKeywordCandidates(
    String keyword, {
    bool traditionalChinese = false,
    bool stripPunctuation = false,
  }) {
    var raw = keyword.trim();
    if (raw.isEmpty) return const [];

    if (traditionalChinese) {
      raw = ChineseS2TConverter.convert(raw).trim();
    }

    if (stripPunctuation) {
      raw = stripSymbols(raw);
    }

    final out = <String>[];
    void push(String s) {
      final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.length < 2 || t.length > 48) return;
      if (!out.any((x) => x.toLowerCase() == t.toLowerCase())) {
        out.add(t);
      }
    }

    // 1. 冒号/空格前缀
    final head = raw.split(RegExp(r'[\s　:：\-–—·・]')).first.trim();
    if (head.isNotEmpty) push(head);

    // 2. 去除括号
    push(raw.replaceAll(RegExp(r'[（(][^）)]*[）)]'), ' '));

    // 3. 去除季数标记
    push(
      raw
          .replaceAll(RegExp(r'(第?\s*\d+\s*[期季部作]|S\s*\d+|Season\s*\d+)', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\s+'), ' '),
    );

    // 4. 原始完整词
    push(raw);

    // 短词优先尝试
    out.sort((a, b) {
      final diff = a.length.compareTo(b.length);
      if (diff != 0) return diff;
      return a.compareTo(b);
    });

    return out.take(4).toList();
  }

  /// 计算两个标题的相似度 (1:1 严格对齐 animaku titleSimilarity 算法，含季数强校验 Season Guard)
  static double calculateSimilarity(String a, String b) {
    final s1 = a.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final s2 = b.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // 1. 季数强冲突守卫 (Hard Season Conflict): 若两边均明确声明了季数且不一致 (如 S3 vs S2)，直接降权至 0.15 杜绝误匹配
    final seasonA = extractSeason(a);
    final seasonB = extractSeason(b);
    if (seasonA != null && seasonB != null && seasonA != seasonB) {
      return 0.15;
    }

    final aHasMod = _modifierPattern.hasMatch(a);
    final bHasMod = _modifierPattern.hasMatch(b);
    final modMismatch = aHasMod != bHasMod;

    // 2. 包含匹配
    if (s1.contains(s2) || s2.contains(s1)) {
      final ratio = math.min(s1.length, s2.length) / math.max(s1.length, s2.length);
      if (modMismatch) {
        // 一方有季数/修饰词而另一方无 (如 S3 vs S1 裸主名)，压制分数低于自动选源门槛 (0.55)
        final penalized = (0.65 + ratio * 0.25) * 0.6;
        return math.min(penalized, 0.45);
      }
      return 0.85 + 0.1 * ratio;
    }

    // 字符 Jaccard 相似度
    final set1 = s1.split('').toSet();
    var inter = 0;
    for (final ch in s2.split('')) {
      if (set1.contains(ch)) inter++;
    }
    final union = {...set1, ...s2.split('')}.length;
    final jaccard = union > 0 ? inter / union : 0.0;

    // CJK Bigram 语法重叠度
    final b1 = <String>[];
    for (var i = 0; i < s1.length - 1; i++) {
      b1.add(s1.substring(i, i + 2));
    }
    final b2 = <String>{};
    for (var i = 0; i < s2.length - 1; i++) {
      b2.add(s2.substring(i, i + 2));
    }
    var bi = 0;
    for (final g in b1) {
      if (b2.contains(g)) bi++;
    }
    final biScore = b1.isNotEmpty ? bi / b1.length : 0.0;

    final combined = math.max(jaccard * 0.6 + biScore * 0.4, jaccard);
    return modMismatch ? combined * 0.7 : combined;
  }

  /// 在候选命中列表中计算与番剧标题库的最佳相似度
  static double bestSimilarity(String title, List<String> targets) {
    var maxScore = 0.0;
    for (final t in targets) {
      final score = calculateSimilarity(title, t);
      if (score > maxScore) maxScore = score;
    }
    return maxScore;
  }

  /// 对搜索命中结果按标题相似度由高到低排序 (1:1 对齐 animaku rankSearchItems)
  static List<SourceSearchResult> rankSearchHits(
    List<SourceSearchResult> items,
    List<String> references,
  ) {
    if (items.isEmpty) return items;
    final sorted = List<SourceSearchResult>.from(items);
    sorted.sort((a, b) {
      final sb = bestSimilarity(b.name, references);
      final sa = bestSimilarity(a.name, references);
      if (sb != sa) {
        return sb.compareTo(sa); // 降序
      }
      return a.name.length.compareTo(b.name.length);
    });
    return sorted;
  }
}
