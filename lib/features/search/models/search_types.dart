/// 搜索过滤类型（全部、动漫 type=2、非动漫 type!=2，接口已严格限定仅视频类型 [2, 6]）
enum SearchFilterType {
  all,
  anime,
  nonAnime;

  String get label => switch (this) {
        SearchFilterType.all => '全部',
        SearchFilterType.anime => '动漫',
        SearchFilterType.nonAnime => '非动漫',
      };
}

/// 搜索结果排序类型（对齐 Animaku 规范：最新放送、默认匹配、最早放送）
enum SearchSortType {
  dateDesc,
  defaultMatch,
  dateAsc;

  String get label => switch (this) {
        SearchSortType.dateDesc => '最新放送',
        SearchSortType.defaultMatch => '默认匹配',
        SearchSortType.dateAsc => '最早放送',
      };
}
