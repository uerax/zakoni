import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../models/bangumi/bangumi_calendar.dart';
import '../models/bangumi/bangumi_collection.dart';
import '../models/bangumi/bangumi_comment.dart';
import '../models/bangumi/bangumi_episode.dart';
import '../models/bangumi/bangumi_item.dart';
import '../models/bangumi/bangumi_user.dart';
import '../utils/image_utils.dart';

enum BangumiSourcePreset {
  mirror(
    'https://bgmapi.anibt.net',
    'bgmimg.anibt.net',
    '镜像加速线路 (推荐，Anycast CDN 国内直连)',
  ),
  official(
    'https://api.bgm.tv',
    'lain.bgm.tv',
    '官方直连线路 (海外用户推荐)',
  );

  final String apiBase;
  final String imageHost;
  final String label;

  const BangumiSourcePreset(this.apiBase, this.imageHost, this.label);
}

class BangumiApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic error;

  const BangumiApiException(this.message, {this.statusCode, this.error});

  @override
  String toString() => 'BangumiApiException: [$statusCode] $message';
}

/// Bangumi 搜索与分类检索分页结果封装
class BangumiSearchResult {
  final List<BangumiItem> items;
  final int total;
  final int limit;
  final int offset;

  const BangumiSearchResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  bool get hasMore => offset + items.length < total;

  static const empty = BangumiSearchResult(
    items: [],
    total: 0,
    limit: 20,
    offset: 0,
  );
}

class BangumiClient {
  /// 遵循 Bangumi API 开发者准则规范配置合规的 User-Agent
  /// 包含开发者个人 ID、应用名称、动态版本号变量及项目主页
  static String get defaultUserAgent => AppConstants.bangumiUserAgent;

  /// 支持按动态版本号与可选平台标识构造合规 User-Agent
  static String buildUserAgent({
    String version = AppConstants.appVersion,
    String? platform,
  }) {
    final platformInfo = platform != null ? ' ($platform)' : '';
    return '${AppConstants.developerId}/${AppConstants.appName}/$version$platformInfo (${AppConstants.projectUrl})';
  }

  final Dio _dio;
  String _baseUrl;
  BangumiSourcePreset _sourcePreset = BangumiSourcePreset.mirror;

  // 内存防抖缓存，避免同一会话在页面/Tab之间切换时无意义地重复请求接口
  List<BangumiCalendarDay>? _calendarCache;
  DateTime? _calendarCacheTime;

  List<BangumiItem>? _trendingCache;
  DateTime? _trendingCacheTime;

  List<BangumiItem>? _moviesCache;
  DateTime? _moviesCacheTime;

  List<BangumiItem>? _ovaCache;
  DateTime? _ovaCacheTime;

