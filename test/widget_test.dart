import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

    // 检查顶部胶囊栏：番剧、连载
    expect(find.text('番剧'), findsOneWidget);
    expect(find.text('连载'), findsOneWidget);

    // 检查首屏独立货架大标题
    expect(find.text('🏆 热门 TV 番剧'), findsOneWidget);
    expect(find.text('🎬 热门剧场版'), findsOneWidget);

    // 向下滚动页面，验证第 3 个货架（OVA）视口懒加载正常挂载
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('📀 热门 OVA / 特别篇'), findsOneWidget);

    // 切换到顶部“连载”标签（连载新番周历）
    await tester.tap(find.text('连载'));
    await tester.pumpAndSettle();

    // 切回顶部“番剧”标签
    await tester.tap(find.text('番剧'));
    await tester.pumpAndSettle();
    expect(find.text('🏆 热门 TV 番剧', skipOffstage: false), findsOneWidget);

    // 切换到底部“分类”（四宫格图标）
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.text('⊞ 分类索引'), findsOneWidget);

    // 切换到底部设置
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('个性化定制 (图标与背景壁纸)'), findsOneWidget);

    // 向下滚动设置项，验证网络线路选项
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Bangumi 网络线路'), findsOneWidget);
    expect(find.text('镜像加速线路（推荐）'), findsOneWidget);
    expect(find.text('官方直连线路'), findsOneWidget);
  });
}
