import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../models/bangumi/bangumi_calendar.dart';
import '../models/bangumi/bangumi_collection.dart';
import '../models/bangumi/bangumi_comment.dart';
import '../models/bangumi/bangumi_episode.dart';
import '../models/bangumi/bangumi_item.dart';
import '../models/bangumi/bangumi_search_result.dart';
import '../models/bangumi/bangumi_user.dart';
import '../services/app_preferences.dart';
import '../utils/image_utils.dart';
import '../utils/timed_cache.dart';
import 'bangumi_api_exception.dart';
import 'bangumi_search_query_builder.dart';
import 'bangumi_source_preset.dart';
import 'bangumi_user_agent.dart';

export '../models/bangumi/bangumi_search_result.dart';
export 'bangumi_api_exception.dart';
export 'bangumi_source_preset.dart';
export 'bangumi_user_agent.dart';

class BangumiClient {
  /// 遵循 Bangumi API 开发者准则规范配置合规的 User-Agent
  static String get defaultUserAgent => BangumiUserAgent.defaultUserAgent;

  /// 支持按动态版本号与可选平台标识构造合规 User-Agent
  static String buildUserAgent({
    String version = AppConstants.appVersion,
    String? platform,
  }) =>
      BangumiUserAgent.build(version: version, platform: platform);

  final Dio _dio;
  String _baseUrl;
  BangumiSourcePreset _sourcePreset = BangumiSourcePreset.mirror;

  // 按照 Animaku 规范对齐 TTL 的内存缓存池
  // 1. 每日放送：按季更替，24 小时缓存
  final _calendarCache = TimedCache<List<BangumiCalendarDay>>(maxAge: const Duration(hours: 24));
  // 2. 热门 / 剧场版 / OVA：12 小时缓存
  final _trendingCache = TimedCache<List<BangumiItem>>(maxAge: const Duration(hours: 12));
  final _moviesCache = TimedCache<List<BangumiItem>>(maxAge: const Duration(hours: 12));
  final _ovaCache = TimedCache<List<BangumiItem>>(maxAge: const Duration(hours: 12));

  // 3. 搜索与分类检索分页缓存：2 小时缓存，最多保留 150 条分页查询
  final _searchCache = TimedKeyedCache<String, BangumiSearchResult>(
    maxAge: const Duration(hours: 2),
    maxEntries: 150,
  );
  // 4. 条目详情：6 小时缓存，最多保留 100 条
  final _subjectCache = TimedKeyedCache<int, BangumiItem>(
    maxAge: const Duration(hours: 6),
    maxEntries: 100,
  );
  // 5. 剧集列表：2 小时缓存，最多保留 100 条
  final _episodesCache = TimedKeyedCache<String, List<BangumiEpisode>>(
    maxAge: const Duration(hours: 2),
    maxEntries: 100,
  );
  // 6. 吐槽与评论列表：3 小时缓存，最多保留 100 条
  final _commentsCache = TimedKeyedCache<String, List<BangumiComment>>(
    maxAge: const Duration(hours: 3),
    maxEntries: 100,
  );

  // Single-Flight 机制：并发重复请求去重
  final Map<String, Future<dynamic>> _inflight = {};

