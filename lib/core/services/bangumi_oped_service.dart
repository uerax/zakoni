import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 单集片头片尾时间戳区间
@immutable
class EpisodeOpedSegment {
  const EpisodeOpedSegment({
    required this.episode,
    this.opStart,
    this.opEnd,
    this.edStart,
    this.edEnd,
  });

  final int episode;
  final int? opStart; // 秒数
  final int? opEnd; // 秒数
  final int? edStart; // 秒数
  final int? edEnd; // 秒数

  bool get hasOp => opStart != null && opEnd != null && opEnd! > opStart!;
  bool get hasEd => edStart != null && edEnd != null && edEnd! > edStart!;

  Duration? get opStartDuration => hasOp ? Duration(seconds: opStart!) : null;
  Duration? get opEndDuration => hasOp ? Duration(seconds: opEnd!) : null;
  Duration? get edStartDuration => hasEd ? Duration(seconds: edStart!) : null;
  Duration? get edEndDuration => hasEd ? Duration(seconds: edEnd!) : null;
}

/// Bangumi OP/ED 片头片尾时间戳服务
/// 数据源同步自 uerax/bangumi-oped (通过 jsDelivr CDN 高速分发)
/// 数据格式：`ep;opStart;opEnd;edStart;edEnd` (-1 表示缺失哨兵值)
class BangumiOpedService {
  BangumiOpedService._();
  static final BangumiOpedService instance = BangumiOpedService._();

  static const String _kBaseUrl =
      'https://cdn.jsdelivr.net/gh/uerax/bangumi-oped@data';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      responseType: ResponseType.plain,
    ),
  );

  final Map<int, Map<int, EpisodeOpedSegment>> _memoryCache = {};

  /// 获取指定 Bangumi 番剧 ID 的全集 OP/ED 时间标记映射 (Key 为集数编号 1, 2, 3...)
  Future<Map<int, EpisodeOpedSegment>> getOpedData(int subjectId) async {
    if (subjectId <= 0) return const {};

    if (_memoryCache.containsKey(subjectId)) {
      return _memoryCache[subjectId]!;
    }

    final url = '$_kBaseUrl/$subjectId/$subjectId.txt';
    try {
      final response = await _dio.get<String>(url);
      if (response.statusCode == 200 && response.data != null) {
        final parsed = parseOpedData(response.data!);
        _memoryCache[subjectId] = parsed;
        return parsed;
      }
    } catch (_) {
      // 404 或无数据时静默回退
    }

    _memoryCache[subjectId] = const {};
    return const {};
  }

  /// 解析远端文本
  Map<int, EpisodeOpedSegment> parseOpedData(String rawText) {
    final result = <int, EpisodeOpedSegment>{};
    final lines = const LineSplitter().convert(rawText);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(';');
      if (parts.length != 5) continue;

      final nums = parts.map((p) => int.tryParse(p) ?? -1).toList();
      final ep = nums[0];
      final opStart = nums[1];
      final opEnd = nums[2];
      final edStart = nums[3];
      final edEnd = nums[4];

      if (ep <= 0) continue;

      // 重复集数按第一条优先
      if (!result.containsKey(ep)) {
        result[ep] = EpisodeOpedSegment(
          episode: ep,
          opStart: opStart >= 0 && opEnd > opStart ? opStart : null,
          opEnd: opStart >= 0 && opEnd > opStart ? opEnd : null,
          edStart: edStart >= 0 && edEnd > edStart ? edStart : null,
          edEnd: edStart >= 0 && edEnd > edStart ? edEnd : null,
        );
      }
    }

    return result;
  }
}
