import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoni/core/models/history/watch_history_item.dart';
import 'package:zakoni/core/services/app_preferences.dart';
import 'package:zakoni/core/services/watched_episodes_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.init();
    WatchedEpisodesService.instance.resetForTest();
    await WatchedEpisodesService.instance.initialize();
  });

  group('WatchedEpisodesService 已看集数策略测试 (对齐 animaku 规范)', () {
    test('1. 标记已看、查询、取消与切换逻辑', () {
      final service = WatchedEpisodesService.instance;
      const bgmId = 400650;

      expect(service.isWatched(bgmId, 1), isFalse);
      expect(service.getWatchedEpisodes(bgmId), isEmpty);

      // 标记第 1 话为已看
      service.markWatched(bgmId, 1);
      expect(service.isWatched(bgmId, 1), isTrue);
      expect(service.getWatchedEpisodes(bgmId), contains(1));

      // 幂等测试：重复标记不抛错
      service.markWatched(bgmId, 1);
      expect(service.isWatched(bgmId, 1), isTrue);

      // 标记第 2 话为已看
      service.markWatched(bgmId, 2);
      expect(service.getWatchedEpisodes(bgmId), equals({1, 2}));

      // toggle 测试：已看的取消，未看的标记
      service.toggleWatched(bgmId, 1); // 变为未看
      expect(service.isWatched(bgmId, 1), isFalse);
      expect(service.getWatchedEpisodes(bgmId), equals({2}));

      service.toggleWatched(bgmId, 3); // 变为已看
      expect(service.isWatched(bgmId, 3), isTrue);
      expect(service.getWatchedEpisodes(bgmId), equals({2, 3}));

      // 取消第 2 话
      service.unmarkWatched(bgmId, 2);
      expect(service.isWatched(bgmId, 2), isFalse);
      expect(service.getWatchedEpisodes(bgmId), equals({3}));
    });

    test('2. 多番剧独立隔离与清空测试', () {
      final service = WatchedEpisodesService.instance;
      const frierenId = 400650;
      const dunmeshiId = 395377;

      service.markWatched(frierenId, 1);
      service.markWatched(frierenId, 2);
      service.markWatched(dunmeshiId, 5);

      expect(service.getWatchedEpisodes(frierenId), equals({1, 2}));
      expect(service.getWatchedEpisodes(dunmeshiId), equals({5}));

      // 清空芙莉莲
      service.clearBangumi(frierenId);
      expect(service.getWatchedEpisodes(frierenId), isEmpty);
      expect(service.getWatchedEpisodes(dunmeshiId), equals({5}));

      // 全量清空
      service.clearAll();
      expect(service.getWatchedEpisodes(dunmeshiId), isEmpty);
    });

    test('3. 本地持久化恢复测试', () async {
      final service = WatchedEpisodesService.instance;
      const bgmId = 400650;

      service.markWatched(bgmId, 14);
      service.markWatched(bgmId, 15);

      // 模拟应用重启：重置内存实例并重新初始化
      service.resetForTest();
      expect(service.isWatched(bgmId, 14), isFalse);

      await service.initialize();
      expect(service.isWatched(bgmId, 14), isTrue);
      expect(service.isWatched(bgmId, 15), isTrue);
      expect(service.getWatchedEpisodes(bgmId), equals({14, 15}));
    });

    test('4. 完播判定公式 (isPlaybackFinished) 测试', () {
      // 达到 90%
      final finishedItem1 = WatchHistoryItem(
        id: '1::ep1',
        bangumiId: 1,
        title: '测试',
        episode: 1,
        pluginName: 'test',
        position: 1300.0,
        duration: 1440.0, // 90.2%
        updatedAt: 0,
      );
      expect(finishedItem1.isFinished, isTrue);

      // 未达 90% 但长视频 (duration > 120) 剩余 <= 60s
      final finishedItem2 = WatchHistoryItem(
        id: '1::ep2',
        bangumiId: 1,
        title: '测试',
        episode: 2,
        pluginName: 'test',
        position: 1390.0,
        duration: 1440.0, // 剩余 50s
        updatedAt: 0,
      );
      expect(finishedItem2.isFinished, isTrue);

      // 播到一半 (不满足完播)
      final playingItem = WatchHistoryItem(
        id: '1::ep3',
        bangumiId: 1,
        title: '测试',
        episode: 3,
        pluginName: 'test',
        position: 600.0,
        duration: 1440.0,
        updatedAt: 0,
      );
      expect(playingItem.isFinished, isFalse);
    });

    test('5. 续播防卡死保护算法逻辑验证', () {
      // 模拟断点续播算法判定
      bool shouldResetToStart(double position, double duration) {
        if ((duration > 30 && (position >= duration - 15 || position / duration >= 0.95)) ||
            position < 15) {
          return true;
        }
        return false;
      }

      // 情况 A: 已播到片尾最后 10 秒 (23:50 / 24:00) -> 触发保护重置为 0
      expect(shouldResetToStart(1430.0, 1440.0), isTrue);

      // 情况 B: 进度达到 96% (23:05 / 24:00) -> 触发保护重置为 0
      expect(shouldResetToStart(1385.0, 1440.0), isTrue);

      // 情况 C: 刚看不足 15 秒 (8s) -> 触发保护从头播放
      expect(shouldResetToStart(8.0, 1440.0), isTrue);

      // 情况 D: 看了一半 (15:00 / 24:00) -> 正常断点续播
      expect(shouldResetToStart(900.0, 1440.0), isFalse);
    });
  });
}
