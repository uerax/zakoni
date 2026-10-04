import 'dart:convert';
import '../models/history/watch_history_item.dart';
import 'app_preferences.dart';

/// 播放历史与继续观看本地持久化服务（对齐 animaku apps/web/src/stores/history.ts）：
/// 1. 负责记录用户观看番剧的最新进度、所属集数、视频源插件 (pluginName) 与线路 (road)；
/// 2. 幂等与去重策略：同一番剧同一集数仅保留最新一条记录，新记录置顶，最多持久化 200 条；
/// 3. 测试与冷启动保护：在未开发视频播放器或本地历史为空时，主动注入 3 条具备真实视频源与 Bangumi 封面的种子数据供测试。
class WatchHistoryService {
  WatchHistoryService._();

  static const int maxItems = 200;

  /// 预置的 3 部真实测试数据（包含视频源、线路与时长进度）
  static List<WatchHistoryItem> get initialMockSeeds {
    final now = DateTime.now();
    return [
      WatchHistoryItem(
        id: WatchHistoryItem.buildId(400650, 14),
        bangumiId: 400650,
        title: '葬送的芙莉莲',
        cover: 'https://lain.bgm.tv/pic/cover/l/d8/d5/400650_6Zz66.jpg',
        episode: 14,
        road: 1,
        pluginName: 'cycani',
        pageUrl: 'https://cycani.org/watch/400650/14',
        position: 1035.0, // 17:15
        duration: 1440.0, // 24:00
        updatedAt: now.subtract(const Duration(minutes: 25)).millisecondsSinceEpoch,
      ),
      WatchHistoryItem(
        id: WatchHistoryItem.buildId(395377, 8),
        bangumiId: 395377,
        title: '迷宫饭',
        cover: 'https://lain.bgm.tv/pic/cover/l/7f/29/395377_1m11O.jpg',
        episode: 8,
        road: 0,
        pluginName: 'anime1',
        pageUrl: 'https://anime1.me/watch/395377/8',
        position: 650.0, // 10:50
        duration: 1440.0, // 24:00
        updatedAt: now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
      ),
      WatchHistoryItem(
        id: WatchHistoryItem.buildId(410657, 4),
        bangumiId: 410657,
        title: '间谍过家家 第二季',
        cover: 'https://lain.bgm.tv/pic/cover/l/71/61/410657_vG6m4.jpg',
        episode: 4,
        road: 1,
        pluginName: 'omofun',
        pageUrl: 'https://omofun.tv/watch/410657/4',
        position: 1265.0, // 21:05
        duration: 1440.0, // 24:00
        updatedAt: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      ),
    ];
  }

  /// 获取播放历史列表（若本地缓存为空，自动落盘并返回 3 条测试数据）
  static Future<List<WatchHistoryItem>> getHistory() async {
    final rawJson = AppPreferences.getWatchHistoryJson();
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          final items = decoded
              .whereType<Map<String, dynamic>>()
              .map((j) => WatchHistoryItem.fromJson(j))
              .toList();
          if (items.isNotEmpty) {
            return items;
          }
        }
      } catch (_) {}
    }

    // 本地缓存为空时，注入种子数据并异步落盘
    final seeds = initialMockSeeds;
    await saveHistory(seeds);
    return seeds;
  }

  /// 全量保存历史记录
  static Future<void> saveHistory(List<WatchHistoryItem> items) async {
    final jsonList = items.take(maxItems).map((e) => e.toJson()).toList();
    await AppPreferences.saveWatchHistoryJson(jsonEncode(jsonList));
  }

  /// 更新或插入单条播放进度（最新在前，同番剧聚合替换为最新进度，每部动漫占一行）
  static Future<void> recordProgress(WatchHistoryItem entry) async {
    final currentList = await getHistory();
    final updatedList = <WatchHistoryItem>[entry];

    // 核心策略：同一番剧只保留最新一条记录（按 bangumiId 聚合更新），杜绝移动端列表刷屏
    for (final item in currentList) {
      if (item.bangumiId != entry.bangumiId) {
        updatedList.add(item);
      }
    }

    await saveHistory(updatedList);
  }

  /// 移除指定 ID 的记录
  static Future<void> remove(String id) async {
    final currentList = await getHistory();
    final filtered = currentList.where((item) => item.id != id).toList();
    await saveHistory(filtered);
  }

  /// 批量删除记录
  static Future<void> removeMany(Set<String> ids) async {
    final currentList = await getHistory();
    final filtered = currentList.where((item) => !ids.contains(item.id)).toList();
    await saveHistory(filtered);
  }

  /// 清空播放历史
  static Future<void> clear() async {
    await AppPreferences.clearWatchHistory();
  }
}
