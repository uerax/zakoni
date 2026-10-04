import 'package:flutter/foundation.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../models/category_constants.dart';

@immutable
class CategoryFilter {
  final Set<String> selectedTags; // 所有选中的标签 (包含 TV/剧场版/OVA 及热血等题材，均无单选限制)
  final int? selectedYear;
  final int? selectedMonth;
  final String selectedSort;
  final String? initialCategory;

  CategoryFilter({
    Set<String>? selectedTags,
    String? selectedType,
    Set<String>? selectedGenres,
    this.selectedYear,
    this.selectedMonth,
    this.selectedSort = 'heat',
    this.initialCategory,
  }) : selectedTags = selectedTags ??
            (selectedType != null || selectedGenres != null
                ? {
                    if (selectedType != null && selectedType != '全部') selectedType,
                    ...?selectedGenres,
                  }
                : const {});

  factory CategoryFilter.fromInitial(String? initialCategory) {
    if (initialCategory != null && initialCategory.isNotEmpty && initialCategory != '全部') {
      return CategoryFilter(
        selectedTags: {initialCategory},
        selectedYear: null,
        selectedMonth: null,
        selectedSort: 'heat',
        initialCategory: initialCategory,
      );
    }
    return CategoryFilter(
      selectedTags: const {},
      selectedYear: null,
      selectedMonth: null,
      selectedSort: 'heat',
      initialCategory: null,
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
    if (initialCategory != null && initialCategory!.isNotEmpty && initialCategory != '全部') {
      return selectedTags.length == 1 &&
          selectedTags.contains(initialCategory) &&
          selectedYear == null &&
          selectedMonth == null &&
          selectedSort == 'heat';
    }
    return selectedTags.isEmpty &&
        selectedYear == null &&
        selectedMonth == null &&
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
          initialCategory == other.initialCategory;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(selectedTags),
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
