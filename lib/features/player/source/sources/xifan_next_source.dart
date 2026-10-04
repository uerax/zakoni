import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/source_models.dart';
import 'video_source.dart';

const String _kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

/// 稀饭Next (next.xifanacg.com) 专有视频源
/// 1:1 对齐 animaku (apps/server/src/lib/xifan-next.ts) 架构与全套容错分支
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
  String get version => '1.3.0';

  @override
  String get description => '1080P · 官方推荐综合主线 (国内原画/HLS多线路)';

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

  /// 凭证自愈：当遭遇 401/403 时，动态抓取 next.xifanacg.com JS Chunks 提取最新密钥与 baseUrl (对齐 animaku)
  Future<({String baseUrl, String key})> _refreshSupabaseCredentials() async {
    if (_refreshingFuture != null) return _refreshingFuture!;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _credentialsLastRefreshedAt < 60000) {
      return (baseUrl: _cachedBaseUrl, key: _cachedKey);
    }
    _credentialsLastRefreshedAt = now;

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
              break;
            }

            final keyMatch = RegExp(r'sb_publishable_[A-Za-z0-9_-]+').firstMatch(chunkText);
            final urlMatch = RegExp(r'https://(?:[a-z0-9-]+\.supabase\.co|api\.xifanacg\.com)').firstMatch(chunkText);
            if (keyMatch != null) {
              if (urlMatch != null && _isAllowedSupabaseBaseUrl(urlMatch.group(0)!)) {
                _cachedBaseUrl = urlMatch.group(0)!;
              }
              _cachedKey = keyMatch.group(0)!;
              break;
            }
          } catch (_) {}
        }
      } catch (_) {}
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

      return res.data;
    } catch (e) {
      throw Exception('稀饭Next网络异常: $e');
    }
  }

  @override
  Future<List<SourceSearchResult>> search(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return [];

    // 1. Primary: RPC suggest_animes
    try {
      final res = await _fetchSupabase(
        '/rest/v1/rpc/suggest_animes',
        method: 'POST',
        body: {'q': q, 'lim': 12},
      );
      if (res is List && res.isNotEmpty) {
        return res
            .whereType<Map<String, dynamic>>()
            .map((item) => SourceSearchResult(
                  name: item['title']?.toString().trim() ??
                      item['title_original']?.toString().trim() ??
                      '番剧 #${item['id']}',
                  url: 'https://next.xifanacg.com/anime/${item['id']}',
                  cover: item['cover_url']?.toString(),
                ))
            .toList();
      }
    } catch (_) {}

    // 2. Fallback: animes table ilike
    try {
      final encoded = Uri.encodeComponent('*$q*');
      final res = await _fetchSupabase(
        '/rest/v1/animes?or=(title.ilike.$encoded,search_title.ilike.$encoded,title_original.ilike.$encoded)&select=id,title,title_original,cover_url&limit=10',
      );
      if (res is List && res.isNotEmpty) {
        return res
            .whereType<Map<String, dynamic>>()
            .map((item) => SourceSearchResult(
                  name: item['title']?.toString().trim() ??
                      item['title_original']?.toString().trim() ??
                      '番剧 #${item['id']}',
                  url: 'https://next.xifanacg.com/anime/${item['id']}',
                  cover: item['cover_url']?.toString(),
                ))
            .toList();
      }
    } catch (_) {}

    return [];
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

  /// 从 Next.js SSR HTML 中解析多线路多源列表 (对齐 animaku extractSourcesFromHtml 规范)
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
          } catch (_) {}
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

    // 1. Primary: 抓取详情页 HTML 解析 RSC 块多线路 (带 source code 绑定)
    try {
      final res = await _dio.get<String>(
        'https://next.xifanacg.com/anime/$animeId',
        options: Options(
          headers: {'User-Agent': _kDefaultUserAgent},
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final sources = _extractSourcesFromHtml(res.data ?? '');
      if (sources != null && sources.isNotEmpty) {
        final roads = <SourceChapterRoad>[];
        for (var sIdx = 0; sIdx < sources.length; sIdx++) {
          final s = sources[sIdx];
          final rawEps = (s['episodes'] as List?) ?? [];
          if (rawEps.isEmpty) continue;

          final code = (s['code']?.toString() ?? '').trim();
          final name = (s['name']?.toString() ?? (code.isNotEmpty ? code : '线路${sIdx + 1}')).trim();

          final episodes = rawEps.map((e) {
            final epNum = e['episode_number'] ?? 1;
            final epTitle = e['title']?.toString().trim();
            final epId = e['id'];
            return SourceEpisode(
              name: (epTitle != null && epTitle.isNotEmpty) ? epTitle : '第$epNum集',
              url: 'https://next.xifanacg.com/anime/$animeId/play/$epId?source=${Uri.encodeComponent(code)}',
            );
          }).toList();

          roads.add(SourceChapterRoad(name: name, episodes: episodes));
        }

        if (roads.isNotEmpty) return roads;
      }
    } catch (_) {}

    // 2. Fallback: Supabase REST 表查询 (过滤 available_at 排除未播日程)
    try {
      final res = await _fetchSupabase(
        '/rest/v1/episodes?anime_id=eq.$animeId&available_at=not.is.null&select=id,title,episode_number,kind&order=episode_number.asc',
      );
      if (res is List && res.isNotEmpty) {
        final mainEps = <SourceEpisode>[];
        final spEps = <SourceEpisode>[];

        for (final item in res.whereType<Map<String, dynamic>>()) {
          final epId = item['id'];
          final epNum = item['episode_number'] ?? 1;
          final title = item['title']?.toString().trim();
          final kind = item['kind']?.toString();
          final displayName = (title != null && title.isNotEmpty) ? title : '第$epNum集';
          final epUrl = 'https://next.xifanacg.com/anime/$animeId/play/$epId';

          if (kind == null || kind == 'main') {
            mainEps.add(SourceEpisode(name: displayName, url: epUrl));
          } else {
            spEps.add(SourceEpisode(name: displayName, url: epUrl));
          }
        }

        final roads = <SourceChapterRoad>[];
        if (mainEps.isNotEmpty) {
          roads.add(SourceChapterRoad(name: '稀饭新番主线', episodes: mainEps));
        }
        if (spEps.isNotEmpty) {
          roads.add(SourceChapterRoad(name: 'SP / 特典', episodes: spEps));
        }
        if (roads.isNotEmpty) return roads;
      }
    } catch (_) {}

    return [];
  }

  /// 提取最高分辨率 HLS 变体 (对齐 animaku extractHighestResolutionHls 规范)
  Future<String> _extractHighestResolutionHls(String masterUrl) async {
    try {
      final res = await _dio.get<String>(
        masterUrl,
        options: Options(
          headers: {'User-Agent': _kDefaultUserAgent},
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final m3u8Text = res.data ?? '';
      if (!m3u8Text.contains('#EXT-X-STREAM-INF')) return masterUrl;

      final lines = m3u8Text.split('\n');
      var highestUrl = '';
      var maxScore = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.startsWith('#EXT-X-STREAM-INF')) {
          var score = 0;
          final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false).firstMatch(line);
          if (resMatch != null) {
            score = int.parse(resMatch.group(1)!) * int.parse(resMatch.group(2)!);
          } else {
            final bwMatch = RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false).firstMatch(line);
            if (bwMatch != null) {
              score = int.parse(bwMatch.group(1)!);
            }
          }
          final nextUrl = (i + 1 < lines.length) ? lines[i + 1].trim() : '';
          if (score > maxScore && nextUrl.isNotEmpty && !nextUrl.startsWith('#')) {
            maxScore = score;
            highestUrl = nextUrl.startsWith('http')
                ? nextUrl
                : Uri.parse(masterUrl).resolve(nextUrl).toString();
          }
        }
      }

      return highestUrl.isNotEmpty ? highestUrl : masterUrl;
    } catch (_) {
      return masterUrl;
    }
  }

  @override
  Future<SourceResolveResult> resolve(String episodeUrl) async {
    final trimmed = episodeUrl.trim();
    final playMatch = RegExp(r'/play/(\d+)').firstMatch(trimmed);
    final episodeId = playMatch != null ? int.tryParse(playMatch.group(1)!) : null;

    if (episodeId == null) {
      throw Exception('无法从播放链接提取稀饭分集 ID: $episodeUrl');
    }

    String sourceCode = '';
    try {
      sourceCode = Uri.parse(trimmed).queryParameters['source'] ?? '';
    } catch (_) {}

    final fbBody = <String, dynamic>{
      'action': 'fallback',
      'episode_id': episodeId,
    };
    if (sourceCode.isNotEmpty) {
      fbBody['source'] = sourceCode;
    }

    // 并发向 Supabase Edge Functions 派发 fallback 与 hls 请求 (对齐 animaku)
    final fbFuture = _fetchSupabase(
      '/functions/v1/issue-web-playback',
      method: 'POST',
      body: fbBody,
      timeout: const Duration(seconds: 6),
    );

    final hlsFuture = _fetchSupabase(
      '/functions/v1/issue-web-playback',
      method: 'POST',
      body: {'action': 'hls', 'episode_id': episodeId},
      timeout: const Duration(seconds: 6),
    );

    String playUrl = '';

    // 2.5s 优先竞速窗口
    try {
      final fbEarly = await fbFuture.timeout(const Duration(milliseconds: 2500));
      if (fbEarly is Map && fbEarly['ok'] == true) {
        playUrl = _pickCandidateUrl(fbEarly, sourceCode);
      }
    } catch (_) {}

    if (playUrl.isEmpty) {
      try {
        final hlsRes = await hlsFuture;
        if (hlsRes is Map && hlsRes['ok'] == true && hlsRes['url'] != null) {
          playUrl = await _extractHighestResolutionHls(hlsRes['url'].toString());
        }
      } catch (_) {}
    }

    if (playUrl.isEmpty) {
      try {
        final fbLate = await fbFuture;
        if (fbLate is Map && fbLate['ok'] == true) {
          playUrl = _pickCandidateUrl(fbLate, sourceCode);
        }
      } catch (_) {}
    }

    if (playUrl.isEmpty) {
      throw Exception('稀饭Next未能生成有效播放直链');
    }

    final isWoPan = playUrl.contains('pan.wo.cn') ||
        playUrl.contains('moedot.net') ||
        playUrl.contains('apn.moedot.net');
    final referer = isWoPan ? 'https://pan.wo.cn/' : 'https://next.xifanacg.com/';

    return SourceResolveResult(
      url: playUrl,
      headers: {
        'User-Agent': _kDefaultUserAgent,
        'Referer': referer,
      },
      format: playUrl.contains('.m3u8') ? 'hls' : 'mp4',
    );
  }

  /// 依据 sourceCode 精准提取候选 CDN 地址 (对齐 animaku selectUrlFromPlaybackResponse 规范)
  String _pickCandidateUrl(Map<dynamic, dynamic> res, String sourceCode) {
    final candidates = (res['candidates'] as List?)?.whereType<Map<dynamic, dynamic>>().toList() ?? [];
    if (sourceCode.isNotEmpty && candidates.isNotEmpty) {
      final target = sourceCode.toLowerCase().trim();
      final matched = candidates.firstWhere(
        (c) => (c['source_code']?.toString().toLowerCase().trim() ?? '') == target,
        orElse: () => const {},
      );
      if (matched.isNotEmpty && matched['url'] != null) {
        return matched['url'].toString();
      }
    }

    // 避开挂掉的 :8088 端口：如果根节点是 :8088，且 candidates 中有可用 CDN，选用可用 CDN
    final rootUrl = res['url']?.toString() ?? '';
    if (rootUrl.contains(':8088') && candidates.isNotEmpty) {
      final alive = candidates.firstWhere(
        (c) => c['url'] != null && !c['url'].toString().contains(':8088'),
        orElse: () => const {},
      );
      if (alive.isNotEmpty && alive['url'] != null) {
        return alive['url'].toString();
      }
    }

    return rootUrl;
  }
}
