import '../../../core/models/bangumi/bangumi_item.dart';
import '../models/search_types.dart';

/// 搜索页面状态模型
class SearchState {
  final String keyword;
  final List<BangumiItem> allItems;
  final SearchFilterType filter;
  final SearchSortType sort;
  final bool isLoading;
  final String? errorMessage;

  const SearchState({
    this.keyword = '',
    this.allItems = const [],
    this.filter = SearchFilterType.anime,
    this.sort = SearchSortType.dateDesc,
    this.isLoading = false,
    this.errorMessage,
  });

  /// 动漫分类列表（type == 2）
  List<BangumiItem> get animeItems =>
      allItems.where((item) => item.type == 2).toList();

  /// 非动漫分类列表（type != 2，在接口限定 [2, 6] 视频范围下包含特摄与真人影视，彻底排除漫画与游戏）
  List<BangumiItem> get nonAnimeItems =>
      allItems.where((item) => item.type != 2).toList();

  int get allCount => allItems.length;
  int get animeCount => animeItems.length;
  int get nonAnimeCount => nonAnimeItems.length;

  /// 根据当前筛选和排序计算后的结果列表
  List<BangumiItem> get filteredAndSortedItems {
    final List<BangumiItem> items = switch (filter) {
      SearchFilterType.all => allItems,
      SearchFilterType.anime => animeItems,
      SearchFilterType.nonAnime => nonAnimeItems,
    };

    if (sort == SearchSortType.dateDesc) {
      final sorted = [...items];
      sorted.sort((a, b) {
        final da = a.airDate.trim();
        final db = b.airDate.trim();
        if (da == db) return 0;
        if (da.isEmpty) return 1;
        if (db.isEmpty) return -1;
        return db.compareTo(da);
      });
      return sorted;
    } else if (sort == SearchSortType.dateAsc) {
      final sorted = [...items];
      sorted.sort((a, b) {
        final da = a.airDate.trim();
        final db = b.airDate.trim();
        if (da == db) return 0;
        if (da.isEmpty) return 1;
        if (db.isEmpty) return -1;
        return da.compareTo(db);
      });
      return sorted;
    }

    return items;
  }

  SearchState copyWith({
    String? keyword,
    List<BangumiItem>? allItems,
    SearchFilterType? filter,
    SearchSortType? sort,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      allItems: allItems ?? this.allItems,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
