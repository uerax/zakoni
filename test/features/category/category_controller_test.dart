import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/core/providers/bangumi_providers.dart';
import 'package:zakoni/features/category/controllers/category_controller.dart';
import 'package:zakoni/features/category/controllers/category_state.dart';
import 'package:zakoni/features/category/models/category_constants.dart';

void main() {
  group('CategoryFilter & State tests', () {
    test('CategoryFilter.fromInitial default values', () {
      final filter = CategoryFilter.fromInitial(null);
      expect(filter.selectedTag, isNull);
      expect(filter.selectedYear, equals(CategoryConstants.currentYear));
      expect(filter.selectedMonth, equals(CategoryConstants.currentSeasonMonth));
      expect(filter.selectedSort, equals('heat'));
      expect(filter.isCurrentSeason, isTrue);
      expect(filter.isDefaultState, isTrue);
    });

    test('CategoryFilter.fromInitial with specific category', () {
      final filter = CategoryFilter.fromInitial('剧场版');
      expect(filter.selectedTag, equals('剧场版'));
      expect(filter.selectedYear, isNull);
      expect(filter.selectedMonth, isNull);
      expect(filter.isCurrentSeason, isFalse);
      expect(filter.isDefaultState, isTrue);
    });

    test('CategoryState buildFilterSummary formats expected summary', () {
      final filter = CategoryFilter.fromInitial(null);
      final state = CategoryState(
        filter: filter,
        total: 42,
        isLoading: false,
      );

      final summary = state.buildFilterSummary();
      expect(summary, contains('${CategoryConstants.currentYear}年'));
      expect(summary, contains(CategoryConstants.seasonShortName(CategoryConstants.currentSeasonMonth)));
      expect(summary, contains('热度优先'));
      expect(summary, contains('共 42 部'));
    });
  });

  group('CategoryController Riverpod tests', () {
    test('CategoryController responds to filter updates', () async {
      final container = ProviderContainer(
        overrides: [
          bangumiClientProvider.overrideWithValue(BangumiClient()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(categoryControllerProvider(null).notifier);

      // 切换排序
      notifier.setSort('score');
      expect(container.read(categoryControllerProvider(null)).filter.selectedSort, equals('score'));

      // 切换年份
      notifier.setYear(2022);
      expect(container.read(categoryControllerProvider(null)).filter.selectedYear, equals(2022));

      // 切换月份并验证联动
      notifier.setMonth(4);
      expect(container.read(categoryControllerProvider(null)).filter.selectedMonth, equals(4));

      // 切换题材标签
      notifier.setTag('科幻');
      expect(container.read(categoryControllerProvider(null)).filter.selectedTag, equals('科幻'));

      // 一键复位至当季
      notifier.resetToCurrentSeason();
      final resetFilter = container.read(categoryControllerProvider(null)).filter;
      expect(resetFilter.isCurrentSeason, isTrue);
    });
  });
}
