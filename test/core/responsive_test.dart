import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/utils/responsive.dart';

void main() {
  group('AppBreakpoints tests', () {
    test('gridColumns calculates correct column counts', () {
      expect(AppBreakpoints.gridColumns(320), 3);
      expect(AppBreakpoints.gridColumns(499), 3);
      expect(AppBreakpoints.gridColumns(500), 4);
      expect(AppBreakpoints.gridColumns(749), 4);
      expect(AppBreakpoints.gridColumns(750), 5);
      expect(AppBreakpoints.gridColumns(999), 5);
      expect(AppBreakpoints.gridColumns(1000), 6);
      expect(AppBreakpoints.gridColumns(1920), 6);
    });

    test('responsivePageSize calculates correct page limits for 3 platforms', () {
      // 手机端 (<600): 12 部
      expect(AppBreakpoints.responsivePageSize(360), 12);
      expect(AppBreakpoints.responsivePageSize(390), 12);
      expect(AppBreakpoints.responsivePageSize(599), 12);

      // 平板端 (600 ~ 839): 20 部
      expect(AppBreakpoints.responsivePageSize(600), 20);
      expect(AppBreakpoints.responsivePageSize(768), 20);
      expect(AppBreakpoints.responsivePageSize(839), 20);

      // 桌面端 (>=840): 24 部
      expect(AppBreakpoints.responsivePageSize(840), 24);
      expect(AppBreakpoints.responsivePageSize(1280), 24);
      expect(AppBreakpoints.responsivePageSize(1920), 24);
    });

    testWidgets('ResponsiveContext extension returns correct values', (tester) async {
      late bool isDesktop;
      late bool isCompact;
      late bool isMedium;

      // 1. Mobile compact screen (400x800)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = context.isDesktop;
              isCompact = context.isCompact;
              isMedium = context.isMedium;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isCompact, isTrue);
      expect(isDesktop, isFalse);
      expect(isMedium, isFalse);

      // 2. Desktop expanded screen (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = context.isDesktop;
              isCompact = context.isCompact;
              isMedium = context.isMedium;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isCompact, isFalse);
      expect(isDesktop, isTrue);
      expect(isMedium, isFalse);

      // 3. Medium tablet screen (700x800)
      tester.view.physicalSize = const Size(700, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = context.isDesktop;
              isCompact = context.isCompact;
              isMedium = context.isMedium;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isCompact, isFalse);
      expect(isDesktop, isFalse);
      expect(isMedium, isTrue);
    });
  });
}
