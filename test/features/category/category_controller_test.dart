import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/core/providers/bangumi_providers.dart';
import 'package:zakoni/features/category/controllers/category_controller.dart';
import 'package:zakoni/features/category/controllers/category_state.dart';

void main() {
  group('CategoryFilter & State tests', () {
    test('CategoryFilter.fromInitial default values', () {
      final filter = CategoryFilter.fromInitial(null);
      expect(filter.selectedType, isNull);
      expect(filter.selectedGenres, isEmpty);
      expect(filter.allTags, isNull);
      expect(filter.selectedYear, isNull);
      expect(filter.selectedMonth, isNull);
      expect(filter.selectedSort, equals('heat'));
      expect(filter.isDefaultState, isTrue);
    });

    test('CategoryFilter.fromInitial with specific media type', () {
      final filter = CategoryFilter.fromInitial('剧场版');
      expect(filter.selectedType, equals('剧场版'));
      expect(filter.selectedGenres, isEmpty);
      expect(filter.allTags, equals(['剧场版']));
      expect(filter.selectedYear, isNull);
      expect(filter.selectedMonth, isNull);
      expect(filter.isCurrentSeason, isFalse);
      expect(filter.isDefaultState, isTrue);
    });

    test('CategoryFilter.fromInitial with specific genre', () {
      final filter = CategoryFilter.fromInitial('恋爱');
      expect(filter.selectedType, isNull);
      expect(filter.selectedGenres, equals({'恋爱'}));
      expect(filter.allTags, equals(['恋爱']));
      expect(filter.selectedYear, isNull);
      expect(filter.selectedMonth, isNull);
      expect(filter.isCurrentSeason, isFalse);
      expect(filter.isDefaultState, isTrue);
    });

    test('CategoryFilter combines allTags correctly', () {
      final filter = CategoryFilter(
        selectedType: 'TV',
        selectedGenres: {'热血', '奇幻'},
      );
      expect(filter.allTags, containsAll(['TV', '热血', '奇幻']));
      expect(filter.allTags?.length, equals(3));
    });

    test('CategoryState buildFilterSummary formats expected summary', () {
      final filter = CategoryFilter.fromInitial(null);
      final state = CategoryState(
        filter: filter,
        total: 42,
        isLoading: false,
      );

      final summary = state.buildFilterSummary();
      expect(summary, contains('全部年份'));
      expect(summary, contains('热度'));
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

      // 切换单选形式分类 (TV / 剧场版 / OVA)
      notifier.setType('剧场版');
      expect(container.read(categoryControllerProvider(null)).filter.selectedType, equals('剧场版'));

      // 切换多选题材分类 (可多选、可反选、可一键清空)
      notifier.toggleGenre('热血');
      notifier.toggleGenre('奇幻');
      expect(container.read(categoryControllerProvider(null)).filter.selectedGenres, equals({'热血', '奇幻'}));
      expect(container.read(categoryControllerProvider(null)).filter.allTags, containsAll(['剧场版', '热血', '奇幻']));

      // 批量设置题材分类 (弹窗关闭后统一应用)
      notifier.setGenres({'恋爱', '日常', '治愈'});
      expect(container.read(categoryControllerProvider(null)).filter.selectedGenres, equals({'恋爱', '日常', '治愈'}));

      // 反选奇幻
      notifier.toggleGenre('奇幻');
      expect(container.read(categoryControllerProvider(null)).filter.selectedGenres, contains('奇幻'));

      // 清空题材
      notifier.clearGenres();
      expect(container.read(categoryControllerProvider(null)).filter.selectedGenres, isEmpty);

      // 一键复位至当季
      notifier.resetToCurrentSeason();
      final resetFilter = container.read(categoryControllerProvider(null)).filter;
      expect(resetFilter.isCurrentSeason, isTrue);
    });

    test('retains previous items for smooth transition when switching tag to uncached filter', () async {
      final container = ProviderContainer(
        overrides: [
          bangumiClientProvider.overrideWithValue(BangumiClient()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(categoryControllerProvider(null).notifier);
      notifier.toggleGenre('恋爱');

      // 切换新标签未命中缓存时，保留现有状态平滑过渡，仅标记 isLoading: true
      final state = container.read(categoryControllerProvider(null));
      expect(state.isLoading, isTrue);
    });
  });
}
