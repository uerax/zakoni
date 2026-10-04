import 'dart:math' as math;
import '../../../core/models/bangumi/bangumi_item.dart';

/// 标题预清洗与关键词候选池生成 (1:1 严格对齐 animaku packages/shared/src/plugin.ts 规范)
class SourceKeywordMatcher {
  SourceKeywordMatcher._();

  static final RegExp _seasonPattern = RegExp(
    r'\s*(?:(?:第\s*[一二三四五六七八九十\d]+\s*[季期部])|(?:Season\s*\d+)|(?:Part\s*\d+)|(?:S\d+)|(?:[第上下][季期])|(?:[上下前后]篇?)|(?:特别篇|总集篇|番外篇|剧场版))\s*$',
    caseSensitive: false,
  );

  static final RegExp _bracketPattern = RegExp(
    r'\s*[\(\[（【][^\)\]）】]+[\)\]）】]\s*$',
  );

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
      if (!variants.any((v) => v.toLowerCase() == t.toLowerCase())) {
        variants.add(t);
      }
    }

    for (final title in titles) {
      // 1. 完整原名
      push(title);

      // 2. 紧凑季数（如 "间谍过家家 第三季" -> "间谍过家家第三季"）
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
        push(extractBaseTitle(noTilde));
      }

      // 6. 括号副标题清洗
      final noBracket = title.replaceAll(RegExp(r'[（(][^）)]*[）)]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (noBracket.isNotEmpty && noBracket != title) {
        push(noBracket);
      }
    }

    // 优先排序：针对某些偏好日语原名的源（如 xifan-next），在候选池中提升日文原名
    final preferOriginal = sourceId == 'xifan-next' || sourceId == 'moonci' || sourceId == 'omofun';
    if (preferOriginal && nameOriginal.isNotEmpty) {
      variants.remove(nameOriginal);
      variants.insert(0, nameOriginal);
      // 紧跟中文名
      if (nameCn.isNotEmpty) {
        variants.remove(nameCn);
        variants.insert(1, nameCn);
      }
    }

    return variants;
  }

  /// 计算两个标题的相似度 (1:1 严格对齐 animaku titleSimilarity 算法)
  static double calculateSimilarity(String a, String b) {
    final s1 = a.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final s2 = b.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // 包含匹配：包含关系直接给予 0.85 ~ 0.95 高基准分（彻底解决因正片带副标题/季数被误杀的问题）
    if (s1.contains(s2) || s2.contains(s1)) {
      final ratio = math.min(s1.length, s2.length) / math.max(s1.length, s2.length);
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

    return math.max(jaccard * 0.6 + biScore * 0.4, jaccard);
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
}
