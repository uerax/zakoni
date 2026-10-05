import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/source_models.dart';
import 'video_source.dart';

const String _kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

/// 稀饭Next (next.xifanacg.com) 专有视频源
/// 严格遵守源站线路定义与返回直链，绝不擅自篡改用户选择的播放线路。
class XifanNextSource extends VideoSource {
  XifanNextSource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const String _defaultSupabaseUrl = 'https://api.xifanacg.com';
  static const String _defaultKey = 'sb_publishable_OBIVAWACIX6lPXrO98_z24_HcsmalkA';

  String _cachedBaseUrl = _defaultSupabaseUrl;
  String _cachedKey = _defaultKey;
  int _credentialsLastRefreshedAt = 0;
  Future<({String baseUrl, String key})>? _refreshingFuture;

  @override
  String get id => 'xifan-next';

  @override
  String get name => '稀饭Next';

  @override
  String get version => '1.5.0';

  @override
  String get description => '1080P · 官方推荐综合主线 (智能双轨与极速直链)';

  // 1. 搜索单飞与短时内存缓存 (30分钟)
  final Map<String, ({int time, List<SourceSearchResult> results})> _searchCache = {};
  final Map<String, Future<List<SourceSearchResult>>> _inflightSearch = {};

  // 2. 章节线路缓存 (1小时)
  final Map<String, ({int time, List<SourceChapterRoad> roads})> _chaptersCache = {};
  final Map<String, Future<List<SourceChapterRoad>>> _inflightChapters = {};

  // 3. 播放直链 LRU 短期缓存 (20分钟)
  final Map<String, ({int time, SourceResolveResult result})> _resolveCache = {};

  void _log(String message) {
    debugPrint('[XifanNext] $message');
  }

  Map<String, String> _buildHeaders([String? customKey]) {
    final key = customKey ?? _cachedKey;
    return {
      'apikey': key,
      'authorization': 'Bearer $key',
      'content-type': 'application/json',
      'x-region': 'ap-southeast-1',
      'User-Agent': _kDefaultUserAgent,
    };
  }

  bool _isAllowedSupabaseBaseUrl(String urlStr) {
    try {
      final u = Uri.parse(urlStr);
      if (u.scheme != 'https') return false;
      final host = u.host.toLowerCase();
      return host == 'api.xifanacg.com' ||
          host.endsWith('.xifanacg.com') ||
          host.endsWith('.supabase.co');
    } catch (_) {
      return false;
    }
  }

  /// 凭证自愈：当遭遇 401/403 时，动态抓取 next.xifanacg.com JS Chunks 提取最新密钥与 baseUrl
  Future<({String baseUrl, String key})> _refreshSupabaseCredentials() async {
    if (_refreshingFuture != null) return _refreshingFuture!;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _credentialsLastRefreshedAt < 60000) {
      return (baseUrl: _cachedBaseUrl, key: _cachedKey);
    }
    _credentialsLastRefreshedAt = now;
    _log('检测到凭证失效，正在从前端资源自愈刷新 Supabase 密钥...');

