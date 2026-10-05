import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/widgets/controls/danmaku_settings_icon.dart';

void main() {
  testWidgets('DanmakuSettingsIcon renders and paints without errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: DanmakuSettingsIcon(
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DanmakuSettingsIcon), findsOneWidget);
  });
}
