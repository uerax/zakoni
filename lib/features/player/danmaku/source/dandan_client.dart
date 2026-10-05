import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/danmaku_item.dart';
import '../utils/danmaku_episode_matcher.dart';

/// 弹弹 play 番剧搜索结果模型
class DandanAnime {
  const DandanAnime({
    required this.animeId,
    required this.animeTitle,
    this.bangumiId,
    this.episodeCount,
    this.typeDescription,
    this.imageUrl,
  });

  final int animeId;
  final String animeTitle;
  final String? bangumiId;
  final int? episodeCount;
  final String? typeDescription;
  final String? imageUrl;

  factory DandanAnime.fromJson(Map<String, dynamic> json) {
    return DandanAnime(
      animeId: json['animeId'] as int? ?? 0,
      animeTitle: json['animeTitle']?.toString() ?? '',
      bangumiId: json['bangumiId']?.toString(),
      episodeCount: json['episodeCount'] as int?,
      typeDescription: json['typeDescription']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

/// 弹弹 play 番剧分集模型
class DandanEpisode implements DanmakuEpisodeEntry {
  const DandanEpisode({
    required this.episodeId,
    required this.episodeTitle,
  });

  @override
  final int episodeId;

  @override
  final String episodeTitle;

  factory DandanEpisode.fromJson(Map<String, dynamic> json) {
    return DandanEpisode(
      episodeId: json['episodeId'] as int? ?? 0,
      episodeTitle: json['episodeTitle']?.toString() ?? '',
    );
  }
}

/// 弹弹 play 番剧详情与分集集合
class DandanBangumiDetails {
  const DandanBangumiDetails({
    required this.bangumiId,
    required this.episodes,
  });

  final int bangumiId;
  final List<DandanEpisode> episodes;
}

/// 弹弹 play 原生 Dio 客户端 (1:1 对齐 animaku dandan.ts)
class DandanClient {
  DandanClient({
    Dio? dio,
    String? appId,
    String? appSecret,
  })  : _dio = dio ?? Dio(),
        _appId = (appId != null && appId.trim().isNotEmpty) ? appId.trim() : _defaultId,
        _appSecret = (appSecret != null && appSecret.trim().isNotEmpty)
            ? appSecret.trim()
            : _defaultToken;

  static const String _kBaseUrl = 'https://api.dandanplay.net';

  /// 默认通用公开客户端凭证 (保证开箱即用)
  static final String _defaultId =
      utf8.decode(base64.decode('aHZmNnB6dnhjbQ=='));
  static final String _defaultToken =
      utf8.decode(base64.decode('SVpoY1VJYWtveEZhSzl4QkJEKjlCczFPVTJzNGtLNXQ='));

  final Dio _dio;
  final String _appId;
  final String _appSecret;

  Map<String, String> _buildHeaders() {
    return {
      'User-Agent': 'Zakoni/1.0.0 (Anime Client)',
      'Accept': 'application/json',
      'X-AppId': _appId,
      'X-AppSecret': _appSecret,
    };
  }

  /// 通过 Bangumi.tv 条目 ID 直接查询弹弹关联番剧与分集 (最快、最准)
  Future<DandanBangumiDetails> getBangumiByBgmId(int bgmId) async {
    final url = '$_kBaseUrl/api/v2/bangumi/bgmtv/$bgmId';
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: _buildHeaders(),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = res.data ?? <String, dynamic>{};
      final success = data['success'] as bool? ?? false;
      if (!success) {
        final errorCode = data['errorCode'] as int?;
        final errorMessage = data['errorMessage']?.toString() ?? '';
        // errorCode 7: 无法找到指定的资源（新番未收录正常情况，返回空集数）
        if (errorCode == 7 || errorMessage.contains('无法找到')) {
          return const DandanBangumiDetails(bangumiId: 0, episodes: []);
        }
        throw Exception(errorMessage.isNotEmpty ? errorMessage : '弹弹 BGM 查询失败');
      }

      final bangumiMap = (data['bangumi'] as Map<String, dynamic>?) ?? data;
      final rawEpisodes = bangumiMap['episodes'] as List<dynamic>? ?? const [];
      final episodes = rawEpisodes
          .whereType<Map<String, dynamic>>()
          .map(DandanEpisode.fromJson)
          .toList();

      final animeId = (bangumiMap['animeId'] as int?) ??
          (bangumiMap['bangumiId'] as int?) ??
          0;

      return DandanBangumiDetails(bangumiId: animeId, episodes: episodes);
    } catch (e) {
      developer.log('[DandanClient] getBangumiByBgmId failed: $e');
      rethrow;
    }
  }

  /// 关键字搜索番剧 (用于 BGM ID 未收录时的降级或手动搜索)
  Future<List<DandanAnime>> searchAnime(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const [];

    final url = '$_kBaseUrl/api/v2/search/anime';
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {'keyword': kw},
        options: Options(
          headers: _buildHeaders(),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = res.data ?? <String, dynamic>{};
      final success = data['success'] as bool? ?? false;
      if (!success) {
        final errorMessage = data['errorMessage']?.toString() ?? '弹弹搜索失败';
        throw Exception(errorMessage);
      }

      final rawAnimes = data['animes'] as List<dynamic>? ?? const [];
      return rawAnimes
          .whereType<Map<String, dynamic>>()
          .map(DandanAnime.fromJson)
          .toList();
    } catch (e) {
      developer.log('[DandanClient] searchAnime failed: $e');
      rethrow;
    }
  }

  /// 获取指定番剧详情与全部剧集
  Future<DandanBangumiDetails> getBangumiDetails(int animeId) async {
    final url = '$_kBaseUrl/api/v2/bangumi/$animeId';
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: _buildHeaders(),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = res.data ?? <String, dynamic>{};
      final success = data['success'] as bool? ?? false;
      if (!success) {
        final errorCode = data['errorCode'] as int?;
        final errorMessage = data['errorMessage']?.toString() ?? '';
        if (errorCode == 7 || errorMessage.contains('无法找到')) {
          return DandanBangumiDetails(bangumiId: animeId, episodes: const []);
        }
        throw Exception(errorMessage.isNotEmpty ? errorMessage : '弹弹番剧详情查询失败');
      }

      final bangumiMap = (data['bangumi'] as Map<String, dynamic>?) ?? data;
      final rawEpisodes = bangumiMap['episodes'] as List<dynamic>? ?? const [];
      final episodes = rawEpisodes
          .whereType<Map<String, dynamic>>()
          .map(DandanEpisode.fromJson)
          .toList();

      return DandanBangumiDetails(bangumiId: animeId, episodes: episodes);
    } catch (e) {
      developer.log('[DandanClient] getBangumiDetails failed: $e');
      rethrow;
    }
  }

  /// 拉取指定分集的弹幕评论列表
  Future<List<DanmakuItem>> getComments(
    int episodeId, {
    bool withRelated = true,
    int chConvert = 1,
  }) async {
    final url = '$_kBaseUrl/api/v2/comment/$episodeId';
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {
          'withRelated': withRelated.toString(),
          'chConvert': chConvert.toString(),
        },
        options: Options(
          headers: _buildHeaders(),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = res.data ?? <String, dynamic>{};
      final rawComments = data['comments'] as List<dynamic>? ?? const [];
      return _parseDandanComments(rawComments);
    } catch (e) {
      developer.log('[DandanClient] getComments failed: $e');
      rethrow;
    }
  }

  /// 解析弹弹原始 comments (m: text, p: "time,type,color,senderHash")
  List<DanmakuItem> _parseDandanComments(List<dynamic> comments) {
    final out = <DanmakuItem>[];

    for (final item in comments) {
      if (item is! Map<String, dynamic>) continue;
      final m = item['m']?.toString() ?? '';
      final p = item['p']?.toString() ?? '';
      if (m.trim().isEmpty || p.isEmpty) continue;

      final parts = p.split(',');
      if (parts.isEmpty) continue;

      final timeSec = double.tryParse(parts[0]);
      if (timeSec == null || !timeSec.isFinite || timeSec < 0) continue;
      final timeMs = (timeSec * 1000).round();

      final typeStr = parts.length > 1 ? parts[1].trim() : '1';
      final colorStr = parts.length > 2 ? parts[2].trim() : '';
      final senderHash = parts.length > 3 ? parts[3].trim() : null;

      final mode = switch (typeStr) {
        '4' => DanmakuMode.bottom,
        '5' => DanmakuMode.top,
        _ => DanmakuMode.scroll,
      };

      final color = _parseColorInt(colorStr);

      out.add(DanmakuItem(
        text: m,
        timeMs: timeMs,
        mode: mode,
        color: color,
        source: 'dandan',
        senderHash: (senderHash != null && senderHash.isNotEmpty) ? senderHash : null,
      ));
    }

    out.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return out;
  }

  Color _parseColorInt(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.white;
    final n = int.tryParse(colorStr);
    if (n == null) return Colors.white;
    // 0xFF000000 | (n & 0xFFFFFF)
    return Color(0xFF000000 | (n & 0x00FFFFFF));
  }
}
