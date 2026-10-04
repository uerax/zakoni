import 'package:dio/dio.dart';
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

/// 100% 纯原生 Dart 视频源运行时
/// 涵盖 animaku 全部 11 个核心视频源，零 FFI 跨语言开销，毫秒级直接响应
class NativeSourceRuntime {
  NativeSourceRuntime({Dio? dio}) : _dio = dio ?? Dio() {
    _registerDefaultSources();
  }

  final Dio _dio;
  final Map<String, VideoSource> _sources = {};

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
    // 纯 Dart 原生运行时无需异步加载 JS 沙箱，瞬时可用
  }

  /// 搜索番剧
  Future<List<SourceSearchResult>> search(String sourceId, String keyword) async {
    final s = _sources[sourceId];
    if (s == null) {
      throw Exception('未找到视频源: $sourceId');
    }
    return s.search(keyword);
  }

  /// 获取选集线路
  Future<List<SourceChapterRoad>> chapters(String sourceId, String animeUrl) async {
    final s = _sources[sourceId];
    if (s == null) {
      throw Exception('未找到视频源: $sourceId');
    }
    return s.chapters(animeUrl);
  }

  /// 解析播放直链
  Future<SourceResolveResult> resolve(String sourceId, String episodeUrl) async {
    final s = _sources[sourceId];
    if (s == null) {
      throw Exception('未找到视频源: $sourceId');
    }
    return s.resolve(episodeUrl);
  }

  void dispose() {
    // 无底层 C 资源
  }
}
