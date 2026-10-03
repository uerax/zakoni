import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/core/utils/image_utils.dart';
import 'package:zakoni/features/common/widgets/cached_anime_image.dart';
import 'package:zakoni/features/home/pages/home_page.dart';
import 'package:zakoni/features/home/widgets/rank_horizontal_section.dart';
import 'package:zakoni/features/home/widgets/today_anime_shelf.dart';

Map<String, dynamic> _generateMockJson(String prefix, int index) {
  return {
    'id': 10000 + index,
    'type': 2,
    'name': '$prefix $index',
    'name_cn': '$prefix 中文名 $index',
    'summary': '简介 $index',
    'air_date': '2026-04-01',
    'air_weekday': 1,
    'rank': index + 1,
    'rating': {
      'score': 8.5,
      'total': 1200,
    },
    'collection': {
      'doing': 200 + index * 10,
      'collect': 500 + index * 20,
    },
    'heat': 1000 + index * 50,
    'eps': 12,
    'eps_count': 12,
    'images': {
      'large': 'https://lain.bgm.tv/pic/cover/l/mock_${prefix}_$index.jpg',
      'common': 'https://lain.bgm.tv/pic/cover/c/mock_${prefix}_$index.jpg',
    },
  };
}

class MockHomeClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    if (options.path.contains('calendar')) {
      final days = List.generate(7, (i) {
        final dayIndex = i + 1;
        return {
          'weekday': {'id': dayIndex, 'en': 'Day $dayIndex', 'cn': '星期$dayIndex', 'ja': ''},
          'items': dayIndex == todayWeekday
              ? List.generate(20, (index) => _generateMockJson('Today', index))
              : [],
        };
      });
      return ResponseBody.fromString(
        jsonEncode(days),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // search / trending / hot movies / hot ova
    final tag = options.queryParameters['tags']?.toString() ?? 'TV';
    final items = List.generate(20, (index) => _generateMockJson(tag, index));
    return ResponseBody.fromString(
      jsonEncode({'data': items}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Home initial image loading count benchmark', () {
    testWidgets('390x844 (iPhone 14/15/16)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dio = Dio();
      dio.httpClientAdapter = MockHomeClientAdapter();
      final client = BangumiClient(dio: dio);

      await tester.pumpWidget(MaterialApp(home: HomePage(client: client)));
      await tester.pumpAndSettle();

      final count = find.byType(CachedAnimeImage).evaluate().length;
      final shelves = find.byType(AnimeHorizontalShelf).evaluate().length;
      debugPrint('[iPhone 390x844] 首次打开挂载图片数: $count (横向货架挂载数: $shelves)');
      expect(count, equals(10));
    });

    testWidgets('360x800 (典型中端 Android 手机)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2.75, 800 * 2.75);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dio = Dio();
      dio.httpClientAdapter = MockHomeClientAdapter();
      final client = BangumiClient(dio: dio);

      await tester.pumpWidget(MaterialApp(home: HomePage(client: client)));
      await tester.pumpAndSettle();

      final count = find.byType(CachedAnimeImage).evaluate().length;
      final shelves = find.byType(AnimeHorizontalShelf).evaluate().length;
      debugPrint('[Android 360x800] 首次打开挂载图片数: $count (横向货架挂载数: $shelves)');
      expect(count, inInclusiveRange(9, 11));
    });

    testWidgets('412x915 (大屏旗舰机 Pixel 8 Pro / Galaxy Ultra)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412 * 3.5, 915 * 3.5);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dio = Dio();
      dio.httpClientAdapter = MockHomeClientAdapter();
      final client = BangumiClient(dio: dio);

      await tester.pumpWidget(MaterialApp(home: HomePage(client: client)));
      await tester.pumpAndSettle();

      final count = find.byType(CachedAnimeImage).evaluate().length;
      final shelves = find.byType(AnimeHorizontalShelf).evaluate().length;
      debugPrint('[Large Phone 412x915] 首次打开挂载图片数: $count (横向货架挂载数: $shelves)');
      expect(count, inInclusiveRange(10, 14));
    });
  });
}
