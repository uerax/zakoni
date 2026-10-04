import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/source_models.dart';
import 'video_source.dart';

const String _kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

/// Animoe 动漫 (animoe.org) 专有视频源
/// 1:1 对齐 animaku (apps/server/src/lib/animoe.ts) 规范
class AnimoeSource extends VideoSource {
  AnimoeSource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const String _baseUrl = 'https://animoe.org';

  @override
  String get id => 'animoe';

  @override
  String get name => 'Animoe';

  @override
  String get version => '1.3.0';

  @override
  String get description => 'HLS · 网易云音乐 CDN 节点 (多线路字幕组)';

  Map<String, String> _headers([String? referer]) {
    final h = <String, String>{
      'User-Agent': _kDefaultUserAgent,
      'Accept': 'application/json, text/html, */*',
    };
    if (referer != null) h['Referer'] = referer;
    return h;
  }

  @override
  Future<List<SourceSearchResult>> search(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return [];

    try {
      final res = await _dio.get<dynamic>(
        '$_baseUrl/index.php/ajax/suggest?mid=1&wd=${Uri.encodeComponent(q)}',
        options: Options(
          headers: _headers('$_baseUrl/'),
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final data = parseJsonMap(res.data);
      final list = (data?['list'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => SourceSearchResult(
                name: item['name']?.toString().trim() ?? '',
                url: '$_baseUrl/info/${item['id']}.html',
                cover: item['pic']?.toString(),
              ))
          .where((s) => s.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<SourceChapterRoad>> chapters(String animeUrl) async {
    final res = await _dio.get<String>(
      animeUrl,
      options: Options(
        headers: _headers('$_baseUrl/'),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    final html = res.data ?? '';

    // 1. 提取 Tab 标签
    final tabLabels = <String>[];
    final tabRegex = RegExp(r'''<a[^>]*class=["'][^"']*module-tab-item[^"']*["'][^>]*>(.*?)</a>''', caseSensitive: false);
    for (final m in tabRegex.allMatches(html)) {
      final label = m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (label.isNotEmpty && !RegExp(r'^(?:排序|正序|倒序)$').hasMatch(label)) {
        tabLabels.add(label);
      }
    }

    // 2. 提取分集列表
    final roads = <SourceChapterRoad>[];
    final boxRegex = RegExp(r'''<div[^>]*class=["'][^"']*module-play-list[^"']*["'][^>]*>([\s\S]*?)</div>''', caseSensitive: false);
    final boxMatches = boxRegex.allMatches(html);
    var roadIdx = 0;

    for (final bm in boxMatches) {
      final boxHtml = bm.group(1)!;
      final epRegex = RegExp(r'''<a[^>]*href=["'](/play/[^"']+)["'][^>]*>(.*?)</a>''', caseSensitive: false);
      final episodes = <SourceEpisode>[];

      for (final em in epRegex.allMatches(boxHtml)) {
        final href = em.group(1)!;
        final rawName = em.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        final name = RegExp(r'^\d+$').hasMatch(rawName) ? '第${rawName.padLeft(2, '0')}集' : rawName;
        episodes.add(SourceEpisode(
          name: name,
          url: '$_baseUrl$href',
        ));
      }

      if (episodes.isNotEmpty) {
        final roadName = roadIdx < tabLabels.length ? tabLabels[roadIdx] : '线路 ${roadIdx + 1}';
        roads.add(SourceChapterRoad(name: roadName, episodes: episodes));
        roadIdx++;
      }
    }

    return roads;
  }

  @override
  Future<SourceResolveResult> resolve(String episodeUrl) async {
    final res = await _dio.get<String>(
      episodeUrl,
      options: Options(
        headers: _headers('$_baseUrl/'),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    final html = res.data ?? '';
    final match = RegExp(r'var\s+player_aaaa\s*=\s*(\{[\s\S]*?\})\s*<').firstMatch(html) ??
        RegExp(r'player_aaaa\s*=\s*(\{[\s\S]*?\})').firstMatch(html);

    if (match == null) {
      throw Exception('未在 Animoe 播放页提取到 player_aaaa 配置');
    }

    final player = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    var directUrl = (player['url']?.toString() ?? '').trim();

    if (directUrl.contains('*')) {
      directUrl = directUrl.split('*')[0].trim();
    }

    if (!directUrl.startsWith('http')) {
      throw Exception('Animoe 媒体地址无效: $directUrl');
    }

    return SourceResolveResult(
      url: directUrl,
      headers: {
        'Referer': '$_baseUrl/',
        'User-Agent': _kDefaultUserAgent,
      },
      format: 'hls',
    );
  }
}
