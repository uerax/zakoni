import 'dart:convert';
import 'package:zakoni/features/player/source/models/source_models.dart';

/// 安全解析任意 Dio 响应（无论服务器以 text/html、text/plain 或 application/json 返回）
Map<String, dynamic>? parseJsonMap(dynamic data) {
  if (data == null) return null;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String && data.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

/// 统一视频源抽象接口 (纯原生 Dart，零 QuickJS 损耗)
abstract class VideoSource {
  String get id;
  String get name;
  String get version;
  String get description;

  Future<List<SourceSearchResult>> search(String keyword);
  Future<List<SourceChapterRoad>> chapters(String animeUrl);
  Future<SourceResolveResult> resolve(String episodeUrl);

  /// 清空视频源私有缓存（默认空实现）
  void clearCache() {}

  SourceMeta toMeta() => SourceMeta(
        id: id,
        name: name,
        version: version,
      );
}
