import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:zakoni/core/network/player_media_disk_cache_manager.dart';
import 'package:zakoni/core/utils/timed_cache.dart';
import 'package:zakoni/features/player/source/models/source_models.dart';
import 'package:zakoni/features/player/source/sources/anime1_source.dart';
import 'package:zakoni/features/player/source/sources/animoe_source.dart';
import 'package:zakoni/features/player/source/sources/cycani_source.dart';
import 'package:zakoni/features/player/source/sources/girigiri_source.dart';
import 'package:zakoni/features/player/source/sources/libvio_source.dart';
import 'package:zakoni/features/player/source/sources/lzizy_source.dart';
import 'package:zakoni/features/player/source/sources/mifun_source.dart';
import 'package:zakoni/features/player/source/sources/moonci_source.dart';
import 'package:zakoni/features/player/source/sources/mxdm_source.dart';
import 'package:zakoni/features/player/source/sources/omofun_source.dart';
import 'package:zakoni/features/player/source/sources/tvtfun_source.dart';
import 'package:zakoni/features/player/source/sources/video_source.dart';
import 'package:zakoni/features/player/source/sources/xifan_next_source.dart';

/// 100% 纯原生 Dart 视频源运行时与统一缓存调度中心
/// 涵盖 animaku 全部 11 个核心视频源，配备 L1 内存 + L2 硬盘持久化双层缓存体系
class NativeSourceRuntime {
  NativeSourceRuntime({Dio? dio}) : _dio = dio ?? Dio() {
    _registerDefaultSources();
  }

  final Dio _dio;
  final Map<String, VideoSource> _sources = {};

  // L1 内存缓存池 (O(1) 毫秒级秒开)
  // 1. 搜索结果: 2 小时
  final TimedKeyedCache<String, List<SourceSearchResult>> _searchMemoryCache =
      TimedKeyedCache(maxAge: const Duration(hours: 2), maxEntries: 200);

  // 2. 选集线路: 30 分钟
  final TimedKeyedCache<String, List<SourceChapterRoad>> _chaptersMemoryCache =
      TimedKeyedCache(maxAge: const Duration(minutes: 30), maxEntries: 200);

  // 3. 直链解析: 20 分钟
  final TimedKeyedCache<String, SourceResolveResult> _resolveMemoryCache =
      TimedKeyedCache(maxAge: const Duration(minutes: 20), maxEntries: 100);

  // 并发去重单飞锁 (杜绝并发探测时的重复网络请求)
  final Map<String, Future<List<SourceSearchResult>>> _inflightSearch = {};
  final Map<String, Future<List<SourceChapterRoad>>> _inflightChapters = {};
  final Map<String, Future<SourceResolveResult>> _inflightResolve = {};

  void _registerDefaultSources() {
    registerSource(XifanNextSource(dio: _dio));
    registerSource(GirigiriSource(dio: _dio));
    registerSource(MifunSource(dio: _dio));
    registerSource(CycaniSource(dio: _dio));
    registerSource(MoonciSource(dio: _dio));
    registerSource(TvTFunSource(dio: _dio));
    registerSource(LzizySource(dio: _dio));
    registerSource(AnimoeSource(dio: _dio));
    registerSource(MxdmSource(dio: _dio));
    registerSource(OmofunSource(dio: _dio));
    registerSource(Anime1Source(dio: _dio));
    registerSource(LibvioSource(dio: _dio));
  }

  void registerSource(VideoSource source) {
    _sources[source.id] = source;
  }

  bool get isInitialized => true;

  SourceBundleMeta get bundleMeta => SourceBundleMeta(
        version: '2.0.0-native',
        buildTime: DateTime.now().toIso8601String(),
        minApiLevel: 1,
        adapters: {for (final s in _sources.values) s.id: s.version},
      );

  List<SourceMeta> get availableSources =>
      _sources.values.map((s) => s.toMeta()).toList();

  VideoSource? getSource(String sourceId) => _sources[sourceId];

  Future<void> initialize({String? bundleCode}) async {
    // 原生运行时瞬时就绪
  }

  /// 搜索番剧 (带 L1 内存 + L2 硬盘双层缓存与请求去重)
  Future<List<SourceSearchResult>> search(
    String sourceId,
    String keyword, {
    bool bypassCache = false,
  }) async {
    final s = _sources[sourceId];
    if (s == null) {
      throw Exception('未找到视频源: $sourceId');
    }

    final kw = keyword.trim();
    if (kw.isEmpty) return const [];

    final cacheKey = '$sourceId:${kw.toLowerCase()}';
    final diskCacheKey = 'src_search_${sourceId}_${kw.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';

    if (!bypassCache) {
      // 1. L1 内存缓存
      final memHit = _searchMemoryCache.get(cacheKey);
      if (memHit != null) return memHit;

      // 2. L2 本地硬盘持久化缓存
      final disk = PlayerMediaDiskCacheManager.instance;
      if (disk != null) {
        try {
          final diskData = await disk.getJson(diskCacheKey);
          if (diskData is List && diskData.isNotEmpty) {
            final list = diskData
                .whereType<Map<String, dynamic>>()
                .map(SourceSearchResult.fromJson)
                .toList();
            if (list.isNotEmpty) {
              _searchMemoryCache.set(cacheKey, list, list.length * 128 + 64);
              return list;
            }
          }
        } catch (_) {}
      }
    }

    // 3. 并发单飞去重
    if (_inflightSearch.containsKey(cacheKey)) {
      return _inflightSearch[cacheKey]!;
    }

    final future = () async {
      try {
        final results = await s.search(kw);
        // 回填 L1 内存缓存 (2 小时)
        final estBytes = results.length * 128 + 64;
        _searchMemoryCache.set(cacheKey, results, estBytes);

        // 回填 L2 本地硬盘 (2 小时)
        if (results.isNotEmpty) {
          final disk = PlayerMediaDiskCacheManager.instance;
          disk?.putJson(
            diskCacheKey,
            results.map((r) => r.toJson()).toList(),
            maxAge: const Duration(hours: 2),
          ).ignore();
        }

        return results;
      } catch (e) {
        developer.log('[NativeRuntime] search error ($sourceId, $kw): $e');
        rethrow;
      }
    }();

    _inflightSearch[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inflightSearch.remove(cacheKey);
    }
  }

