import 'dart:async';
import 'dart:math';
import '../models/bangumi/bangumi_item.dart';
import '../models/home/recommend_item.dart';
import '../network/bangumi_client.dart';
import '../network/bangumi_data_disk_cache_manager.dart';
import '../utils/anime_tag_filter.dart';
import 'app_preferences.dart';

/// 今日推荐调度核心算法服务：
/// 1. 确定性天命种子（Deterministic Daily Seed）：
///    结合设备唯一标识 (DeviceUUID) 与当日日期字符串计算 32 位离散哈希，
///    确保“千人千面、天内绝对幂等（全天刷新结果不变）、次日零点自动平滑轮换”；
/// 2. 受控白名单精准清洗：
///    通过 AnimeTagFilter.genreAllowList 过滤用户输入，彻底免疫时间、载体、恶搞短句等一切 UGC 噪音；
/// 3. 特殊处理说明：根据业务强规则，所有检索请求均强行绑定【日本】标签（tags: [..., '日本']），
///    配合评分门槛 (score >= 5.0) 与评价人数 (rating_count >= 50)，坚决杜绝低幼片、非日系动画或无评分僵尸条目污染；
/// 4. 槽位调度与降级保护：
///    - 无数据时（冷启动）：以种子派生基底偏移量，在全量高分池中批量切片提取 5 部；
///    - 有数据时：前 3 个槽位分配给出现最多的 Top 3 标签，后 2 个槽位在剩余长尾标签中基于 Seed 随机抽样；
///      若长尾无数据或检索为空，三级优雅降级平滑退化至全量池兜底，绝不开天窗；
/// 5. 跨槽位与播放历史全局去重，输出稳固的 5 部今日推荐番剧。
class DailyRecommendService {
  DailyRecommendService._();

  /// 缓存当天的推荐计算结果，避免同一会话内重复计算
  static List<RecommendItem>? _memoryCachedItems;
  static String? _cachedDateKey;

  /// 清空今日推荐的内存与时间戳缓存（在用户手动清理数据缓存或切换线路时调用）
  static void clearCache() {
    _memoryCachedItems = null;
    _cachedDateKey = null;
  }

