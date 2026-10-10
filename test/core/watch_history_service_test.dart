import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoway/core/models/history/watch_history_item.dart';
import 'package:zakoway/core/services/app_preferences.dart';
import 'package:zakoway/core/services/watch_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.init();
    WatchHistoryService.instance.resetForTest();
  });

  group('WatchHistoryItem & WatchHistoryService tests', () {
    test('WatchHistoryItem serialization and helper getters', () {
      final item = WatchHistoryItem(
        id: '400650::ep14',
        bangumiId: 400650,
        title: '葬送的芙莉莲',
        cover: 'https://lain.bgm.tv/pic/cover/l/d8/d5/400650_6Zz66.jpg',
        episode: 14,
        road: 1,
        pluginName: 'cycani',
        pageUrl: 'https://cycani.org/watch/400650/14',
        position: 1035.0, // 17:15
        duration: 1440.0, // 24:00
        updatedAt: 1712000000000,
      );

      expect(item.progress, closeTo(0.718, 0.01));
      expect(item.positionText, equals('17:15 / 24:00'));
      expect(item.pluginName, equals('cycani'));
      expect(item.road, equals(1));

      final json = item.toJson();
      final parsed = WatchHistoryItem.fromJson(json);

      expect(parsed.id, equals(item.id));
      expect(parsed.bangumiId, equals(400650));
      expect(parsed.title, equals('葬送的芙莉莲'));
      expect(parsed.episode, equals(14));
      expect(parsed.pluginName, equals('cycani'));
      expect(parsed.road, equals(1));
      expect(parsed.position, equals(1035.0));
      expect(parsed.duration, equals(1440.0));
    });

    test('getHistory returns 3 mock seeds with video sources on empty cache', () async {
      final history = await WatchHistoryService.instance.getHistory();

      expect(history.length, equals(3));
      expect(history[0].title, equals('葬送的芙莉莲'));
      expect(history[0].pluginName, equals('cycani'));
      expect(history[0].episode, equals(14));

      expect(history[1].title, equals('迷宫饭'));
      expect(history[1].pluginName, equals('anime1'));
      expect(history[1].episode, equals(8));

      expect(history[2].title, equals('间谍过家家 第二季'));
      expect(history[2].pluginName, equals('omofun'));
      expect(history[2].episode, equals(4));

      // 验证已持久化落盘
      final persistedJson = AppPreferences.getWatchHistoryJson();
      expect(persistedJson, isNotNull);
      expect(persistedJson, contains('cycani'));
      expect(persistedJson, contains('anime1'));
      expect(persistedJson, contains('omofun'));
    });

    test('recordProgress accurately preserves different episodes and dedupes same episode, latestByAnime aggregates correctly', () async {
      await WatchHistoryService.instance.getHistory(); // 初始化 3 条种子 (芙莉莲 ep14, 迷宫饭 ep8, 间谍过家家 ep4)

      var notified = false;
      void listener() {
        notified = true;
      }
      WatchHistoryService.instance.addListener(listener);

      // 1. 播放芙莉莲第 15 话 (新集数)：此时芙莉莲 ep14 与 ep15 应同时保存在底层历史中，共 4 条
      final ep15Progress = WatchHistoryItem(
        id: WatchHistoryItem.buildId(400650, 15),
        bangumiId: 400650,
        title: '葬送的芙莉莲',
        episode: 15,
        pluginName: 'cycani',
        road: 1,
        position: 1200.0, // 20:00
        duration: 1440.0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await WatchHistoryService.instance.recordProgress(ep15Progress);
      final updated = await WatchHistoryService.instance.getHistory();

      expect(notified, isTrue);
      // 底层历史总数变为 4 (芙莉莲 ep15 与 ep14 并存，多集进度不丢失)
      expect(updated.length, equals(4));
      // 最新记录排在第一位，且集数为 15
      expect(updated.first.bangumiId, equals(400650));
      expect(updated.first.episode, equals(15));
      expect(updated.first.position, equals(1200.0));

      // 验证首页聚合属性 latestByAnime：每部番剧仅保留最新一条 (共 3 部番剧)
      final latest = WatchHistoryService.instance.latestByAnime;
      expect(latest.length, equals(3));
      expect(latest.first.bangumiId, equals(400650));
      expect(latest.first.episode, equals(15)); // 取到最新的第 15 话

      // 2. 重新播放同一番剧的同一集 (芙莉莲 ep15 进度更新到 22:00)
      final ep15Updated = WatchHistoryItem(
        id: WatchHistoryItem.buildId(400650, 15),
        bangumiId: 400650,
        title: '葬送的芙莉莲',
        episode: 15,
        pluginName: 'cycani',
        road: 1,
        position: 1320.0, // 22:00
        duration: 1440.0,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await WatchHistoryService.instance.recordProgress(ep15Updated);
      final reUpdated = await WatchHistoryService.instance.getHistory();
      // 同集数覆盖更新，总数依然为 4
      expect(reUpdated.length, equals(4));
      expect(reUpdated.first.position, equals(1320.0));

      // 3. 测试按番剧全量删除
      await WatchHistoryService.instance.removeByBangumi(400650);
      final afterRemoveBangumi = await WatchHistoryService.instance.getHistory();
      // 芙莉莲全部集数被清除，剩余 2 部番剧
      expect(afterRemoveBangumi.length, equals(2));
      expect(afterRemoveBangumi.any((i) => i.bangumiId == 400650), isFalse);

      WatchHistoryService.instance.removeListener(listener);
    });

    test('groupWatchHistory and computeHistoryStats algorithms work correctly', () {
      final now = DateTime(2026, 10, 4, 15, 30);
      final items = [
        WatchHistoryItem(
          id: '1::ep1',
          bangumiId: 1,
          title: '今天番剧',
          episode: 1,
          pluginName: 'cycani',
          position: 1400.0,
          duration: 1440.0, // 已看完
          updatedAt: DateTime(2026, 10, 4, 14, 0).millisecondsSinceEpoch,
        ),
        WatchHistoryItem(
          id: '2::ep2',
          bangumiId: 2,
          title: '昨天番剧',
          episode: 2,
          pluginName: 'anime1',
          position: 720.0,
          duration: 1440.0,
          updatedAt: DateTime(2026, 10, 3, 20, 0).millisecondsSinceEpoch,
        ),
        WatchHistoryItem(
          id: '3::ep3',
          bangumiId: 3,
          title: '近7天番剧',
          episode: 3,
          pluginName: 'omofun',
          position: 300.0,
          duration: 1440.0,
          updatedAt: DateTime(2026, 10, 1, 10, 0).millisecondsSinceEpoch,
        ),
      ];

      final groups = groupWatchHistory(items, now);
      expect(groups.length, equals(3));
      expect(groups[0].label, equals('今天'));
      expect(groups[0].items.first.title, equals('今天番剧'));
      expect(groups[1].label, equals('昨天'));
      expect(groups[2].label, equals('近 7 天'));

      final stats = computeHistoryStats(items, now);
      expect(stats.totalCount, equals(3));
      expect(stats.todayCount, equals(1));
      expect(stats.finishedCount, equals(1));
      expect(stats.totalWatchHours, closeTo(0.67, 0.05));
    });

    test('remove and clear methods work as expected and notify listeners', () async {
      final history = await WatchHistoryService.instance.getHistory();
      expect(history.length, equals(3));

      var removeNotified = false;
      WatchHistoryService.instance.addListener(() => removeNotified = true);

      await WatchHistoryService.instance.remove(history.first.id);
      final afterRemove = await WatchHistoryService.instance.getHistory();
      expect(afterRemove.length, equals(2));
      expect(removeNotified, isTrue);

      var clearNotified = false;
      WatchHistoryService.instance.addListener(() => clearNotified = true);

      await WatchHistoryService.instance.clear();
      expect(AppPreferences.getWatchHistoryJson(), isNull);
      expect(WatchHistoryService.instance.items, isEmpty);
      expect(clearNotified, isTrue);
    });
  });
}