  BangumiClient({
    String? baseUrl,
    Dio? dio,
  })  : _baseUrl = baseUrl ?? AppPreferences.getInitialSourcePreset().apiBase,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppPreferences.getInitialSourcePreset().apiBase,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent': defaultUserAgent,
                  'Accept': 'application/json',
                },
              ),
            ) {
    if (baseUrl != null) {
      if (baseUrl == BangumiSourcePreset.official.apiBase) {
        _sourcePreset = BangumiSourcePreset.official;
        setBangumiImageHost(BangumiSourcePreset.official.imageHost);
      } else {
        _sourcePreset = BangumiSourcePreset.mirror;
        setBangumiImageHost(BangumiSourcePreset.mirror.imageHost);
      }
    } else {
      final initial = AppPreferences.getInitialSourcePreset();
      _sourcePreset = initial;
      setBangumiImageHost(initial.imageHost);
    }
  }

  String get baseUrl => _baseUrl;
  BangumiSourcePreset get sourcePreset => _sourcePreset;

  void setSourcePreset(BangumiSourcePreset preset) {
    _sourcePreset = preset;
    updateBaseUrl(preset.apiBase);
    setBangumiImageHost(preset.imageHost);
    AppPreferences.saveSourcePreset(preset);
    clearCache();
  }

  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
    _dio.options.baseUrl = newBaseUrl;
  }

  /// 获取当前客户端在内存中缓存的 API 查询响应总数
  int get totalCachedQueries =>
      (_calendarCache.value != null ? 1 : 0) +
      (_trendingCache.value != null ? 1 : 0) +
      (_moviesCache.value != null ? 1 : 0) +
      (_ovaCache.value != null ? 1 : 0) +
      _searchCache.length +
      _subjectCache.length +
      _episodesCache.length +
      _commentsCache.length;

  /// O(1) 极速获取当前客户端在内存中缓存的 API 响应数据字节大小，彻底避免在 UI 线程全量 JSON 序列化导致卡顿
  int get dataCacheSizeBytes =>
      _calendarCache.estimatedBytes +
      _trendingCache.estimatedBytes +
      _moviesCache.estimatedBytes +
      _ovaCache.estimatedBytes +
      _searchCache.totalBytes +
      _subjectCache.totalBytes +
      _episodesCache.totalBytes +
      _commentsCache.totalBytes;

  void clearCache() {
    _calendarCache.clear();
    _trendingCache.clear();
    _moviesCache.clear();
    _ovaCache.clear();
    _searchCache.clear();
    _subjectCache.clear();
    _episodesCache.clear();
    _commentsCache.clear();
    _inflight.clear();
  }

  /// 获取每日放送时间表 (周一至周日)，带 30 分钟内存持久化缓存
  Future<List<BangumiCalendarDay>> getCalendar({bool forceRefresh = false}) async {
    if (!forceRefresh && _calendarCache.value != null) {
      return _calendarCache.value!;
    }

    try {
      final res = await _dio.get('/calendar');
      final rawList = res.data;
      if (rawList is! List) return _calendarCache.value ?? const [];

      final days = rawList.map((day) {
        if (day is Map<String, dynamic>) {
          return BangumiCalendarDay.fromJson(day);
        }
        return null;
      }).whereType<BangumiCalendarDay>().toList();

      if (days.isNotEmpty) {
        _calendarCache.set(days, days.length * 1500);
      }
      return days;
    } on DioException catch (e) {
      if (_calendarCache.staleValue != null) return _calendarCache.staleValue!;
      throw _handleDioError('获取每日放送失败', e);
    }
  }

  /// 获取首页热门番剧列表 (带内存缓存与多源降级容灾)
  Future<List<BangumiItem>> getTrending({int limit = 18, bool forceRefresh = false}) async {
    if (!forceRefresh && _trendingCache.value != null) {
      return _trendingCache.value!;
    }

    // 1. 优先尝试 next.bgm.tv /p1/trending/subjects (若无跨域限制或在原生平台)
    try {
      final res = await _dio.get(
        'https://next.bgm.tv/p1/trending/subjects',
        queryParameters: {'type': 2, 'limit': limit, 'offset': 0},
      );
      final rawData = res.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        final list = rawData['data'] as List;
        final items = list
            .whereType<Map<String, dynamic>>()
            .map((entry) {
              final subject = entry['subject'] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(entry['subject'] as Map<String, dynamic>)
                  : Map<String, dynamic>.from(entry);
              // 关键：next.bgm.tv 返回的热度值保存在外层 entry['count'] 中，需合并注入到 subject 中以正确生成 item.heat
              if (entry['count'] != null) {
                subject['heat'] = entry['count'];
              }
              if (entry['watchers'] != null) {
                subject['watchers'] = entry['watchers'];
              }
              return BangumiItem.fromJson(subject);
            })
            .toList();
        if (items.isNotEmpty) {
          _trendingCache.set(items, items.length * 1500);
          return items;
        }
      }
    } catch (_) {
      // 容错降级（如 Web 端 CORS 限制拦截时自动平滑走标准检索接口）
    }

    // 2. 降级使用标准 v0 接口按近半年时间 + 热度排行检索 (全端/跨域 100% 兼容)
    try {
      final now = DateTime.now();
      final halfYearAgo = now.subtract(const Duration(days: 180));
      final dateStr =
          '${halfYearAgo.year}-${halfYearAgo.month.toString().padLeft(2, '0')}-01';

      final items = await search(
        '',
        sort: 'heat',
        airDate: ['>=$dateStr'],
        limit: limit,
      );
      if (items.isNotEmpty) {
        _trendingCache.set(items, items.length * 1500);
        return items;
      }
    } catch (_) {}

    return _trendingCache.staleValue ?? const [];
  }

  /// 获取热门剧场版列表 (带内存缓存)
  Future<List<BangumiItem>> getHotMovies({int limit = 18, bool forceRefresh = false}) async {
    if (!forceRefresh && _moviesCache.value != null) {
      return _moviesCache.value!;
    }

    try {
      final items = await search(
        '',
        tags: const ['剧场版'],
        sort: 'heat',
        limit: limit,
      );
      if (items.isNotEmpty) {
        _moviesCache.set(items, items.length * 1500);
        return items;
      }
    } catch (e) {
      developer.log('获取热门剧场版失败: $e');
    }
    return _moviesCache.staleValue ?? const [];
  }

  /// 获取热门 OVA 列表 (带 30 分钟内存持久化缓存)
  Future<List<BangumiItem>> getHotOva({int limit = 18, bool forceRefresh = false}) async {
    if (!forceRefresh && _ovaCache.value != null) {
      return _ovaCache.value!;
    }

    try {
      final items = await search(
        '',
        tags: const ['OVA'],
        sort: 'heat',
        limit: limit,
      );
      if (items.isNotEmpty) {
        _ovaCache.set(items, items.length * 1500);
        return items;
      }
    } catch (e) {
      developer.log('获取热门 OVA 失败: $e');
    }
    return _ovaCache.staleValue ?? const [];
  }

  /// 获取番剧条目详情 (带 6 小时内存缓存与 Single-Flight 并发合并)
  Future<BangumiItem> getSubject(int subjectId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _subjectCache.get(subjectId);
      if (cached != null) return cached;
    }

    final inflightKey = 'subject_$subjectId';
    if (_inflight.containsKey(inflightKey)) {
      return await (_inflight[inflightKey] as Future<BangumiItem>);
    }

    final future = () async {
      try {
        final res = await _dio.get('/v0/subjects/$subjectId');
        if (res.data is Map<String, dynamic>) {
          final item = BangumiItem.fromJson(res.data as Map<String, dynamic>);
          _subjectCache.set(subjectId, item, 4096);
          return item;
        }
        throw const BangumiApiException('响应格式不正确');
      } on DioException catch (e) {
        final stale = _subjectCache.getStale(subjectId);
        if (stale != null) return stale;
        throw _handleDioError('获取番剧详情失败 (ID: $subjectId)', e);
      }
    }();

    _inflight[inflightKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(inflightKey);
    }
  }

  /// 获取番剧剧集列表 (默认 type=0 为正片，1 为 SP，带 2 小时内存缓存)
  Future<List<BangumiEpisode>> getEpisodes(
    int subjectId, {
    int type = 0,
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${subjectId}_${type}_${limit}_$offset';
    if (!forceRefresh) {
      final cached = _episodesCache.get(cacheKey);
      if (cached != null) return cached;
    }

    final inflightKey = 'episodes_$cacheKey';
    if (_inflight.containsKey(inflightKey)) {
      return await (_inflight[inflightKey] as Future<List<BangumiEpisode>>);
    }

    final Future<List<BangumiEpisode>> future = () async {
      try {
        final res = await _dio.get(
          '/v0/episodes',
          queryParameters: {
            'subject_id': subjectId,
            'type': type,
            'limit': limit,
            'offset': offset,
          },
        );

        final data = res.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          final list = data['data'] as List;
          final eps = list
              .whereType<Map<String, dynamic>>()
              .map((ep) => BangumiEpisode.fromJson(ep))
              .toList();
          _episodesCache.set(cacheKey, eps, eps.length * 400 + 256);
          return eps;
        }
        return const <BangumiEpisode>[];
      } on DioException catch (e) {
        final stale = _episodesCache.getStale(cacheKey);
        if (stale != null) return stale;
        throw _handleDioError('获取剧集列表失败 (ID: $subjectId)', e);
      }
    }();

    _inflight[inflightKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(inflightKey);
    }
  }

  /// 搜索番剧条目 (优先使用 v0 结构化搜索，必要时降级旧版搜索)
  Future<List<BangumiItem>> search(
    String keyword, {
    int limit = 20,
    int offset = 0,
    String? sort,
    List<String>? tags,
    int? year,
    List<String>? airDate,
    int type = 2, // 2 = 动画
    bool forceRefresh = false,
  }) async {
    final result = await searchWithTotal(
      keyword,
      limit: limit,
      offset: offset,
      sort: sort,
      tags: tags,
      year: year,
      airDate: airDate,
      type: type,
      forceRefresh: forceRefresh,
    );
    return result.items;
  }

  String _buildSearchCacheKey({
    required String keyword,
    required String? sort,
    required List<String>? tags,
    required int? year,
    required List<String>? airDate,
    required int type,
    required int limit,
    required int offset,
  }) {
    final sortedTags = tags != null ? ([...tags]..sort()).join(',') : '';
    final sortedAirDate = airDate != null ? ([...airDate]..sort()).join(',') : '';
    return '$keyword|$sort|$sortedTags|$year|$sortedAirDate|$type|$limit|$offset';
  }

  /// 同步检查是否有未过期的搜索/分类缓存结果（用于切换分类时 0ms 瞬间呈现，消除骨架屏闪烁）
  BangumiSearchResult? peekSearchCache(
    String keyword, {
    int limit = 20,
    int offset = 0,
    String? sort,
    List<String>? tags,
    int? year,
    List<String>? airDate,
    int type = 2,
  }) {
    final cacheKey = _buildSearchCacheKey(
      keyword: keyword.trim(),
      sort: sort,
      tags: tags,
      year: year,
      airDate: airDate,
      type: type,
      limit: limit,
      offset: offset,
    );
    return _searchCache.peek(cacheKey);
  }

  /// 结构化搜索并返回分页与总数结果 (供分类/探索瀑布流与高级筛选使用，带 2 小时内存缓存与容灾)
  Future<BangumiSearchResult> searchWithTotal(
    String keyword, {
    int limit = 20,
    int offset = 0,
    String? sort,
    List<String>? tags,
    int? year,
    List<String>? airDate,
    int type = 2, // 2 = 动画
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final trimmed = keyword.trim();
    final cacheKey = _buildSearchCacheKey(
      keyword: trimmed,
      sort: sort,
      tags: tags,
      year: year,
      airDate: airDate,
      type: type,
      limit: limit,
      offset: offset,
    );

    if (!forceRefresh) {
      final cached = _searchCache.get(cacheKey);
      if (cached != null) return cached;
    }

    final inflightKey = 'search_$cacheKey';
    if (_inflight.containsKey(inflightKey)) {
      return await (_inflight[inflightKey] as Future<BangumiSearchResult>);
    }

    final future = () async {
      final payload = BangumiSearchQueryBuilder.buildPayload(
        keyword: keyword,
        sort: sort,
        tags: tags,
        year: year,
        airDate: airDate,
        type: type,
      );

      if (payload == null) {
        return BangumiSearchResult.empty;
      }

      final isSortByDate = sort == 'date' || sort == 'airdate';

      try {
        final res = await _dio.post(
          '/v0/search/subjects',
          data: payload,
          queryParameters: {
            'limit': limit,
            'offset': offset,
          },
          cancelToken: cancelToken,
        );

        final data = res.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          final list = data['data'] as List;
          final items = list
              .whereType<Map<String, dynamic>>()
              .map((item) => BangumiItem.fromJson(item))
              .toList();

          if (isSortByDate) {
            items.sort((a, b) => b.airDate.compareTo(a.airDate));
          }

          final total = (data['total'] is num)
              ? (data['total'] as num).toInt()
              : (offset + items.length);

          final result = BangumiSearchResult(
            items: items,
            total: total,
            limit: limit,
            offset: offset,
          );
          _searchCache.set(cacheKey, result, result.items.length * 1500 + 512);
          return result;
        }
        return BangumiSearchResult.empty;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          rethrow;
        }
        final stale = _searchCache.getStale(cacheKey);
        if (stale != null) return stale;

        if (trimmed.isEmpty) {
          throw _handleDioError('筛选番剧列表失败', e);
        }
        // 容错: 关键词搜索失败时尝试旧版搜索接口作为回退
        developer.log('v0 search 失败，尝试旧版回退: ${e.message}');
        try {
          final fallbackRes = await _dio.get(
            '/search/subject/${Uri.encodeComponent(trimmed)}',
            queryParameters: {
              'type': type,
              'responseGroup': 'small',
              'max_results': limit,
              'start': offset,
            },
            cancelToken: cancelToken,
          );
          final list = fallbackRes.data?['list'];
          if (list is List) {
            final items = list
                .whereType<Map<String, dynamic>>()
                .map((item) => BangumiItem.fromJson(item))
                .toList();
            final total = (fallbackRes.data?['results'] is num)
                ? (fallbackRes.data['results'] as num).toInt()
                : (offset + items.length);
            final result = BangumiSearchResult(
              items: items,
              total: total,
              limit: limit,
              offset: offset,
            );
            _searchCache.set(cacheKey, result, result.items.length * 1500 + 512);
            return result;
          }
        } catch (_) {
          // 忽略回退失败，抛出主要异常
        }
        throw _handleDioError('搜索番剧失败: "$trimmed"', e);
      }
    }();

    _inflight[inflightKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(inflightKey);
    }
  }

  /// 获取条目吐槽与讨论 (带 3 小时内存缓存)
  Future<List<BangumiComment>> getComments(
    int subjectId, {
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${subjectId}_${limit}_$offset';
    if (!forceRefresh) {
      final cached = _commentsCache.get(cacheKey);
      if (cached != null) return cached;
    }

    final inflightKey = 'comments_$cacheKey';
    if (_inflight.containsKey(inflightKey)) {
      return await (_inflight[inflightKey] as Future<List<BangumiComment>>);
    }

    final Future<List<BangumiComment>> future = () async {
      try {
        final res = await _dio.get(
          '/v0/subjects/$subjectId/comments',
          queryParameters: {
            'limit': limit,
            'offset': offset,
          },
        );

        final data = res.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          final list = data['data'] as List;
          final comments = list
              .whereType<Map<String, dynamic>>()
              .map((c) => BangumiComment.fromJson(c))
              .toList();
          _commentsCache.set(cacheKey, comments, comments.length * 600 + 256);
          return comments;
        }
        return const <BangumiComment>[];
      } on DioException catch (e) {
        final stale = _commentsCache.getStale(cacheKey);
        if (stale != null) return stale;
        throw _handleDioError('获取评论失败 (ID: $subjectId)', e);
      }
    }();

    _inflight[inflightKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(inflightKey);
    }
  }

  /// 获取当前登录用户信息 (需要 Bearer Token)
  Future<BangumiUser> getCurrentUser(String token) async {
    try {
      final res = await _dio.get(
        '/v0/me',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (res.data is Map<String, dynamic>) {
        return BangumiUser.fromJson(res.data as Map<String, dynamic>);
      }
      throw const BangumiApiException('用户资料解析失败');
    } on DioException catch (e) {
      throw _handleDioError('获取当前用户信息失败', e);
    }
  }

  /// 获取用户对某条目的收藏状态
  Future<BangumiCollectionEntry?> getCollection(int subjectId, String token) async {
    try {
      final res = await _dio.get(
        '/v0/users/-/collections/$subjectId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (res.data is Map<String, dynamic>) {
        return BangumiCollectionEntry.fromJson(res.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // 未收藏
      }
      throw _handleDioError('获取条目收藏状态失败', e);
    }
  }

  /// 修改/保存用户对某条目的收藏状态
  Future<bool> setCollection(
    int subjectId,
    CollectType type,
    String token, {
    int? rate,
    String? comment,
  }) async {
    final bangumiType = type.toBangumiType();
    if (bangumiType == null) {
      return false;
    }

    try {
      final payload = <String, dynamic>{
        'type': bangumiType,
      };
      if (rate != null) payload['rate'] = rate;
      if (comment != null) payload['comment'] = comment;

      final res = await _dio.post(
        '/v0/users/-/collections/$subjectId',
        data: payload,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } on DioException catch (e) {
      throw _handleDioError('更新收藏状态失败', e);
    }
  }

  BangumiApiException _handleDioError(String prefix, DioException e) =>
      BangumiApiException.fromDio(prefix, e);
}
