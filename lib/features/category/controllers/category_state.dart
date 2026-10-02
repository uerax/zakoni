import 'package:flutter/foundation.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../models/category_constants.dart';

@immutable
class CategoryFilter {
  final String? selectedTag;
  final int? selectedYear;
  final int? selectedMonth;
  final String selectedSort;
  final String? initialCategory;

  const CategoryFilter({
    this.selectedTag,
    this.selectedYear,
    this.selectedMonth,
    this.selectedSort = 'heat',
    this.initialCategory,
  });

  factory CategoryFilter.fromInitial(String? initialCategory) {
    if (initialCategory != null && initialCategory.isNotEmpty) {
      return CategoryFilter(
        selectedTag: initialCategory,
        selectedYear: null,
        selectedMonth: null,
        selectedSort: 'heat',
        initialCategory: initialCategory,
      );
    }
    return CategoryFilter(
      selectedTag: null,
      selectedYear: CategoryConstants.currentYear,
      selectedMonth: CategoryConstants.currentSeasonMonth,
      selectedSort: 'heat',
      initialCategory: null,
    );
  }

  /// 是否处于默认的“当季新番”状态
  bool get isCurrentSeason =>
      selectedYear == CategoryConstants.currentYear &&
      selectedMonth == CategoryConstants.currentSeasonMonth &&
      (selectedTag == null || selectedTag == '全部') &&
      selectedSort == 'heat';

  /// 是否处于初始默认选项（未被用户二次修改）
  bool get isDefaultState {
    if (initialCategory != null && initialCategory!.isNotEmpty) {
      return selectedTag == initialCategory &&
          selectedYear == null &&
          selectedMonth == null &&
          selectedSort == 'heat';
    }
    return isCurrentSeason;
  }

  CategoryFilter copyWith({
    Object? selectedTag = _sentinel,
    Object? selectedYear = _sentinel,
    Object? selectedMonth = _sentinel,
    String? selectedSort,
    String? initialCategory,
  }) {
    return CategoryFilter(
      selectedTag: selectedTag == _sentinel ? this.selectedTag : selectedTag as String?,
      selectedYear: selectedYear == _sentinel ? this.selectedYear : selectedYear as int?,
      selectedMonth: selectedMonth == _sentinel ? this.selectedMonth : selectedMonth as int?,
      selectedSort: selectedSort ?? this.selectedSort,
      initialCategory: initialCategory ?? this.initialCategory,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryFilter &&
          runtimeType == other.runtimeType &&
          selectedTag == other.selectedTag &&
          selectedYear == other.selectedYear &&
          selectedMonth == other.selectedMonth &&
          selectedSort == other.selectedSort &&
          initialCategory == other.initialCategory;

  @override
  int get hashCode => Object.hash(
        selectedTag,
        selectedYear,
        selectedMonth,
        selectedSort,
        initialCategory,
      );
}

@immutable
class CategoryState {
  final CategoryFilter filter;
  final List<BangumiItem> items;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final bool isTagExpanded;

  const CategoryState({
    required this.filter,
    this.items = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.isTagExpanded = false,
  });

  CategoryState copyWith({
    CategoryFilter? filter,
    List<BangumiItem>? items,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? errorMessage = _sentinel,
    bool? isTagExpanded,
  }) {
    return CategoryState(
      filter: filter ?? this.filter,
      items: items ?? this.items,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      isTagExpanded: isTagExpanded ?? this.isTagExpanded,
    );
  }

  static const _sentinel = Object();

  /// 构造顶部筛选摘要副标题
  String buildFilterSummary() {
    if (isLoading) return '💡 正在检索 Bangumi 动画条目...';

    final parts = <String>[];
    if (filter.selectedTag != null && filter.selectedTag != '全部') {
      parts.add('标签: ${filter.selectedTag}');
    }
    if (filter.selectedMonth != null && filter.selectedMonth! > 0) {
      final y = filter.selectedYear ?? CategoryConstants.currentYear;
      parts.add('$y年 ${CategoryConstants.seasonShortName(filter.selectedMonth!)}');
    } else if (filter.selectedYear != null) {
      parts.add('${filter.selectedYear}年');
    } else {
      parts.add('全部年份');
    }

    final sortItem = CategoryConstants.sortOptions.firstWhere(
      (s) => s.key == filter.selectedSort,
      orElse: () => CategoryConstants.sortOptions.first,
    );
    parts.add(sortItem.label);

    if (total > 0) {
      parts.add('共 $total 部');
    } else if (!isLoading && errorMessage == null) {
      parts.add('暂无匹配结果');
    }

    return '💡 ${parts.join(' · ')}';
  }
}
