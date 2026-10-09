import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoni/core/constants/app_constants.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/core/services/app_preferences.dart';
import 'package:zakoni/features/common/widgets/ios_swipe_action_tile.dart';
import 'package:zakoni/features/settings/widgets/network_settings_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.init();
  });

  Widget buildTestWidget({
    required BangumiClient client,
    BangumiSourcePreset currentPreset = BangumiSourcePreset.mirror,
    ValueChanged<BangumiSourcePreset>? onPresetChanged,
    VoidCallback? onRouteChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NetworkSettingsCard(
            client: client,
            currentPreset: currentPreset,
            onPresetChanged: onPresetChanged ?? (_) {},
            onRouteChanged: onRouteChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('renders built-in presets and add route tile', (tester) async {
    final client = BangumiClient();
    await tester.pumpWidget(buildTestWidget(client: client));
    await tester.pumpAndSettle();

    expect(find.text('网络线路'), findsOneWidget);
    expect(find.text('镜像加速'), findsOneWidget);
    expect(find.text('官方直连'), findsOneWidget);
    expect(find.text('添加自定义线路'), findsOneWidget);
  });

  testWidgets('switches between presets', (tester) async {
    final client = BangumiClient();
    BangumiSourcePreset? changedPreset;

    await tester.pumpWidget(buildTestWidget(
      client: client,
      onPresetChanged: (preset) => changedPreset = preset,
    ));
    await tester.pumpAndSettle();

    // 点击官方直连
    await tester.tap(find.text('官方直连'));
    await tester.pumpAndSettle();

    expect(changedPreset, equals(BangumiSourcePreset.official));
    expect(client.activeRouteId, equals(BangumiSourcePreset.official.name));
    expect(find.text('已切换至官方直连'), findsOneWidget);
  });

  testWidgets('adds custom route via manual reverse proxy URL input', (tester) async {
    final client = BangumiClient();

    await tester.pumpWidget(buildTestWidget(client: client));
    await tester.pumpAndSettle();

    // 点击添加自定义线路
    await tester.tap(find.text('添加自定义线路'));
    await tester.pumpAndSettle();

    // 手动输入反代 URL 和名称
    await tester.enterText(find.widgetWithText(TextField, '线路名称（选填）'), '自建代理');
    await tester.enterText(find.widgetWithText(TextField, '反代 URL 或仓库链接'), 'https://my-proxy.anime');
    await tester.pumpAndSettle();

    // 点击确认添加（顶栏 ✓ 圆纽）
    await tester.tap(find.byKey(const ValueKey('tg_form_confirm_btn')));
    await tester.pump();
    expect(find.text('已添加线路【自建代理】'), findsOneWidget);
    await tester.pumpAndSettle();

    // 弹窗关闭，列表中出现新线路
    expect(find.text('自建代理'), findsOneWidget);
    expect(find.text('https://my-proxy.anime'), findsOneWidget);
    expect(AppPreferences.getCustomNetworkRoutes().length, equals(1));

    // 点击切换至新线路
    await tester.tap(find.text('自建代理'));
    await tester.pumpAndSettle();

    expect(client.activeRouteId, startsWith('custom_'));
    expect(client.baseUrl, equals('https://my-proxy.anime'));
    expect(find.text('已切换至自定义线路【自建代理】'), findsOneWidget);
  });

  testWidgets('imports route from default repo link with fallback placeholder', (tester) async {
    final client = BangumiClient();

    await tester.pumpWidget(buildTestWidget(client: client));
    await tester.pumpAndSettle();

    // 点击添加自定义线路
    await tester.tap(find.text('添加自定义线路'));
    await tester.pumpAndSettle();

    // 点击填入内置仓库链接
    await tester.tap(find.text('点击填入内置仓库链接'));
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.defaultRoutesRepoUrl), findsOneWidget);
    expect(find.text('内置仓库线路'), findsOneWidget);

    // 点击确认添加（顶栏 ✓ 圆纽，走 JSON 仓库分支，未联网时安全回退占位）
    await tester.tap(find.byKey(const ValueKey('tg_form_confirm_btn')));
    await tester.pumpAndSettle();
    expect(find.text('已成功从仓库导入 1 条线路'), findsOneWidget);

    // 弹窗关闭，列表中出现解析生成的有效节点（反代 Base URL，而非 .json 链接）
    expect(find.text('内置仓库线路'), findsOneWidget);
    expect(find.text('https://bgmapi.anibt.net'), findsOneWidget);
    expect(AppPreferences.getCustomNetworkRoutes().length, equals(1));

    // 点击切换至新线路
    await tester.tap(find.text('内置仓库线路'));
    await tester.pumpAndSettle();

    expect(client.activeRouteId, startsWith('custom_'));
    expect(client.baseUrl, equals('https://bgmapi.anibt.net'));
    expect(find.text('已切换至自定义线路【内置仓库线路】'), findsOneWidget);
  });

  testWidgets('deletes custom route via swipe and confirm dialog', (tester) async {
    const customRoute = CustomNetworkRoute(
      id: 'custom_test_1',
      name: '测试自建',
      url: 'https://test.proxy',
    );
    await AppPreferences.saveCustomNetworkRoutes([customRoute]);
    await AppPreferences.saveActiveRouteId(customRoute.id);

    final client = BangumiClient();
    expect(client.activeRouteId, equals('custom_test_1'));

    await tester.pumpWidget(buildTestWidget(client: client));
    await tester.pumpAndSettle();

    expect(find.text('测试自建'), findsOneWidget);

    // 查找 IosSwipeActionTile 并触发删除
    final swipeTile = find.byType(IosSwipeActionTile);
    expect(swipeTile, findsOneWidget);

    // 向左拖拽露出删除按钮
    await tester.drag(swipeTile, const Offset(-100, 0));
    await tester.pumpAndSettle();

    // 点击删除按钮（带 Icons.delete_outline_rounded）
    final deleteButton = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // 弹出确认移除对话框
    expect(find.text('移除自定义线路'), findsOneWidget);
    expect(find.text('确定要移除【测试自建】吗？'), findsOneWidget);

    // 确认移除
    await tester.tap(find.text('确认移除'));
    await tester.pump();
    expect(find.text('已移除线路【测试自建】，并恢复至镜像加速'), findsOneWidget);
    await tester.pumpAndSettle();

    // 线路已移除，恢复至镜像加速
    expect(find.text('测试自建'), findsNothing);
    expect(AppPreferences.getCustomNetworkRoutes(), isEmpty);
    expect(client.activeRouteId, equals(BangumiSourcePreset.mirror.name));
  });
}
