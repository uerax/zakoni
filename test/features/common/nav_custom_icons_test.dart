import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoway/features/common/widgets/app_floating_bottom_bar.dart';
import 'package:zakoway/features/common/widgets/nav_custom_icons.dart';

void main() {
  group('NavCustomIcons', () {
    testWidgets('JellyNavIcon renders without exception in both states', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                JellyNavIcon(color: Colors.green, isSelected: false),
                JellyNavIcon(color: Colors.green, isSelected: true),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(JellyNavIcon), findsNWidgets(2));
    });

    testWidgets('PenguinNavIcon renders without exception in both states', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PenguinNavIcon(color: Colors.blue, isSelected: false),
                PenguinNavIcon(color: Colors.blue, isSelected: true),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(PenguinNavIcon), findsNWidgets(2));
    });

    testWidgets('AppFloatingBottomBar supports both custom builders and IconData', (WidgetTester tester) async {
      int tappedIndex = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppFloatingBottomBar(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
              items: [
                AppFloatingNavItem(
                  builder: (context, color, isSelected) => JellyNavIcon(
                    color: color,
                    isSelected: isSelected,
                  ),
                ),
                AppFloatingNavItem(
                  builder: (context, color, isSelected) => PenguinNavIcon(
                    color: color,
                    isSelected: isSelected,
                  ),
                ),
                const AppFloatingNavItem(
                  unselectedIcon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(JellyNavIcon), findsOneWidget);
      expect(find.byType(PenguinNavIcon), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      await tester.tap(find.byType(PenguinNavIcon));
      await tester.pump();
      expect(tappedIndex, 1);
    });
  });
}
