import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/features/category/pages/category_page.dart';
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

    // 检查顶部全宽沉浸式栏：搜索栏占位文字
    expect(find.text('搜索番剧、剧场版、特别篇...'), findsOneWidget);

    // 检查首屏独立货架大标题（规范排印，无 Emoji）
    expect(find.text('热门 TV 番剧'), findsOneWidget);
    expect(find.text('热门剧场版'), findsOneWidget);

    // 向下滚动页面，验证第 3 个货架（OVA）视口懒加载正常挂载
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('热门 OVA / 特别篇'), findsOneWidget);

    // 切换到底部“分类”（四宫格图标）
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPage), findsOneWidget);
    expect(find.text('全部'), findsNWidgets(2));

    // 切换到底部设置
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('网络线路'), findsOneWidget);
    expect(find.text('镜像加速'), findsOneWidget);
    expect(find.text('官方直连'), findsOneWidget);

    // 向下滚动设置项，验证个性化外观选项
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('个性化外观'), findsOneWidget);
  });

  testWidgets('MainNavigationShell lazy mounts tabs only on first tap', (WidgetTester tester) async {
    final dio = Dio();
    dio.httpClientAdapter = ImmediateMockAdapter();
    final client = BangumiClient(dio: dio);

    await tester.pumpWidget(ZakoniApp(client: client));
    await tester.pump();

    // 刚打开应用时（仅激活 Tab 0 首页）：分类页与设置页未挂载，杜绝后台偷跑网络
    expect(find.byType(CategoryPage), findsNothing);
    expect(find.text('网络线路'), findsNothing);

    // 首次点击分类 Tab：激活挂载分类页
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPage), findsOneWidget);

    // 首次点击设置 Tab：激活挂载设置页
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('网络线路'), findsOneWidget);

    // 切回首页后，已激活的分类页保持常驻保活
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('HomePage adapts to desktop mode with HomeDesktopHero when width >= 840', (WidgetTester tester) async {
    final dio = Dio();
    dio.httpClientAdapter = ImmediateMockAdapter();
    final client = BangumiClient(dio: dio);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(ZakoniApp(client: client));
    await tester.pumpAndSettle();

    expect(find.text('搜索番剧、剧场版、特别篇...'), findsOneWidget);
    expect(find.text('热门 TV 番剧'), findsOneWidget);
  });
}
