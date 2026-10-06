import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'app_preferences.dart';

/// 全局已观看集数响应式单一数据源服务（对齐 animaku apps/web/src/stores/watched.ts）：
/// 1. 响应式单一可信源：继承 ChangeNotifier，任何对已看状态的增删改均自动广播至选集列表与番剧卡片；
/// 2. 数据结构：`Map<int, Map<int, int>>`，即 `bangumiId -> { canonicalEp: watchedTimestamp }`；
/// 3. 特殊处理说明：
///    标记与查询必须严格采用官方正片集数 (canonicalEp) 作为主键，禁止使用源线路内私有索引 (sourceIndex)。
///    第三方视频源常包含 PV/SP/特典或分集错位，使用官方集数可在用户切换视频源或线路时保持已看状态无缝一致；
/// 4. 本地持久化：通过 AppPreferences 异步序列化落盘，冷启动自动恢复。
class WatchedEpisodesService extends ChangeNotifier {
  static final WatchedEpisodesService instance = WatchedEpisodesService._();
  WatchedEpisodesService._();

  /// 内存中各番剧的已看集数映射：bangumiId -> (episodeNumber -> timestamp)
  Map<int, Map<int, int>> _records = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// 初始化服务并从本地偏好加载已看记录
  Future<void> initialize() async {
    if (_isInitialized) return;

    final rawJson = AppPreferences.getWatchedEpisodesJson();
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final loaded = <int, Map<int, int>>{};
          decoded.forEach((bgmKey, epMapRaw) {
            final bgmId = int.tryParse(bgmKey);
            if (bgmId != null && epMapRaw is Map<String, dynamic>) {
              final epMap = <int, int>{};
              epMapRaw.forEach((epKey, tsRaw) {
                final ep = int.tryParse(epKey);
                final ts = (tsRaw as num?)?.toInt();
                if (ep != null && ts != null) {
                  epMap[ep] = ts;
                }
              });
              if (epMap.isNotEmpty) {
                loaded[bgmId] = epMap;
              }
            }
          });
          _records = loaded;
        }
      } catch (e) {
        debugPrint('[WatchedEpisodesService] 解析已看记录失败: $e');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// 异步落盘持久化
  Future<void> _persist() async {
    try {
      final jsonMap = <String, dynamic>{};
      _records.forEach((bgmId, epMap) {
        final innerMap = <String, dynamic>{};
        epMap.forEach((ep, ts) {
          innerMap[ep.toString()] = ts;
        });
        jsonMap[bgmId.toString()] = innerMap;
      });
      await AppPreferences.saveWatchedEpisodesJson(jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('[WatchedEpisodesService] 持久化已看记录失败: $e');
    }
  }

  /// 标记指定番剧的某集为已看
  void markWatched(int bangumiId, int episode, {int? timestamp}) {
    if (bangumiId <= 0 || episode <= 0) return;

    final bgmMap = _records[bangumiId] ?? <int, int>{};
    if (bgmMap.containsKey(episode)) {
      return; // 幂等保护：已标记无需重复触发
    }

    final updatedBgmMap = Map<int, int>.from(bgmMap);
    updatedBgmMap[episode] = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    _records = Map<int, Map<int, int>>.from(_records)..[bangumiId] = updatedBgmMap;

    notifyListeners();
    _persist().ignore();
  }

  /// 取消指定番剧某集的已看标记
  void unmarkWatched(int bangumiId, int episode) {
    if (bangumiId <= 0 || episode <= 0) return;

    final bgmMap = _records[bangumiId];
    if (bgmMap == null || !bgmMap.containsKey(episode)) return;

    final updatedBgmMap = Map<int, int>.from(bgmMap)..remove(episode);
    final updatedRecords = Map<int, Map<int, int>>.from(_records);

    if (updatedBgmMap.isEmpty) {
      updatedRecords.remove(bangumiId);
    } else {
      updatedRecords[bangumiId] = updatedBgmMap;
    }

    _records = updatedRecords;
    notifyListeners();
    _persist().ignore();
  }

  /// 手动切换某集已看状态
  void toggleWatched(int bangumiId, int episode) {
    if (isWatched(bangumiId, episode)) {
      unmarkWatched(bangumiId, episode);
    } else {
      markWatched(bangumiId, episode);
    }
  }

  /// 查询指定番剧某集是否已看
  bool isWatched(int bangumiId, int episode) {
    if (bangumiId <= 0 || episode <= 0) return false;
    final bgmMap = _records[bangumiId];
    return bgmMap != null && bgmMap.containsKey(episode);
  }

  /// 获取指定番剧的全部已看集数集合（O(1) 包含检索，供 UI 选集组件高效消费）
  Set<int> getWatchedEpisodes(int bangumiId) {
    if (bangumiId <= 0) return const {};
    final bgmMap = _records[bangumiId];
    if (bgmMap == null || bgmMap.isEmpty) return const {};
    return bgmMap.keys.toSet();
  }

  /// 清空某部番剧的已看记录
  void clearBangumi(int bangumiId) {
    if (bangumiId <= 0 || !_records.containsKey(bangumiId)) return;

    _records = Map<int, Map<int, int>>.from(_records)..remove(bangumiId);
    notifyListeners();
    _persist().ignore();
  }

  /// 清空全部已看记录
  void clearAll() {
    if (_records.isEmpty) return;

    _records = {};
    notifyListeners();
    AppPreferences.clearWatchedEpisodes().ignore();
  }

  @visibleForTesting
  void resetForTest() {
    _records = {};
    _isInitialized = false;
  }
}
