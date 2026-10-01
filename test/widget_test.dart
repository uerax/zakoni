import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/main.dart';

class ImmediateMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final dynamic responseData = options.path.contains('calendar') ? [] : {'data': []};

    return ResponseBody.fromString(
      jsonEncode(responseData),
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
  testWidgets('ZakoniApp smoke test with navigation and settings', (WidgetTester tester) async {
    final dio = Dio();
    dio.httpClientAdapter = ImmediateMockAdapter();
    final client = BangumiClient(dio: dio);

    await tester.pumpWidget(ZakoniApp(client: client));
    await tester.pumpAndSettle();

    // 检查顶部胶囊栏：番剧、分类
    expect(find.text('番剧'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('🏆 热门排行'), findsOneWidget);
    expect(find.text('TV'), findsOneWidget);
    expect(find.text('剧场版'), findsOneWidget);
    expect(find.text('OVA'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);

    // 切换到分类标签
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(find.text('分类检索功能设计中'), findsOneWidget);

    // 切回番剧标签
    await tester.tap(find.text('番剧'));
    await tester.pumpAndSettle();
    expect(find.text('🏆 热门排行'), findsOneWidget);

    // 测试点击热门排行的“更多”，快速切换到分类 Tab
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(find.text('分类检索功能设计中'), findsOneWidget);

    // 切回番剧标签
    await tester.tap(find.text('番剧'));
    await tester.pumpAndSettle();

    // 切换到底部时间表
    await tester.tap(find.text('时间表'));
    await tester.pumpAndSettle();
    expect(find.text('每日放送'), findsOneWidget);

    // 切换到底部设置
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('Bangumi 网络线路'), findsOneWidget);
    expect(find.text('镜像加速线路（推荐）'), findsOneWidget);
    expect(find.text('官方直连线路'), findsOneWidget);
  });
}
