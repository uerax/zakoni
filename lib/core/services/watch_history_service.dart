import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/history/watch_history_item.dart';
import 'app_preferences.dart';

/// 播放历史与继续观看响应式单一数据源服务（对齐 animaku apps/web/src/stores/history.ts 与 Flutter ChangeNotifier 模式）：
/// 1. 响应式单一可信源：继承 ChangeNotifier，任何对历史的增删改均自动通过 notifyListeners() 广播至全应用所有监听页面；
/// 2. 独立于网络请求：本地播放历史与慢速网络 API 完全解耦，首页与历史页通过 ListenableBuilder 毫秒级动态同步；
/// 3. 单动漫聚合策略：同一番剧最新集数置顶更新，每部动漫在历史中只占一行，彻底杜绝列表刷屏；
/// 4. 容量与持久化管理：上限 200 条，落盘持久化至 AppPreferences；
/// 5. 冷启动种子数据：在本地无历史时自动注入 3 条具备真实视频源与 Bangumi 封面的测试数据。
class WatchHistoryService extends ChangeNotifier {
  static final WatchHistoryService instance = WatchHistoryService._();
  WatchHistoryService._();

  static const int maxItems = 200;

  List<WatchHistoryItem> _items = [];
  bool _isInitialized = false;

  /// 内存中当前的播放历史列表（只读不可变快照）
  List<WatchHistoryItem> get items => List.unmodifiable(_items);

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

  /// 获取播放历史列表（首次调用自动加载持久化缓存，为空时自动注入种子数据）
  Future<List<WatchHistoryItem>> getHistory({bool forceReload = false}) async {
    if (_isInitialized && !forceReload) {
      return _items;
    }

    final rawJson = AppPreferences.getWatchHistoryJson();
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          final loaded = decoded
              .whereType<Map<String, dynamic>>()
              .map((j) => WatchHistoryItem.fromJson(j))
              .toList();
          if (loaded.isNotEmpty) {
            _items = loaded;
            _isInitialized = true;
            notifyListeners();
            return _items;
          }
        }
      } catch (_) {}
    }

    // 本地缓存为空时，注入种子数据并异步落盘
    final seeds = initialMockSeeds;
    _items = List.of(seeds);
    _isInitialized = true;
    await _persist();
    notifyListeners();
    return _items;
  }

  /// 内部持久化辅助方法
  Future<void> _persist() async {
    final jsonList = _items.take(maxItems).map((e) => e.toJson()).toList();
    await AppPreferences.saveWatchHistoryJson(jsonEncode(jsonList));
  }

  /// 全量保存历史记录（更新内存、落盘并广播）
  Future<void> saveHistory(List<WatchHistoryItem> newItems) async {
    _items = List.of(newItems.take(maxItems));
    _isInitialized = true;
    await _persist();
    notifyListeners();
  }

  /// 更新或插入单条播放进度（最新在前，同番剧聚合替换为最新进度，每部动漫占一行）
  Future<void> recordProgress(WatchHistoryItem entry) async {
    if (!_isInitialized) await getHistory();

    final updatedList = <WatchHistoryItem>[entry];

    // 核心策略：同一番剧只保留最新一条记录（按 bangumiId 聚合更新），杜绝移动端列表刷屏
    for (final item in _items) {
      if (item.bangumiId != entry.bangumiId) {
        updatedList.add(item);
      }
    }

    _items = updatedList.take(maxItems).toList();
    await _persist();
    notifyListeners();
  }

  /// 移除指定 ID 的记录
  Future<void> remove(String id) async {
    if (!_isInitialized) await getHistory();

    _items.removeWhere((item) => item.id == id);
    await _persist();
    notifyListeners();
  }

  /// 批量删除记录
  Future<void> removeMany(Set<String> ids) async {
    if (!_isInitialized) await getHistory();

    _items.removeWhere((item) => ids.contains(item.id));
    await _persist();
    notifyListeners();
  }

  /// 清空播放历史
  Future<void> clear() async {
    _items.clear();
    _isInitialized = true;
    await AppPreferences.clearWatchHistory();
    notifyListeners();
  }

  /// 重置初始化状态（主要用于单元测试隔离）
  @visibleForTesting
  void resetForTest() {
    _items = [];
    _isInitialized = false;
  }
}