    _refreshingFuture = () async {
      try {
        final homeRes = await _dio.get<String>(
          'https://next.xifanacg.com',
          options: Options(
            headers: {'User-Agent': _kDefaultUserAgent},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        final html = homeRes.data ?? '';
        final chunkMatches = RegExp(r'''src=["'](/_next/static/chunks/[^"']+\.js)["']''').allMatches(html);
        final chunkPaths = chunkMatches.map((m) => m.group(1)!).toList();

        for (final chunkPath in chunkPaths) {
          try {
            final chunkRes = await _dio.get<String>(
              'https://next.xifanacg.com$chunkPath',
              options: Options(
                headers: {'User-Agent': _kDefaultUserAgent},
                sendTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );
            final chunkText = chunkRes.data ?? '';

            final pairMatch = RegExp(r'"(https://[^"]+)","(sb_publishable_[A-Za-z0-9_-]+)"').firstMatch(chunkText);
            if (pairMatch != null && _isAllowedSupabaseBaseUrl(pairMatch.group(1)!)) {
              _cachedBaseUrl = pairMatch.group(1)!;
              _cachedKey = pairMatch.group(2)!;
              _log('凭证自愈成功: baseUrl=$_cachedBaseUrl');
              break;
            }

            final keyMatch = RegExp(r'sb_publishable_[A-Za-z0-9_-]+').firstMatch(chunkText);
            final urlMatch = RegExp(r'https://(?:[a-z0-9-]+\.supabase\.co|api\.xifanacg\.com)').firstMatch(chunkText);
            if (keyMatch != null) {
              if (urlMatch != null && _isAllowedSupabaseBaseUrl(urlMatch.group(0)!)) {
                _cachedBaseUrl = urlMatch.group(0)!;
              }
              _cachedKey = keyMatch.group(0)!;
              _log('凭证自愈成功: key=$_cachedKey');
              break;
            }
          } catch (e) {
            _log('探测静态资源 $chunkPath 失败: $e');
          }
        }
      } catch (e) {
        _log('拉取首页静态清单异常: $e');
      }
      return (baseUrl: _cachedBaseUrl, key: _cachedKey);
    }();

    try {
      return await _refreshingFuture!;
    } finally {
      _refreshingFuture = null;
    }
  }

  String _buildSupabaseUrl(String baseUrl, String endpoint) {
    var url = '$baseUrl$endpoint';
    if (endpoint.startsWith('/functions/v1/')) {
      final sep = url.contains('?') ? '&' : '?';
      if (!url.contains('forceFunctionRegion=')) {
        url = '$url${sep}forceFunctionRegion=ap-southeast-1';
      }
    }
    return url;
  }

  Future<dynamic> _fetchSupabase(
    String endpoint, {
    String method = 'GET',
    dynamic body,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    var url = _buildSupabaseUrl(_cachedBaseUrl, endpoint);

    try {
      final res = await _dio.request<dynamic>(
        url,
        data: body,
        options: Options(
          method: method,
          headers: _buildHeaders(),
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (_) => true,
        ),
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        _log('请求 $endpoint 遭遇 ${res.statusCode}，尝试刷新密钥重试...');
        final refreshed = await _refreshSupabaseCredentials();
        url = _buildSupabaseUrl(refreshed.baseUrl, endpoint);
        final retryRes = await _dio.request<dynamic>(
          url,
          data: body,
          options: Options(
            method: method,
            headers: _buildHeaders(refreshed.key),
            sendTimeout: timeout,
            receiveTimeout: timeout,
            validateStatus: (_) => true,
          ),
        );
        return retryRes.data;
      }

      if (res.statusCode != null && res.statusCode! >= 400) {
        _log('接口 $endpoint 响应异常 HTTP ${res.statusCode}: ${res.data}');
      }

      return res.data;
    } catch (e) {
      _log('网络请求异常 $endpoint: $e');
      throw Exception('稀饭Next网络异常: $e');
    }
  }

  @override
  Future<List<SourceSearchResult>> search(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return [];

    final cacheKey = q.toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _searchCache[cacheKey];
    if (cached != null && now - cached.time < 30 * 60 * 1000) {
      _log('命中搜索内存缓存: "$q" (${cached.results.length}条)');
      return cached.results;
    }

    if (_inflightSearch.containsKey(cacheKey)) {
      return _inflightSearch[cacheKey]!;
    }

    final future = () async {
      _log('开始搜索: "$q"');

      // 1. Primary: RPC suggest_animes
      try {
        final res = await _fetchSupabase(
          '/rest/v1/rpc/suggest_animes',
          method: 'POST',
          body: {'q': q, 'lim': 12},
        );
        if (res is List && res.isNotEmpty) {
          final list = res
              .whereType<Map<String, dynamic>>()
              .map((item) => SourceSearchResult(
                    name: item['title']?.toString().trim() ??
                        item['title_original']?.toString().trim() ??
                        '番剧 #${item['id']}',
                    url: 'https://next.xifanacg.com/anime/${item['id']}',
                    cover: item['cover_url']?.toString(),
                  ))
              .toList();
          _log('RPC 搜索成功命中 ${list.length} 条');
          _searchCache[cacheKey] = (time: DateTime.now().millisecondsSinceEpoch, results: list);
          return list;
        }
      } catch (e) {
        _log('RPC 搜索异常: $e');
      }

      // 2. Fallback: animes table ilike
      try {
        final encoded = Uri.encodeComponent('*$q*');
        final res = await _fetchSupabase(
          '/rest/v1/animes?or=(title.ilike.$encoded,search_title.ilike.$encoded,title_original.ilike.$encoded)&select=id,title,title_original,cover_url&limit=10',
        );
        if (res is List && res.isNotEmpty) {
          final list = res
              .whereType<Map<String, dynamic>>()
              .map((item) => SourceSearchResult(
                    name: item['title']?.toString().trim() ??
                        item['title_original']?.toString().trim() ??
                        '番剧 #${item['id']}',
                    url: 'https://next.xifanacg.com/anime/${item['id']}',
                    cover: item['cover_url']?.toString(),
                  ))
              .toList();
          _log('REST 表搜索命中 ${list.length} 条');
          _searchCache[cacheKey] = (time: DateTime.now().millisecondsSinceEpoch, results: list);
          return list;
        }
      } catch (e) {
        _log('REST 表搜索异常: $e');
      }

      _log('未搜索到相关番剧');
      return <SourceSearchResult>[];
    }();

    _inflightSearch[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inflightSearch.remove(cacheKey);
    }
  }

  /// 提取 Next.js 15 流式 RSC 块 (self.__next_f.push)
  List<String> _extractNextFPushes(String html) {
    final chunks = <String>[];
    var pos = 0;
    const token = 'self.__next_f.push([';

    while (true) {
      final idx = html.indexOf(token, pos);
      if (idx == -1) break;

      final start = idx + token.length - 1;
      var depth = 0;
      var inStr = false;
      var esc = false;
      var quote = '';
      var end = -1;

      for (var i = start; i < html.length; i++) {
        final ch = html[i];
        if (inStr) {
          if (esc) {
            esc = false;
            continue;
          }
          if (ch == '\\') {
            esc = true;
            continue;
          }
          if (ch == quote) inStr = false;
          continue;
        }
        if (ch == '"' || ch == "'") {
          inStr = true;
          quote = ch;
          continue;
        }
        if (ch == '[') {
          depth++;
        } else if (ch == ']') {
          depth--;
          if (depth == 0) {
            end = i + 1;
            break;
          }
        }
      }

      if (end > 0) {
        try {
          final parsed = jsonDecode(html.substring(start, end));
          if (parsed is List && parsed.length > 1 && parsed[1] is String) {
            chunks.add(parsed[1] as String);
          }
        } catch (_) {}
        pos = end;
      } else {
        pos += token.length;
      }
    }

    return chunks;
  }

  /// 从 Next.js SSR HTML 中解析多线路多源列表
  List<dynamic>? _extractSourcesFromHtml(String html) {
    final chunks = _extractNextFPushes(html);
    for (final chunkStr in chunks) {
      final idx = chunkStr.indexOf('"sources":[');
      if (idx >= 0) {
        var depth = 0;
        var inStr = false;
        var esc = false;
        var quote = '';
        var end = -1;
        final start = idx + 10;

        for (var i = start; i < chunkStr.length; i++) {
          final ch = chunkStr[i];
          if (inStr) {
            if (esc) {
              esc = false;
              continue;
            }
            if (ch == '\\') {
              esc = true;
              continue;
            }
            if (ch == quote) inStr = false;
            continue;
          }
          if (ch == '"' || ch == "'") {
            inStr = true;
            quote = ch;
            continue;
          }
          if (ch == '[') {
            depth++;
          } else if (ch == ']') {
            depth--;
            if (depth == 0) {
              end = i + 1;
              break;
            }
          }
        }

        if (end > 0) {
          try {
            final parsed = jsonDecode(chunkStr.substring(start, end));
            if (parsed is List) return parsed;
          } catch (e) {
            _log('解析 sources JSON 失败: $e');
          }
        }
      }
    }
    return null;
  }

  @override
  Future<List<SourceChapterRoad>> chapters(String animeUrl) async {
    final match = RegExp(r'/anime/(\d+)').firstMatch(animeUrl) ?? RegExp(r'(\d+)$').firstMatch(animeUrl);
    if (match == null) {
      throw Exception('无法解析稀饭番剧 ID: $animeUrl');
    }
    final animeId = match.group(1)!;

    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _chaptersCache[animeId];
    if (cached != null && now - cached.time < 60 * 60 * 1000) {
      _log('命中分集线路内存缓存: animeId=$animeId (${cached.roads.length}条线路)');
      return cached.roads;
    }

    if (_inflightChapters.containsKey(animeId)) {
      return _inflightChapters[animeId]!;
    }

    final future = () async {
      _log('正在获取番剧分集与线路: animeId=$animeId');

      // 极速轨 (Fast-Path): Supabase REST 表查询 (过滤 available_at 排除未播日程，仅 ~1.5KB JSON，500ms 内瞬间直出)
      Future<List<SourceChapterRoad>?> fetchFastRest() async {
        try {
          final res = await _fetchSupabase(
            '/rest/v1/episodes?anime_id=eq.$animeId&available_at=not.is.null&select=id,title,episode_number,kind&order=episode_number.asc',
            timeout: const Duration(seconds: 4),
          );
          if (res is List && res.isNotEmpty) {
            final mainEps = <SourceEpisode>[];
            final spEps = <SourceEpisode>[];

            for (final item in res.whereType<Map<String, dynamic>>()) {
              final epId = item['id'];
              final epNum = item['episode_number'] ?? 1;
              final kind = item['kind']?.toString();
              final epUrl = 'https://next.xifanacg.com/anime/$animeId/play/$epId';

              if (kind == null || kind == 'main') {
                mainEps.add(SourceEpisode(name: '第$epNum集', url: epUrl));
              } else {
                spEps.add(SourceEpisode(name: 'SP $epNum', url: epUrl));
              }
            }

            final roads = <SourceChapterRoad>[];
            if (mainEps.isNotEmpty) {
              // 特殊处理说明：
              // 为杜绝首屏白屏等待，Fast-Path 在 300ms 内依据 REST episodes 表生成稀饭标准三线路（主线1-沃云、主线2-海外、备用1-切片），
              // 严格携带各线路专属 source_id 与 source_code，确保用户秒开即可自由选线，同时后台平滑拉取 SSR 页面多线路元数据。
              roads.add(SourceChapterRoad(
                name: '稀饭新番主线-1',
                episodes: mainEps
                    .map((e) => SourceEpisode(name: e.name, url: '${e.url}?source_id=4&source=xfxf1'))
                    .toList(),
              ));
              roads.add(SourceChapterRoad(
                name: '稀饭新番主线-2',
                episodes: mainEps
                    .map((e) => SourceEpisode(name: e.name, url: '${e.url}?source_id=1&source=AL'))
                    .toList(),
              ));
              roads.add(SourceChapterRoad(
                name: '稀饭备用-1',
                episodes: mainEps
                    .map((e) => SourceEpisode(name: e.name, url: '${e.url}?source_id=2&source=CS'))
                    .toList(),
              ));
            }
            if (spEps.isNotEmpty) {
              roads.add(SourceChapterRoad(name: 'SP / 特典', episodes: spEps));
            }
            return roads.isNotEmpty ? roads : null;
          }
        } catch (e) {
          _log('Fast-Path REST 查询异常: $e');
        }
        return null;
      }

      // 完整轨 (Full-Path): 抓取详情页 HTML 解析 RSC 块多线路 (严格携带 source_id 与 source_code)
      Future<List<SourceChapterRoad>?> fetchFullSsr() async {
        try {
          final res = await _dio.get<String>(
            'https://next.xifanacg.com/anime/$animeId',
            options: Options(
              headers: {'User-Agent': _kDefaultUserAgent},
              sendTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
            ),
          );
          final sources = _extractSourcesFromHtml(res.data ?? '');
          if (sources != null && sources.isNotEmpty) {
            final roads = <SourceChapterRoad>[];
            for (var sIdx = 0; sIdx < sources.length; sIdx++) {
              final s = sources[sIdx];
              final rawEps = (s['episodes'] as List?) ?? [];
              if (rawEps.isEmpty) continue;

              final dynamic rawSourceId = s['id'];
              final int? sourceId = (rawSourceId is int)
                  ? rawSourceId
                  : int.tryParse(rawSourceId?.toString() ?? '');
              final code = (s['code']?.toString() ?? '').trim();
              final name = (s['name']?.toString() ?? (code.isNotEmpty ? code : '线路${sIdx + 1}')).trim();

              final episodes = rawEps.map((e) {
                final epNum = e['episode_number'] ?? 1;
                final epId = e['id'];

                final params = <String>[];
                if (sourceId != null) {
                  params.add('source_id=$sourceId');
                }
                if (code.isNotEmpty) {
                  params.add('source=${Uri.encodeComponent(code)}');
                }
                final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';

                return SourceEpisode(
                  name: '第$epNum集',
                  url: 'https://next.xifanacg.com/anime/$animeId/play/$epId$queryString',
                );
              }).toList();

              roads.add(SourceChapterRoad(name: name, episodes: episodes));
            }
            return roads.isNotEmpty ? roads : null;
          }
        } catch (e) {
          _log('Full-Path SSR 页面抓取与解析异常: $e');
        }
        return null;
      }

      // 竞速编排：并发启动 Fast-Path 与 Full-Path
      final ssrFuture = fetchFullSsr();
      final restFuture = fetchFastRest();

      // 给 Full-Path (SSR) 预留 2 秒优先优胜窗口，若超时或失败则秒级由 Fast-Path 顶上
      final earlySsr = await ssrFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      if (earlySsr != null && earlySsr.isNotEmpty) {
        _log('SSR 完整多线路优先命中: ${earlySsr.map((r) => "${r.name}(${r.episodes.length}集)").join(', ')}');
        _chaptersCache[animeId] = (time: DateTime.now().millisecondsSinceEpoch, roads: earlySsr);
        return earlySsr;
      }

      // 若 SSR 耗时超过 750ms，检查极速 REST 表结果
      final fastRest = await restFuture;
      if (fastRest != null && fastRest.isNotEmpty) {
        _log('极速 Fast-Path 抢先直出 (${fastRest.length}条线路)，分集列表瞬时呈现');
        _chaptersCache[animeId] = (time: DateTime.now().millisecondsSinceEpoch, roads: fastRest);

        // 后台静默等待 SSR 完成后平滑升级多线路缓存
        ssrFuture.then((ssrRoads) {
          if (ssrRoads != null && ssrRoads.isNotEmpty) {
            _log('后台 SSR 线路解析就绪，已平滑升级多线路缓存');
            _chaptersCache[animeId] = (time: DateTime.now().millisecondsSinceEpoch, roads: ssrRoads);
          }
        }).catchError((_) {});

        return fastRest;
      }

      // 若 Fast-Path 异常，最后等待 SSR 兜底
      final lateSsr = await ssrFuture;
      if (lateSsr != null && lateSsr.isNotEmpty) {
        _chaptersCache[animeId] = (time: DateTime.now().millisecondsSinceEpoch, roads: lateSsr);
        return lateSsr;
      }

      _log('未解析到任何有效分集');
      return <SourceChapterRoad>[];
    }();

    _inflightChapters[animeId] = future;
    try {
      return await future;
    } finally {
      _inflightChapters.remove(animeId);
    }
  }

  @override
  Future<SourceResolveResult> resolve(String episodeUrl) async {
    final trimmed = episodeUrl.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _resolveCache[trimmed];
    if (cached != null && now - cached.time < 20 * 60 * 1000) {
      _log('命中播放直链内存缓存: $trimmed -> ${cached.result.url}');
      return cached.result;
    }

    final playMatch = RegExp(r'/play/(\d+)').firstMatch(trimmed);
    final episodeId = playMatch != null ? int.tryParse(playMatch.group(1)!) : null;

    if (episodeId == null) {
      throw Exception('无法从播放链接提取稀饭分集 ID: $episodeUrl');
    }

    int? sourceId;
    String sourceCode = '';
    try {
      final uri = Uri.parse(trimmed);
      sourceId = int.tryParse(uri.queryParameters['source_id'] ?? '');
      sourceCode = uri.queryParameters['source'] ?? '';
    } catch (e) {
      _log('解析播放链接参数失败: $e');
    }

    _log('开始解析播放直链: episodeId=$episodeId, sourceId=$sourceId, sourceCode=$sourceCode');

    // 构造请求体：完全遵循稀饭官网前端规范，使用 action: 'fallback'，传数字 source_id
    final reqBody = <String, dynamic>{
      'action': 'fallback',
      'episode_id': episodeId,
    };
    if (sourceId != null) {
      reqBody['source_id'] = sourceId;
    }

    final dynamic res = await _fetchSupabase(
      '/functions/v1/issue-web-playback',
      method: 'POST',
      body: reqBody,
      timeout: const Duration(seconds: 8),
    );

    if (res is! Map || res['ok'] != true) {
      final err = (res is Map) ? res['error'] : 'unknown_error';
      _log('issue-web-playback 接口报错: $err');
      throw Exception('稀饭Next签发直链失败: $err');
    }

    final candidates = (res['candidates'] as List?)
            ?.whereType<Map<dynamic, dynamic>>()
            .toList() ??
        [];

    _log('issue-web-playback 成功返回，candidates 数量: ${candidates.length}');

    String playUrl = '';

    // 1. 若指定了 sourceId，严格在 candidates 中匹配该 sourceId 的源，绝不搞跨线路篡改
    if (sourceId != null && candidates.isNotEmpty) {
      final matched = candidates.firstWhere(
        (c) {
          final cId = c['source_id'];
          return cId == sourceId || cId?.toString() == sourceId.toString();
        },
        orElse: () => const {},
      );
      if (matched.isNotEmpty && matched['url'] != null) {
        playUrl = matched['url'].toString();
        _log('严格命中用户指定线路 (source_id: $sourceId, 名称: ${matched['source_name']}): $playUrl');
      }
    }

    // 2. 若通过 sourceCode 匹配
    if (playUrl.isEmpty && sourceCode.isNotEmpty && candidates.isNotEmpty) {
      final target = sourceCode.toLowerCase().trim();
      final matched = candidates.firstWhere(
        (c) => (c['source_code']?.toString().toLowerCase().trim() ?? '') == target,
        orElse: () => const {},
      );
      if (matched.isNotEmpty && matched['url'] != null) {
        playUrl = matched['url'].toString();
        _log('严格命中用户指定线路代号 (source_code: $sourceCode, 名称: ${matched['source_name']}): $playUrl');
      }
    }

    // 3. 若指定线路未单独匹配到，但接口给出了候选列表（通常为未传 source_id 的通用链接），严格按源返回提取直链
    if (playUrl.isEmpty && candidates.isNotEmpty) {
      // 默认未指定线路时，按国内主线 > 国内 HLS 备用 > 国外保底 选择
      final primary = candidates.firstWhere(
        (c) => (c['source_code']?.toString().toLowerCase() == 'xfxf1'),
        orElse: () => const {},
      );
      if (primary.isNotEmpty && primary['url'] != null) {
        playUrl = primary['url'].toString();
        _log('未指定线路，默认采用国内主线: $playUrl');
      } else {
        final backup = candidates.firstWhere(
          (c) => (c['source_code']?.toString().toLowerCase() == 'cs'),
          orElse: () => const {},
        );
        if (backup.isNotEmpty && backup['url'] != null) {
          playUrl = backup['url'].toString();
          _log('未指定线路，采用国内备用 HLS: $playUrl');
        } else {
          playUrl = candidates.first['url']?.toString() ?? '';
          _log('未指定线路，采用首个候选源: $playUrl');
        }
      }
    }

    // 4. 兜底直接取 root url
    if (playUrl.isEmpty) {
      playUrl = res['url']?.toString() ?? '';
      _log('从响应根对象提取播放地址: $playUrl');
    }

    if (playUrl.isEmpty) {
      _log('未能在接口返回中找到有效的播放地址: $res');
      throw Exception('稀饭Next未能生成有效播放地址');
    }

    final isWoPan = playUrl.contains('pan.wo.cn') ||
        playUrl.contains('moedot.net') ||
        playUrl.contains('apn.moedot.net');
    final referer = isWoPan ? 'https://pan.wo.cn/' : 'https://next.xifanacg.com/';
    final format = playUrl.contains('.m3u8') ? 'hls' : 'mp4';

    _log('最终返回直链: $playUrl, 格式: $format, Referer: $referer');

    final result = SourceResolveResult(
      url: playUrl,
      headers: {
        'User-Agent': _kDefaultUserAgent,
        'Referer': referer,
      },
      format: format,
    );

    _resolveCache[trimmed] = (time: DateTime.now().millisecondsSinceEpoch, result: result);
    return result;
  }
}
