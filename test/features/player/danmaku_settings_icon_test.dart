import 'dart:ui';
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

  testWidgets('DanmakuToggleIcon renders in enabled and disabled states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DanmakuToggleIcon(
                enabled: true,
                size: 20,
                color: Colors.blue,
              ),
              DanmakuToggleIcon(
                enabled: false,
                size: 20,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DanmakuToggleIcon), findsNWidgets(2));
  });

  test('弹 字符绘制像素中心严格落于 (12.0, 12.0) 且四周边距对称', () async {
    final tp = TextPainter(
      text: const TextSpan(
        text: '弹',
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
          fontFamily: 'MiSans',
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    tp.paint(canvas, Offset(12.0 - tp.width / 2 + 0.5, 12.0 - tp.height / 2 + 1.8));
    final picture = recorder.endRecording();
    final image = await picture.toImage(24, 24);
    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    final bytes = byteData!.buffer.asUint8List();

    int minX = 24, maxX = 0, minY = 24, maxY = 0;
    for (int y = 0; y < 24; y++) {
      for (int x = 0; x < 24; x++) {
        final alpha = bytes[(y * 24 + x) * 4 + 3];
        if (alpha > 20) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    final centerX = (minX + maxX) / 2.0;
    final centerY = (minY + maxY) / 2.0;
    expect((centerX - 12.0).abs(), lessThanOrEqualTo(0.5));
    expect((centerY - 12.0).abs(), lessThanOrEqualTo(0.5));
  });
}