  BangumiClient({
    String? baseUrl,
    Dio? dio,
  })  : _baseUrl = baseUrl ?? BangumiSourcePreset.mirror.apiBase,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? BangumiSourcePreset.mirror.apiBase,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent': defaultUserAgent,
                  'Accept': 'application/json',
                },
              ),
            ) {
    if (baseUrl == BangumiSourcePreset.official.apiBase) {
      _sourcePreset = BangumiSourcePreset.official;
      setBangumiImageHost(BangumiSourcePreset.official.imageHost);
    } else {
      _sourcePreset = BangumiSourcePreset.mirror;
      setBangumiImageHost(BangumiSourcePreset.mirror.imageHost);
    }
  }

  String get baseUrl => _baseUrl;
  BangumiSourcePreset get sourcePreset => _sourcePreset;

  void setSourcePreset(BangumiSourcePreset preset) {
    _sourcePreset = preset;
    updateBaseUrl(preset.apiBase);
    setBangumiImageHost(preset.imageHost);
    clearCache();
  }

  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
    _dio.options.baseUrl = newBaseUrl;
  }

  void clearCache() {
    _calendarCache = null;
    _calendarCacheTime = null;
    _trendingCache = null;
    _trendingCacheTime = null;
    _moviesCache = null;
    _moviesCacheTime = null;
    _ovaCache = null;
    _ovaCacheTime = null;
  }

  /// 获取每日放送时间表 (周一至周日)，带 30 分钟内存持久化缓存
  Future<List<BangumiCalendarDay>> getCalendar({bool forceRefresh = false}) async {
    if (!forceRefresh && _calendarCache != null && _calendarCacheTime != null) {
      if (DateTime.now().difference(_calendarCacheTime!).inMinutes < 30) {
        return _calendarCache!;
      }
    }

    try {
      final res = await _dio.get('/calendar');
      final rawList = res.data;
      if (rawList is! List) return _calendarCache ?? const [];

      final days = rawList.map((day) {
        if (day is Map<String, dynamic>) {
          return BangumiCalendarDay.fromJson(day);
        }
        return null;
      }).whereType<BangumiCalendarDay>().toList();

      if (days.isNotEmpty) {
        _calendarCache = days;
        _calendarCacheTime = DateTime.now();
      }
      return days;
    } on DioException catch (e) {
      if (_calendarCache != null) return _calendarCache!;
      throw _handleDioError('获取每日放送失败', e);
    }
  }

  /// 获取首页热门番剧列表 (带内存缓存与多源降级容灾)
  Future<List<BangumiItem>> getTrending({int limit = 18, bool forceRefresh = false}) async {
    if (!forceRefresh && _trendingCache != null && _trendingCacheTime != null) {
      if (DateTime.now().difference(_trendingCacheTime!).inMinutes < 30) {
        return _trendingCache!;
      }
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
          _trendingCache = items;
          _trendingCacheTime = DateTime.now();
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
        _trendingCache = items;
        _trendingCacheTime = DateTime.now();
        return items;
      }
    } catch (_) {}

    return _trendingCache ?? const [];
  }

  /// 获取热门剧场版列表 (带内存缓存)
  Future<List<BangumiItem>> getHotMovies({int limit = 18, bool forceRefresh = false}) async {
    if (!forceRefresh && _moviesCache != null && _moviesCacheTime != null) {
      if (DateTime.now().difference(_moviesCacheTime!).inMinutes < 30) {
        return _moviesCache!;
      }
    }

    try {
      final items = await search(
        '',
        tags: const ['剧场版'],
        sort: 'heat',
        limit: limit,
      );
      if (items.isNotEmpty) {
        _moviesCache = items;
        _moviesCacheTime = DateTime.now();
        return items;
      }
    } catch (e) {
      developer.log('获取热门剧场版失败: $e');
    }
    return _moviesCache ?? const [];
  }

  /// 获取热门 OVA 列表 (带 30 分钟内存持久化缓存)
  Future<List<BangumiItem>> getHotOva({int limit = 18, bool forceRefresh = false}) async {
    if (!forceRefresh && _ovaCache != null && _ovaCacheTime != null) {
      if (DateTime.now().difference(_ovaCacheTime!).inMinutes < 30) {
        return _ovaCache!;
      }
    }

    try {
      final items = await search(
        '',
        tags: const ['OVA'],
        sort: 'heat',
        limit: limit,
      );
      if (items.isNotEmpty) {
        _ovaCache = items;
        _ovaCacheTime = DateTime.now();
        return items;
      }
    } catch (e) {
      developer.log('获取热门 OVA 失败: $e');
    }
    return _ovaCache ?? const [];
  }

  /// 获取番剧条目详情
  Future<BangumiItem> getSubject(int subjectId) async {
    try {
      final res = await _dio.get('/v0/subjects/$subjectId');
      if (res.data is Map<String, dynamic>) {
        return BangumiItem.fromJson(res.data as Map<String, dynamic>);
      }
      throw const BangumiApiException('响应格式不正确');
    } on DioException catch (e) {
      throw _handleDioError('获取番剧详情失败 (ID: $subjectId)', e);
    }
  }

  /// 获取番剧剧集列表 (默认 type=0 为正片，1 为 SP)
  Future<List<BangumiEpisode>> getEpisodes(
    int subjectId, {
    int type = 0,
    int limit = 100,
    int offset = 0,
  }) async {
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
        return list
            .whereType<Map<String, dynamic>>()
            .map((ep) => BangumiEpisode.fromJson(ep))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw _handleDioError('获取剧集列表失败 (ID: $subjectId)', e);
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
    );
    return result.items;
  }

  /// 结构化搜索并返回分页与总数结果 (供分类/探索瀑布流与高级筛选使用)
  Future<BangumiSearchResult> searchWithTotal(
    String keyword, {
    int limit = 20,
    int offset = 0,
    String? sort,
    List<String>? tags,
    int? year,
    List<String>? airDate,
    int type = 2, // 2 = 动画
  }) async {
    final trimmed = keyword.trim();
    // 只有当没有关键词、也没有任何筛选过滤条件时才直接返回空
    if (trimmed.isEmpty &&
        (tags == null || tags.isEmpty) &&
        year == null &&
        (airDate == null || airDate.isEmpty) &&
        sort == null) {
      return BangumiSearchResult.empty;
    }

    // 处理排序逻辑：Bangumi 官方 v0 不支持 date 排序，参照 animaku 上游使用 heat，客户端本地按放送日期倒序
    final isSortByDate = sort == 'date' || sort == 'airdate';
    final upstreamSort = isSortByDate ? 'heat' : sort;

    try {
      final filter = <String, dynamic>{
        'type': [type],
        'nsfw': false,
      };
      if (tags != null && tags.isNotEmpty) {
        filter['tag'] = tags;
      }
      if (year != null) {
        filter['air_date'] = ['>=$year-01-01', '<=$year-12-31'];
      }
      if (airDate != null && airDate.isNotEmpty) {
        filter['air_date'] = airDate;
      }
      if (upstreamSort == 'rank' || upstreamSort == 'score') {
        filter['rank'] = ['>0', '<=99999'];
      }

      final payload = <String, dynamic>{
        'filter': filter,
      };
      if (trimmed.isNotEmpty) {
        payload['keyword'] = trimmed;
      }
      if (upstreamSort != null && upstreamSort.isNotEmpty) {
        payload['sort'] = upstreamSort;
      }

      final res = await _dio.post(
        '/v0/search/subjects',
        data: payload,
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
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

        return BangumiSearchResult(
          items: items,
          total: total,
          limit: limit,
          offset: offset,
        );
      }
      return BangumiSearchResult.empty;
    } on DioException catch (e) {
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
          return BangumiSearchResult(
            items: items,
            total: total,
            limit: limit,
            offset: offset,
          );
        }
      } catch (_) {
        // 忽略回退失败，抛出主要异常
      }
      throw _handleDioError('搜索番剧失败: "$trimmed"', e);
    }
  }

  /// 获取条目吐槽与讨论
  Future<List<BangumiComment>> getComments(
    int subjectId, {
    int limit = 20,
    int offset = 0,
  }) async {
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
        return list
            .whereType<Map<String, dynamic>>()
            .map((c) => BangumiComment.fromJson(c))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw _handleDioError('获取评论失败 (ID: $subjectId)', e);
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

  BangumiApiException _handleDioError(String prefix, DioException e) {
    final status = e.response?.statusCode;
    final resData = e.response?.data;
    String message = e.message ?? '未知网络异常';

    if (resData is Map && resData.containsKey('description')) {
      message = resData['description'].toString();
    } else if (resData is Map && resData.containsKey('message')) {
      message = resData['message'].toString();
    }

    return BangumiApiException(
      '$prefix: $message',
      statusCode: status,
      error: e,
    );
  }
}
