import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/models/bangumi/bangumi_item.dart';
import 'package:zakoni/core/models/home/recommend_item.dart';
import 'package:zakoni/features/home/widgets/continue_watching_shelf.dart';
import 'package:zakoni/features/home/widgets/daily_spotlight_card.dart';

BangumiItem _createMockItem(int id, String name, double score) {
  return BangumiItem(
    id: id,
    type: 2,
    name: name,
    nameCn: '$name 中文',
    summary: '简介 $name',
    airDate: '2026-04-01',
    airWeekday: 1,
    rank: 1,
    images: {
      'large': 'https://lain.bgm.tv/pic/cover/l/mock_$id.jpg',
    },
    tags: const [],
    alias: const [],
    ratingScore: score,
    votes: 500,
    eps: 12,
    totalEpisodes: 12,
  );
}

void main() {
  group('RecommendItem model & rule engine tests', () {
    test('generateRecommendations creates sorted recommendations with explainability', () {
      final items = [
        _createMockItem(1, 'Item One', 7.5),
        _createMockItem(2, 'Item Two', 9.2),
        _createMockItem(3, 'Item Three', 8.4),
      ];

      final recs = RecommendItem.generateRecommendations(items);
      expect(recs.length, equals(3));
      // 高分优先
      expect(recs.first.item.id, equals(2));
      expect(recs.first.item.ratingScore, equals(9.2));
      expect(recs.first.matchRate, inInclusiveRange(85, 99));
      expect(recs.first.reason, isNotEmpty);
      expect(recs.first.tag, isNotEmpty);
    });

    test('generateRecommendations handles empty source gracefully', () {
      final recs = RecommendItem.generateRecommendations([]);
      expect(recs, isEmpty);
    });
  });

  group('ContinueWatchingShelf widget tests', () {
    testWidgets('Empty records renders SizedBox.shrink with 0 dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContinueWatchingShelf(records: []),
          ),
        ),
      );

      expect(find.text('继续追番'), findsNothing);
      expect(find.byType(ContinueWatchingShelf), findsOneWidget);
    });

    testWidgets('Non-empty records renders cards with progress information', (tester) async {
      final mockRecord = WatchProgressItem(
        item: _createMockItem(10, 'Frieren', 9.4),
        episodeNumber: 8,
        progress: 0.72,
        positionText: '18:23 / 24:00',
        lastWatchTime: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContinueWatchingShelf(
              records: [mockRecord],
            ),
          ),
        ),
      );

      expect(find.text('继续追番'), findsOneWidget);
      expect(find.text('Frieren 中文'), findsOneWidget);
      expect(find.textContaining('第 8 话'), findsOneWidget);
      expect(find.textContaining('72%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('DailySpotlightCard widget tests', () {
    testWidgets('Renders recommendation details and supports switching', (tester) async {
      final recs = [
        RecommendItem(
          item: _createMockItem(101, 'Cowboy Bebop', 9.1),
          reason: '渡边信一郎硬核太空浪漫神作',
          tag: '口碑神作',
          matchRate: 98,
        ),
        RecommendItem(
          item: _createMockItem(102, 'Dungeon Meshi', 8.8),
          reason: '极高水准奇幻生态冒险剧',
          tag: '当季精选',
          matchRate: 95,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailySpotlightCard(recommendations: recs),
          ),
        ),
      );

      // 第一部展示
      expect(find.text('今日推荐'), findsOneWidget);
      expect(find.text('98% 契合'), findsOneWidget);
      expect(find.text('口碑神作'), findsOneWidget);
      expect(find.text('Cowboy Bebop 中文'), findsOneWidget);
      expect(find.textContaining('渡边信一郎硬核太空浪漫神作'), findsOneWidget);

      // 点击“换一部”
      await tester.tap(find.text('换一部'));
      await tester.pumpAndSettle();

      // 切换至第二部
      expect(find.text('95% 契合'), findsOneWidget);
      expect(find.text('当季精选'), findsOneWidget);
      expect(find.text('Dungeon Meshi 中文'), findsOneWidget);
      expect(find.textContaining('极高水准奇幻生态冒险剧'), findsOneWidget);
    });
  });
}
