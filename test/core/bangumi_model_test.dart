import 'package:flutter_test/flutter_test.dart';
import 'package:zakoway/core/models/bangumi/bangumi_calendar.dart';
import 'package:zakoway/core/models/bangumi/bangumi_collection.dart';
import 'package:zakoway/core/models/bangumi/bangumi_episode.dart';
import 'package:zakoway/core/models/bangumi/bangumi_item.dart';
import 'package:zakoway/core/utils/html_utils.dart';

void main() {
  group('decodeHtmlEntities', () {
    test('decodes basic XML and HTML named entities', () {
      expect(decodeHtmlEntities('&amp;'), '&');
      expect(decodeHtmlEntities('&lt;div&gt;'), '<div>');
      expect(decodeHtmlEntities('&quot;hello&quot;'), '"hello"');
      expect(decodeHtmlEntities('&apos;world&apos;'), "'world'");
      expect(decodeHtmlEntities('space&nbsp;here'), 'space here');
    });

    test('decodes decimal and hex entities', () {
      expect(decodeHtmlEntities('&#65;'), 'A');
      expect(decodeHtmlEntities('&#x41;'), 'A');
      expect(decodeHtmlEntities('&#x26;'), '&');
    });

    test('prevents recursive multi-pass decoding', () {
      // &amp;#39; -> &#39;, never to single quote
      expect(decodeHtmlEntities('&amp;#39;'), '&#39;');
    });
  });

  group('formatCompactCount & labels', () {
    test('basic numbers and thresholds', () {
      expect(formatCompactCount(850), '850');
      expect(formatDoingLabel(850), '850 人在看');
      expect(formatCompactCount(99), '99');
      expect(formatCompactCount(2058), '2.1k');
      expect(formatDoingLabel(2058), '2.1k 人在看');
      expect(formatCompactCount(1000), '1k');
      expect(formatCompactCount(4321), '4.3k');
      expect(formatCompactCount(12500), '1.3w');
      expect(formatDoingLabel(12500), '1.3w 人在看');
      expect(formatCompactCount(42397), '4.2w');
      expect(formatCompactCount(100000), '10w');
      expect(formatCompactCount(0), '');
      expect(formatDoingLabel(0), null);
      expect(formatCompactCount(-5), '');
      expect(formatCompactCount(null), '');
    });
  });

  group('estimateAirProgress & airProgressLabel', () {
    final fixedNow = DateTime(2026, 9, 3);

    test('status classification', () {
      // 1. Upcoming
      expect(estimateAirProgress('2026-10-01', 12, now: fixedNow).status, BangumiAirStatus.upcoming);
      expect(airProgressLabel('2026-10-01', 12, now: fixedNow), '未开播');

      // 2. Airing
      expect(estimateAirProgress('2026-07-06', 12, now: fixedNow).status, BangumiAirStatus.airing);
      expect(airProgressLabel('2026-07-06', 12, now: fixedNow), '连载中');

      // 3. Finished when planned eps completed
      expect(estimateAirProgress('2026-01-10', 12, now: fixedNow).status, BangumiAirStatus.finished);
      expect(airProgressLabel('2026-01-10', 12, now: fixedNow), '已完结');

      // 4. Finished when eps is unknown but started > 180 days ago
      expect(estimateAirProgress('2024-04-01', 0, now: fixedNow).status, BangumiAirStatus.finished);
      expect(airProgressLabel('2024-04-01', 0, now: fixedNow), '已完结');
    });
  });

  group('airBadgeLabel', () {
    final fixedNow = DateTime(2026, 9, 3);

    test('label combinations', () {
      // Airing with doing count
      expect(
        airBadgeLabel(airDate: '2026-07-06', eps: 12, doing: 2058, now: fixedNow),
        '连载中 · 2.1k人在看',
      );

      // Airing without doing count
      expect(
        airBadgeLabel(airDate: '2026-07-06', eps: 12, now: fixedNow),
        '连载中',
      );

      // Finished with doing count
      expect(
        airBadgeLabel(airDate: '2026-01-10', eps: 12, doing: 520, now: fixedNow),
        '已完结 · 520人在看',
      );

      // Airing with heat count
      expect(
        airBadgeLabel(airDate: '2026-07-06', eps: 12, heat: 4566, now: fixedNow),
        '连载中 · 4.6k 热度',
      );

      // Finished with collect count
      expect(
        airBadgeLabel(airDate: '2026-01-10', eps: 12, collect: 58658, now: fixedNow),
        '已完结 · 5.9w 看过',
      );

      // Finished with both doing and collect count (prefers collect for finished)
      expect(
        airBadgeLabel(airDate: '2026-01-10', eps: 12, doing: 322, collect: 58658, now: fixedNow),
        '已完结 · 5.9w 看过',
      );

      // Upcoming without doing count
      expect(
        airBadgeLabel(airDate: '2026-10-01', eps: 12, now: fixedNow),
        '未开播',
      );
    });
  });

  group('BangumiItem.fromJson', () {
    test('parses full json with alias, html entities and rating', () {
      final json = {
        'id': 1001,
        'type': 2,
        'name': '葬送のフリーレン &amp; 仲間たち',
        'name_cn': '葬送的芙莉莲',
        'summary': '这是&quot;一部&quot;神作',
        'date': '2023-09-29',
        'eps': 28,
        'total_episodes': 28,
        'rating': {
          'rank': 1,
          'score': 8.94,
          'total': 15000,
        },
        'collection': {
          'doing': 8200,
          'collect': 32000,
        },
        'images': {
          'large': 'https://lain.bgm.tv/pic/cover/l/1.jpg',
          'common': 'https://lain.bgm.tv/pic/cover/c/1.jpg',
        },
        'tags': [
          {'name': '奇幻', 'count': 500},
          {'name': '冒险', 'count': 450},
        ],
        'infobox': [
          {
            'key': '别名',
            'values': [
              {'v': 'Frieren'},
              {'v': 'Sousou no Frieren'},
            ],
          }
        ],
      };

      final item = BangumiItem.fromJson(json);

      expect(item.id, 1001);
      expect(item.name, '葬送のフリーレン & 仲間たち');
      expect(item.nameCn, '葬送的芙莉莲');
      expect(item.summary, '这是"一部"神作');
      expect(item.preferredName, '葬送的芙莉莲');
      expect(item.coverUrl, 'https://lain.bgm.tv/pic/cover/l/1.jpg');
      expect(item.ratingScore, 8.9);
      expect(item.rank, 1);
      expect(item.votes, 15000);
      expect(item.doing, 8200);
      expect(item.collect, 32000);
      expect(item.eps, 28);
      expect(item.alias, ['Frieren', 'Sousou no Frieren']);
      expect(item.tags.length, 2);
      expect(item.tags.first.name, '奇幻');
      expect(item.tags.first.count, 500);
    });

    test('parses fallback info string correctly', () {
      final meta = parseBangumiInfoMeta('12话 / 2026年7月6日 / 監督…');
      expect(meta.eps, 12);
      expect(meta.airDate, '2026-07-06');
    });
  });

  group('BangumiEpisode', () {
    test('parses episode json and duration', () {
      final json = {
        'id': 12345,
        'type': 0,
        'sort': 1,
        'name': '冒険の終わり',
        'name_cn': '冒险的终点',
        'duration': '00:24:15',
        'airdate': '2023-09-29',
        'ep': 1,
      };

      final ep = BangumiEpisode.fromJson(json);
      expect(ep.id, 12345);
      expect(ep.sort, 1.0);
      expect(ep.displayTitle, '冒险的终点');
      expect(ep.episodeLabel, '01');
      expect(ep.durationSeconds, 24 * 60 + 15);
    });

    test('handles SP episode label', () {
      final json = {
        'id': 12346,
        'type': 1,
        'sort': 1,
        'name': 'SP 1',
        'ep': 1,
      };
      final ep = BangumiEpisode.fromJson(json);
      expect(ep.episodeLabel, 'SP01');
    });
  });

  group('CollectType conversion', () {
    test('maps local to remote and vice versa', () {
      expect(CollectType.watching.toBangumiType(), 3);
      expect(CollectType.fromBangumiType(3), CollectType.watching);

      expect(CollectType.planToWatch.toBangumiType(), 1);
      expect(CollectType.fromBangumiType(1), CollectType.planToWatch);

      expect(CollectType.watched.toBangumiType(), 2);
      expect(CollectType.fromBangumiType(2), CollectType.watched);

      expect(CollectType.none.toBangumiType(), null);
      expect(CollectType.fromBangumiType(99), CollectType.none);
    });
  });

  group('BangumiCalendarDay.fromJson', () {
    test('parses calendar items', () {
      final json = {
        'weekday': {'id': 1, 'en': 'Mon', 'cn': '星期一', 'ja': '月曜日'},
        'items': [
          {'id': 101, 'name': 'Anime A', 'type': 2},
          {'id': 102, 'name': 'Anime B', 'type': 2},
        ]
      };

      final day = BangumiCalendarDay.fromJson(json);
      expect(day.weekday.cn, '星期一');
      expect(day.weekday.id, 1);
      expect(day.items.length, 2);
      expect(day.items.first.id, 101);
    });
  });
}
