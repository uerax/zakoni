import 'package:flutter/foundation.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../models/category_constants.dart';

@immutable
class CategoryInitialArgs {
  final String? category;
  final int? year;
  final int? month;

  const CategoryInitialArgs({
    this.category,
    this.year,
    this.month,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryInitialArgs &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(category, year, month);

  @override
  String toString() =>
      'CategoryInitialArgs(category: $category, year: $year, month: $month)';
}

@immutable
class CategoryFilter {
  final Set<String> selectedTags; // 所有选中的标签 (包含 TV/剧场版/OVA 及热血等题材，均无单选限制)
  final int? selectedYear;
  final int? selectedMonth;
  final String selectedSort;
  final String? initialCategory;
  final int? initialYear;
  final int? initialMonth;

  CategoryFilter({
    Set<String>? selectedTags,
    String? selectedType,
    Set<String>? selectedGenres,
    this.selectedYear,
    this.selectedMonth,
    this.selectedSort = 'heat',
    this.initialCategory,
    this.initialYear,
    this.initialMonth,
  }) : selectedTags = selectedTags ??
            (selectedType != null || selectedGenres != null
                ? {
                    if (selectedType != null && selectedType != '全部') selectedType,
                    ...?selectedGenres,
                  }
                : const {});

  factory CategoryFilter.fromInitial([Object? initial]) {
    if (initial is CategoryInitialArgs) {
      final initialCategory = initial.category;
      final initialYear = initial.year;
      final initialMonth = initial.month;
      final hasCategory = initialCategory != null &&
          initialCategory.isNotEmpty &&
          initialCategory != '全部';

      return CategoryFilter(
        selectedTags: hasCategory ? {initialCategory} : const {},
        selectedYear: initialYear,
        selectedMonth: initialMonth,
        selectedSort: 'heat',
        initialCategory: initialCategory,
        initialYear: initialYear,
        initialMonth: initialMonth,
      );
    } else if (initial is String) {
      final hasCategory = initial.isNotEmpty && initial != '全部';
      return CategoryFilter(
        selectedTags: hasCategory ? {initial} : const {},
        selectedYear: null,
        selectedMonth: null,
        selectedSort: 'heat',
        initialCategory: initial,
        initialYear: null,
        initialMonth: null,
      );
    }

    return CategoryFilter(
      selectedTags: const {},
      selectedYear: null,
      selectedMonth: null,
      selectedSort: 'heat',
      initialCategory: null,
      initialYear: null,
      initialMonth: null,
    );
  }

  /// 组合生成用于检索的上游标签列表
  List<String>? get allTags => selectedTags.isEmpty ? null : selectedTags.toList();

  /// 兼容旧版单一 tag 访问
  String? get selectedTag => selectedTags.length == 1 ? selectedTags.first : null;
  String? get selectedType => selectedTags.where((t) => CategoryConstants.mediaTypes.contains(t)).firstOrNull;
  Set<String> get selectedGenres => selectedTags.where((t) => !CategoryConstants.mediaTypes.contains(t)).toSet();

  /// 是否处于默认的“当季新番”状态
  bool get isCurrentSeason =>
      selectedYear == CategoryConstants.currentYear &&
      selectedMonth == CategoryConstants.currentSeasonMonth &&
      selectedTags.isEmpty &&
      selectedSort == 'heat';

  /// 是否处于初始默认选项（未被用户二次修改）
  bool get isDefaultState {
    final hasCategory = initialCategory != null &&
        initialCategory!.isNotEmpty &&
        initialCategory != '全部';
    final isCategoryMatch = hasCategory
        ? (selectedTags.length == 1 && selectedTags.contains(initialCategory))
        : selectedTags.isEmpty;

    return isCategoryMatch &&
        selectedYear == initialYear &&
        selectedMonth == initialMonth &&
        selectedSort == 'heat';
  }

  CategoryFilter copyWith({
    Set<String>? selectedTags,
    Object? selectedType = _sentinel,
    Set<String>? selectedGenres,
    Object? selectedYear = _sentinel,
    Object? selectedMonth = _sentinel,
    String? selectedSort,
    String? initialCategory,
    Object? initialYear = _sentinel,
    Object? initialMonth = _sentinel,
  }) {
    Set<String> effectiveTags = selectedTags ?? this.selectedTags;
    if (selectedGenres != null || selectedType != _sentinel) {
      final newType = selectedType == _sentinel ? this.selectedType : selectedType as String?;
      final newGenres = selectedGenres ?? this.selectedGenres;
      effectiveTags = {
        if (newType != null && newType != '全部') newType,
        ...newGenres,
      };
    }

    return CategoryFilter(
      selectedTags: effectiveTags,
      selectedYear: selectedYear == _sentinel ? this.selectedYear : selectedYear as int?,
      selectedMonth: selectedMonth == _sentinel ? this.selectedMonth : selectedMonth as int?,
      selectedSort: selectedSort ?? this.selectedSort,
      initialCategory: initialCategory ?? this.initialCategory,
      initialYear: initialYear == _sentinel ? this.initialYear : initialYear as int?,
      initialMonth: initialMonth == _sentinel ? this.initialMonth : initialMonth as int?,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryFilter &&
          runtimeType == other.runtimeType &&
          setEquals(selectedTags, other.selectedTags) &&
          selectedYear == other.selectedYear &&
          selectedMonth == other.selectedMonth &&
          selectedSort == other.selectedSort &&
          initialCategory == other.initialCategory &&
          initialYear == other.initialYear &&
          initialMonth == other.initialMonth;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(selectedTags),
        selectedYear,
        selectedMonth,
        selectedSort,
        initialCategory,
        initialYear,
        initialMonth,
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
    if (isLoading) return '正在检索 Bangumi 动画条目...';

    final parts = <String>[];
    if (filter.selectedTags.isNotEmpty) {
      parts.add(filter.selectedTags.join('+'));
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

    // 方案 B：仅在精准筛选且结果数 < 1000 时展示准确数字；超过或等于 1000 时为官方截断上限，直接隐藏避免误导
    if (total > 0 && total < 1000) {
      parts.add('共 $total 部');
    } else if (!isLoading && errorMessage == null && total == 0) {
      parts.add('暂无匹配结果');
    }

    return parts.join(' · ');
  }
}
