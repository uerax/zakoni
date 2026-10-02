import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/bangumi_providers.dart';
import '../models/category_constants.dart';
import 'category_state.dart';

final categoryControllerProvider = NotifierProvider.autoDispose
    .family<CategoryController, CategoryState, String?>(
  CategoryController.new,
);

class CategoryController extends Notifier<CategoryState> {
  final String? initialCategory;
  int _requestSeq = 0;

  CategoryController([this.initialCategory]);

  @override
  CategoryState build() {
    final filter = CategoryFilter.fromInitial(initialCategory);
    // 在下一个 microtask 启动第一页数据加载，避免在 build 过程中同步修改状态
    Future.microtask(fetchFirstPage);
    return CategoryState(filter: filter, isLoading: true);
  }

  /// 构建当前筛选条件的日期与参数，向 Bangumi 发起第一页请求
  Future<void> fetchFirstPage() async {
    final seq = ++_requestSeq;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final filter = state.filter;
      final tagList = (filter.selectedTag != null && filter.selectedTag != '全部')
          ? [filter.selectedTag!]
          : null;

      List<String>? airDate;
      int? yearParam;

      if (filter.selectedMonth != null && filter.selectedMonth! > 0) {
        final targetYear = filter.selectedYear ?? CategoryConstants.currentYear;
        yearParam = targetYear;
        airDate = CategoryConstants.seasonAirDate(targetYear, filter.selectedMonth!);
      } else if (filter.selectedYear != null) {
        yearParam = filter.selectedYear;
      }

      final client = ref.read(bangumiClientProvider);
      final result = await client.searchWithTotal(
        '',
        tags: tagList,
        year: yearParam,
        airDate: airDate,
        sort: filter.selectedSort,
        limit: CategoryConstants.pageSize,
        offset: 0,
      );

      if (seq != _requestSeq) return;

      state = state.copyWith(
        items: result.items,
        total: result.total,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 滚动触底加载下一页数据
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final filter = state.filter;
      final tagList = (filter.selectedTag != null && filter.selectedTag != '全部')
          ? [filter.selectedTag!]
          : null;

      List<String>? airDate;
      int? yearParam;

      if (filter.selectedMonth != null && filter.selectedMonth! > 0) {
        final targetYear = filter.selectedYear ?? CategoryConstants.currentYear;
        yearParam = targetYear;
        airDate = CategoryConstants.seasonAirDate(targetYear, filter.selectedMonth!);
      } else if (filter.selectedYear != null) {
        yearParam = filter.selectedYear;
      }

      final client = ref.read(bangumiClientProvider);
      final result = await client.searchWithTotal(
        '',
        tags: tagList,
        year: yearParam,
        airDate: airDate,
        sort: filter.selectedSort,
        limit: CategoryConstants.pageSize,
        offset: state.items.length,
      );

      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setTag(String? tag) {
    final effectiveTag = (tag == '全部') ? null : tag;
    if (state.filter.selectedTag == effectiveTag) return;
    state = state.copyWith(
      filter: state.filter.copyWith(selectedTag: effectiveTag),
      isTagExpanded: false,
    );
    fetchFirstPage();
  }

  void setYear(int? year) {
    if (state.filter.selectedYear == year) return;
    state = state.copyWith(
      filter: state.filter.copyWith(selectedYear: year),
    );
    fetchFirstPage();
  }

  void setMonth(int? month) {
    final targetMonth = (month == null || month == 0) ? null : month;
    if (state.filter.selectedMonth == targetMonth) return;

    int? newYear = state.filter.selectedYear;
    // 友好联动：若此前为“全部年份”，点击具体季度自动对齐到今年
    if (targetMonth != null && newYear == null) {
      newYear = CategoryConstants.currentYear;
    }

    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedMonth: targetMonth,
        selectedYear: newYear,
      ),
    );
    fetchFirstPage();
  }

  void setSort(String sort) {
    if (state.filter.selectedSort == sort) return;
    state = state.copyWith(
      filter: state.filter.copyWith(selectedSort: sort),
    );
    fetchFirstPage();
  }

  void toggleTagExpanded([bool? expanded]) {
    state = state.copyWith(
      isTagExpanded: expanded ?? !state.isTagExpanded,
    );
  }

  /// 一键复位至“当季新番”
  void resetToCurrentSeason() {
    if (state.filter.isCurrentSeason) return;
    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedTag: null,
        selectedYear: CategoryConstants.currentYear,
        selectedMonth: CategoryConstants.currentSeasonMonth,
        selectedSort: 'heat',
      ),
      isTagExpanded: false,
    );
    fetchFirstPage();
  }

  /// 复原到初始默认选项（若有 initialCategory 则恢复该分类，否则复原为当季新番默认选项）
  void resetToDefault() {
    if (state.filter.isDefaultState) return;
    state = state.copyWith(
      filter: CategoryFilter.fromInitial(state.filter.initialCategory),
      isTagExpanded: false,
    );
    fetchFirstPage();
  }
}
