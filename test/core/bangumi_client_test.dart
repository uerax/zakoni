import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/models/bangumi/bangumi_collection.dart';
import 'package:zakoni/core/network/bangumi_client.dart';

class MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final result = handler(options);
    final statusCode = result['statusCode'] as int? ?? 200;
    final data = result['data'];
    final jsonStr = jsonEncode(data);

    return ResponseBody.fromString(
      jsonStr,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('BangumiClient tests with MockAdapter', () {
    late Dio dio;
    late BangumiClient client;

    test('getCalendar parses mock response', () async {
      dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/calendar');
        return {
          'statusCode': 200,
          'data': [
            {
              'weekday': {'id': 1, 'en': 'Mon', 'cn': '星期一', 'ja': '月曜日'},
              'items': [
                {'id': 101, 'name': 'Anime Mon', 'type': 2}
              ]
            }
          ]
        };
      });
      client = BangumiClient(dio: dio);

      final calendar = await client.getCalendar();
      expect(calendar.length, 1);
      expect(calendar.first.weekday.cn, '星期一');
      expect(calendar.first.items.first.name, 'Anime Mon');
    });

    test('getSubject returns parsed BangumiItem', () async {
      dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/v0/subjects/1234');
        return {
          'statusCode': 200,
          'data': {
            'id': 1234,
            'type': 2,
            'name': 'Original Name',
            'name_cn': '中文名',
            'eps': 12,
          }
        };
      });
      client = BangumiClient(dio: dio);

      final subject = await client.getSubject(1234);
      expect(subject.id, 1234);
      expect(subject.nameCn, '中文名');
      expect(subject.eps, 12);
    });

    test('getEpisodes returns list of episodes', () async {
      dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/v0/episodes');
        expect(options.queryParameters['subject_id'], 1234);
        return {
          'statusCode': 200,
          'data': {
            'total': 1,
            'limit': 100,
            'offset': 0,
            'data': [
              {
                'id': 999,
                'sort': 1,
                'name_cn': '第一集',
                'duration': '00:24:00',
              }
            ]
          }
        };
      });
      client = BangumiClient(dio: dio);

      final eps = await client.getEpisodes(1234);
      expect(eps.length, 1);
      expect(eps.first.id, 999);
      expect(eps.first.displayTitle, '第一集');
      expect(eps.first.durationSeconds, 1440);
    });

    test('setCollection sends correct authorization and payload', () async {
      dio = Dio(BaseOptions(baseUrl: 'https://api.bgm.tv'));
      dio.httpClientAdapter = MockAdapter((options) {
        expect(options.path, '/v0/users/-/collections/1234');
        expect(options.headers['Authorization'], 'Bearer mock_token');
        final data = options.data as Map<String, dynamic>;
        expect(data['type'], 3); // watching -> 3
        return {'statusCode': 200, 'data': {}};
      });
      client = BangumiClient(dio: dio);

      final success = await client.setCollection(
        1234,
        CollectType.watching,
        'mock_token',
      );
      expect(success, true);
    });
  });
}