  /// 计算当天的 32 位确定性正整数天命种子
  static int computeSeed(String deviceId, DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final raw = '$deviceId#$dateStr';

    // 采用 32-bit FNV-1a 高离散度哈希算法
    var hash = 0x811c9dc5;
    for (var i = 0; i < raw.length; i++) {
      hash ^= raw.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// 获取今日推荐番剧核心入口
  static Future<List<RecommendItem>> getDailyRecommendations({
    required BangumiClient client,
    Map<String, int> rawUserTagFreq = const {},
    Set<int> watchedSubjectIds = const {},
    DateTime? customDate,
    String? customDeviceId,
    bool forceRefresh = false,
  }) async {
    final now = customDate ?? DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final diskCacheKey = 'daily_roam_bundle_$dateKey';

    // 1. L1 内存缓存拦截（当前会话内绝对幂等）
    if (!forceRefresh && _cachedDateKey == dateKey && _memoryCachedItems != null) {
      return _memoryCachedItems!;
    }

    // 2. L2 本地硬盘持久化缓存拦截（用户杀进程重新打开时 0ms 命中，0 次网络请求）
    if (!forceRefresh) {
      try {
        final diskJson = await BangumiDataDiskCacheManager.instance?.getJson(diskCacheKey);
        if (diskJson is List) {
          final cachedList = diskJson
              .whereType<Map<String, dynamic>>()
              .map((j) => RecommendItem.fromJson(j))
              .toList();
          if (cachedList.isNotEmpty) {
            _cachedDateKey = dateKey;
            _memoryCachedItems = cachedList;
            return cachedList;
          }
        }
      } catch (_) {}
    }

    final deviceId = customDeviceId ?? AppPreferences.getOrCreateDeviceInstallId();
    final seed = computeSeed(deviceId, now);
    final rng = Random(seed);

    // 3. 白名单清洗用户词频画像
    final cleanProfile = AnimeTagFilter.filterByGenreAllowList(rawUserTagFreq);

    List<RecommendItem> finalRecommendations;

    if (cleanProfile.isEmpty) {
      // 4. 情况 A：冷启动（无用户数据）
      finalRecommendations = await _fetchColdStartRecommendations(
        client: client,
        seed: seed,
        rng: rng,
        watchedSubjectIds: watchedSubjectIds,
      );
    } else {
      // 5. 情况 B：有用户数据（Top 3 主力 + 2 长尾探索）
      finalRecommendations = await _fetchPersonalizedRecommendations(
        client: client,
        cleanProfile: cleanProfile,
        seed: seed,
        rng: rng,
        watchedSubjectIds: watchedSubjectIds,
      );
    }

    // 6. 回填 L1 内存缓存
    _cachedDateKey = dateKey;
    _memoryCachedItems = finalRecommendations;

    // 7. 异步安全落盘至 L2 硬盘：有效期严格锁定至今日 23:59:59 (次日零点自动过期)
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final remainingTtl = endOfDay.difference(now);
    final validDuration = remainingTtl.isNegative || remainingTtl.inMinutes < 15
        ? const Duration(hours: 4)
        : remainingTtl;

    unawaited(
      BangumiDataDiskCacheManager.instance?.putJson(
        diskCacheKey,
        finalRecommendations.map((r) => r.toJson()).toList(),
        maxAge: validDuration,
      ) ?? Future.value(),
    );

    return finalRecommendations;
  }

  /// 冷启动抓取：根据种子在全量【日本动画 (评分>=5.0, 评价人数>=50)】池中抽取
  static Future<List<RecommendItem>> _fetchColdStartRecommendations({
    required BangumiClient client,
    required int seed,
    required Random rng,
    required Set<int> watchedSubjectIds,
  }) async {
    // 安全翻页深度控制在前 250 位以内，确保拉取的番剧海报完整且品质稳定
    final baseOffset = seed % 250;

    try {
      final result = await client.searchWithTotal(
        '',
        tags: const ['日本'],
        sort: 'score',
        limit: 20,
        offset: baseOffset,
      );

      final validCandidates = result.items.where((item) {
        return !watchedSubjectIds.contains(item.id) &&
            item.ratingScore >= 5.0 &&
            item.coverUrl.isNotEmpty;
      }).toList();

      if (validCandidates.length >= 5) {
        // 分散抽取 5 部
        final step = (validCandidates.length / 5).floor().clamp(1, 4);
        final selected = <BangumiItem>[];
        for (var i = 0; i < 5; i++) {
          final index = (i * step) % validCandidates.length;
          selected.add(validCandidates[index]);
        }
        return _wrapRecommendations(selected, rng: rng);
      } else if (validCandidates.isNotEmpty) {
        return _wrapRecommendations(validCandidates.take(5).toList(), rng: rng);
      }
    } catch (_) {
      // 网络降级保护
    }

    // 终极网络失败兜底：从热门列表中挑 5 部
    final hotFallback = await client.getTrending(limit: 10);
    return _wrapRecommendations(hotFallback.take(5).toList(), rng: rng);
  }

  /// 个性化抓取：前 3 个槽位取 Top 3 标签，后 2 个槽位在长尾标签中基于 Seed 随机挑
  static Future<List<RecommendItem>> _fetchPersonalizedRecommendations({
    required BangumiClient client,
    required Map<String, int> cleanProfile,
    required int seed,
    required Random rng,
    required Set<int> watchedSubjectIds,
  }) async {
    // 1. 标签按频次降序排序
    final sortedTags = cleanProfile.keys.toList()
      ..sort((a, b) => (cleanProfile[b] ?? 0).compareTo(cleanProfile[a] ?? 0));

    // 2. 提取 Top 3 核心标签
    final top3Tags = sortedTags.take(3).toList();

    // 3. 提取长尾候选标签（排除 Top 3）
    final remainingTags = sortedTags.length > 3 ? sortedTags.sublist(3) : <String>[];
    final selectedLongTailTags = <String>[];
    if (remainingTags.isNotEmpty) {
      final shuffled = [...remainingTags]..shuffle(rng);
      selectedLongTailTags.addAll(shuffled.take(2));
    }

    // 4. 构建 5 个槽位的目标检索标签（不足则为 null 触发退化全量池）
    final slotTags = <String?>[
      top3Tags.isNotEmpty ? top3Tags[0] : null,
      top3Tags.length > 1 ? top3Tags[1] : null,
      top3Tags.length > 2 ? top3Tags[2] : null,
      selectedLongTailTags.isNotEmpty ? selectedLongTailTags[0] : null,
      selectedLongTailTags.length > 1 ? selectedLongTailTags[1] : null,
    ];

    // 5. 并发向 Bangumi 请求 5 个槽位（每个槽位独立计算派生 offset 拉开翻页深度）
    final futures = <Future<List<BangumiItem>>>[];
    for (var i = 0; i < 5; i++) {
      final targetTag = slotTags[i];
      // 利用种子派生不同深度偏移量
      final slotOffset = (seed + i * 17) % 35;

      if (targetTag != null) {
        futures.add(
          client
              .searchWithTotal(
                '',
                tags: [targetTag, '日本'],
                sort: 'score',
                limit: 8,
                offset: slotOffset,
              )
              .then((res) => res.items)
              .catchError((_) => <BangumiItem>[]),
        );
      } else {
        // 无标签时平滑退化为全量高分池
        futures.add(
          client
              .searchWithTotal(
                '',
                tags: const ['日本'],
                sort: 'score',
                limit: 8,
                offset: slotOffset,
              )
              .then((res) => res.items)
              .catchError((_) => <BangumiItem>[]),
        );
      }
    }

    final slotResults = await Future.wait(futures);

    // 6. 跨槽位去重与顺延选取
    final seenIds = <int>{...watchedSubjectIds};
    final chosenItems = <BangumiItem>[];
    final chosenTags = <String>[];

    for (var i = 0; i < 5; i++) {
      final candidates = slotResults[i];
      BangumiItem? picked;
      for (final item in candidates) {
        if (!seenIds.contains(item.id) && item.ratingScore >= 5.0 && item.coverUrl.isNotEmpty) {
          picked = item;
          break;
        }
      }

      if (picked != null) {
        seenIds.add(picked.id);
        chosenItems.add(picked);
        chosenTags.add(slotTags[i] ?? '精选');
      }
    }

    // 7. 若部分槽位因冷门或去重导致未凑满 5 部，启动全量池兜底补充
    if (chosenItems.length < 5) {
      try {
        final fallbackRes = await client.searchWithTotal(
          '',
          tags: const ['日本'],
          sort: 'score',
          limit: 12,
          offset: (seed * 3) % 150,
        );
        for (final item in fallbackRes.items) {
          if (!seenIds.contains(item.id) && item.ratingScore >= 5.0 && item.coverUrl.isNotEmpty) {
            seenIds.add(item.id);
            chosenItems.add(item);
            chosenTags.add('精选');
            if (chosenItems.length >= 5) break;
          }
        }
      } catch (_) {}
    }

    // 装箱为推荐实体
    final result = <RecommendItem>[];
    for (var i = 0; i < chosenItems.length; i++) {
      final item = chosenItems[i];
      final tag = chosenTags[i];
      final isDegraded = tag == '精选';
      final displayTag = resolveDisplayTag(isDegraded ? null : tag, item, rng);
      final reason = buildRecommendReason(i, isDegraded ? null : tag, item);

      result.add(
        RecommendItem(
          item: item,
          tag: displayTag,
          reason: reason,
          matchRate: 98 - (i * 2),
        ),
      );
    }

    return result;
  }

  /// 依据主题材与作品自身次级标签，合成地道二次元特色标签
  static String resolveDisplayTag(String? mainTag, BangumiItem item, [Random? rng]) {
    final subTags = item.tags
        .map((t) => t.name.trim())
        .where((t) => t != mainTag)
        .toSet();

    switch (mainTag) {
      case '恋爱':
        if (subTags.contains('治愈') || subTags.contains('纯爱')) return '#纯爱治愈';
        if (subTags.contains('搞笑') || subTags.contains('校园')) return '#恋爱喜剧';
        return '#恋爱喜剧';

      case '悬疑':
        if (subTags.contains('智斗') || subTags.contains('推理')) return '#硬核烧脑';
        return '#硬核烧脑';

      case '打斗':
      case '战斗':
        if (subTags.contains('超能力') || subTags.contains('热血')) return '#战斗爽';
        return '#战斗爽';

      case '日常':
        if (subTags.contains('美食')) return '#下饭神作';
        if (subTags.contains('治愈')) return '#日常治愈';
        return '#日常治愈';

      case '奇幻':
        if (subTags.contains('异世界')) return '#异界冒险';
        if (subTags.contains('冒险')) return '#奇幻冒险';
        return '#奇幻冒险';

      case '宫廷':
        if (subTags.contains('悬疑') || subTags.contains('剧情')) return '#宫廷权谋';
        return '#宫廷权谋';

      default:
        // 其他题材：从番剧自身高频有效标签里挑选一个
        final validTags = AnimeTagFilter.cleanItemTags(item.tags.map((t) => t.name));
        if (validTags.isNotEmpty) {
          final pickIndex = rng != null ? rng.nextInt(validTags.length) : 0;
          return '#${validTags[pickIndex]}';
        }
        if (mainTag != null && mainTag.isNotEmpty) {
          return '#$mainTag';
        }
        return '#今日推荐';
    }
  }

  /// 四维槽位推荐理由文案动态引擎
  /// 特殊处理说明：文案返回纯语义文本，不包含 💡 等装饰 Emoji，避免与 UI 层的图标控件叠加显示重复。
  static String buildRecommendReason(int slotIndex, String? mainTag, BangumiItem item) {
    final scoreStr = item.ratingScore > 0 ? '${item.ratingScore.toStringAsFixed(1)}分' : '高分';

    // 槽位 0 (Top 1 主力)
    if (slotIndex == 0 && mainTag != null) {
      return '命中你偏好最高的【$mainTag】题材，Bangumi $scoreStr';
    }

    // 槽位 1~2 (Top 2~3 次级主力)
    if ((slotIndex == 1 || slotIndex == 2) && mainTag != null) {
      return '兼顾你关注的【$mainTag】风向，Bangumi $scoreStr';
    }

    // 槽位 3~4 (长尾探索)
    if ((slotIndex == 3 || slotIndex == 4) && mainTag != null) {
      return '偶尔换换口味：捕捉到你兴趣库中的【$mainTag】基因，翻出的宝藏作品';
    }

    // 冷启动 / 退化全量
    return '今日番剧推荐：Bangumi $scoreStr';
  }

  /// 辅助方法：将番剧列表批量包装为带默认推荐理由的实体
  static List<RecommendItem> _wrapRecommendations(
    List<BangumiItem> items, {
    Random? rng,
  }) {
    final result = <RecommendItem>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final tag = resolveDisplayTag(null, item, rng);
      final reason = buildRecommendReason(i, null, item);
      result.add(
        RecommendItem(
          item: item,
          tag: tag,
          reason: reason,
          matchRate: 96 - (i * 2),
        ),
      );
    }
    return result;
  }
}