  /// 获取选集线路 (带 L1 内存 + L2 硬盘双层缓存与请求去重)
  Future<List<SourceChapterRoad>> chapters(
    String sourceId,
    String animeUrl, {
    bool bypassCache = false,
  }) async {
    final s = _sources[sourceId];
    if (s == null) {
      throw Exception('未找到视频源: $sourceId');
    }

    final cacheKey = '$sourceId:$animeUrl';
    final diskCacheKey = 'src_ch_${sourceId}_${animeUrl.hashCode.abs()}';

    if (!bypassCache) {
      // 1. L1 内存缓存
      final memHit = _chaptersMemoryCache.get(cacheKey);
      if (memHit != null) return memHit;

      // 2. L2 本地硬盘持久化缓存
      final disk = PlayerMediaDiskCacheManager.instance;
      if (disk != null) {
        try {
          final diskData = await disk.getJson(diskCacheKey);
          if (diskData is List && diskData.isNotEmpty) {
            final roads = diskData
                .whereType<Map<String, dynamic>>()
                .map(SourceChapterRoad.fromJson)
                .toList();
            if (roads.isNotEmpty && roads.any((r) => r.episodes.isNotEmpty)) {
              _chaptersMemoryCache.set(cacheKey, roads, roads.length * 512 + 128);
              return roads;
            }
          }
        } catch (_) {}
      }
    }

    // 3. 并发单飞去重
    if (_inflightChapters.containsKey(cacheKey)) {
      return _inflightChapters[cacheKey]!;
    }

    final future = () async {
      try {
        final roads = await s.chapters(animeUrl);
        if (roads.isNotEmpty && roads.any((r) => r.episodes.isNotEmpty)) {
          // 回填 L1 内存 (30 分钟)
          final estBytes = roads.length * 512 + 128;
          _chaptersMemoryCache.set(cacheKey, roads, estBytes);

          // 回填 L2 本地硬盘 (30 分钟)
          final disk = PlayerMediaDiskCacheManager.instance;
          disk?.putJson(
            diskCacheKey,
            roads.map((r) => r.toJson()).toList(),
            maxAge: const Duration(minutes: 30),
          ).ignore();
        }
        return roads;
      } catch (e) {
        developer.log('[NativeRuntime] chapters error ($sourceId, $animeUrl): $e');
        rethrow;
      }
    }();

    _inflightChapters[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inflightChapters.remove(cacheKey);
    }
  }

  /// 解析播放直链 (带 L1 内存 20 分钟缓存与 Single-Flight 请求去重)
  ///
  /// 特殊处理说明：视频直链通常包含临时鉴权令牌、短期 CDN 签名或会话 Cookie，
  /// 跨进程持久化到磁盘极易导致重启后读取过期废链引发 403 播放失败。
  /// 因此直链仅保留 20 分钟 L1 内存缓存与单飞去重，不进行 L2 磁盘持久化。
  Future<SourceResolveResult> resolve(
    String sourceId,
    String episodeUrl, {
    bool bypassCache = false,
  }) async {
    final s = _sources[sourceId];
    if (s == null) {
      throw Exception('未找到视频源: $sourceId');
    }

    final cacheKey = '$sourceId:$episodeUrl';

    if (!bypassCache) {
      // 1. L1 内存缓存
      final memHit = _resolveMemoryCache.get(cacheKey);
      if (memHit != null && memHit.url.isNotEmpty) return memHit;
    }

    // 2. 并发单飞去重
    if (_inflightResolve.containsKey(cacheKey)) {
      return _inflightResolve[cacheKey]!;
    }

    final future = () async {
      try {
        final result = await s.resolve(episodeUrl);
        if (result.url.isNotEmpty) {
          // 回填 L1 内存 (20 分钟)
          _resolveMemoryCache.set(cacheKey, result, 256);
        }
        return result;
      } catch (e) {
        developer.log('[NativeRuntime] resolve error ($sourceId, $episodeUrl): $e');
        rethrow;
      }
    }();

    _inflightResolve[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inflightResolve.remove(cacheKey);
    }
  }

  /// 获取当前所有视频源缓存的内存预估字节数
  int get memoryCacheSizeBytes =>
      _searchMemoryCache.totalBytes +
      _chaptersMemoryCache.totalBytes +
      _resolveMemoryCache.totalBytes;

  /// 清空视频源运行时全部内存缓存
  void clearMemoryCache() {
    _searchMemoryCache.clear();
    _chaptersMemoryCache.clear();
    _resolveMemoryCache.clear();
    for (final s in _sources.values) {
      s.clearCache();
    }
  }

  void dispose() {
    clearMemoryCache();
  }
}
