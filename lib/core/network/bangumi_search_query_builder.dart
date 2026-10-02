/// Bangumi 搜索请求体与参数构造器
class BangumiSearchQueryBuilder {
  BangumiSearchQueryBuilder._();

  /// 构造 /v0/search/subjects 的 payload
  static Map<String, dynamic>? buildPayload({
    required String keyword,
    String? sort,
    List<String>? tags,
    int? year,
    List<String>? airDate,
    int? type = 2, // 2 = 动画，传 null 且 types 为 null 时表示不限制类型
    List<int>? types, // 多类型过滤（如 [2, 6] 动画+真人/特摄，优先级高于单个 type）
  }) {
    final trimmed = keyword.trim();
    // 只有当没有关键词、也没有任何筛选过滤条件时才直接返回 null (即无需发起请求)
    if (trimmed.isEmpty &&
        (tags == null || tags.isEmpty) &&
        year == null &&
        (airDate == null || airDate.isEmpty) &&
        sort == null) {
      return null;
    }

    // 处理排序逻辑：Bangumi 官方 v0 不支持 date 排序，参照 animaku 上游使用 heat，客户端本地按放送日期倒序
    final isSortByDate = sort == 'date' || sort == 'airdate';
    final upstreamSort = isSortByDate ? 'heat' : sort;

    final filter = <String, dynamic>{
      'nsfw': false,
    };
    if (types != null && types.isNotEmpty) {
      filter['type'] = types;
    } else if (type != null) {
      filter['type'] = [type];
    }
    if (tags != null && tags.isNotEmpty) {
      filter['tag'] = tags;
    }
    if (year != null) {
      filter['air_date'] = ['>=$year-01-01', '<=$year-12-31'];
    }
    if (airDate != null && airDate.isNotEmpty) {
      filter['air_date'] = airDate;
    }

    // 特殊处理说明：
    // 按评分或排名排序时，全量过滤 rank > 0，防止 Bangumi 数据库将未上榜的 rank=0 条目在升序排位中置顶；
    // 按评分排序时同时过滤评分人数少于 50 人的条目 (rating_count >= 50)，保障评分榜单质量，杜绝极少人评分的冷门/刷分条目
    if (upstreamSort == 'rank' || upstreamSort == 'score') {
      filter['rank'] = ['>0', '<=99999'];
    }
    if (upstreamSort == 'score') {
      filter['rating_count'] = ['>=50'];
    }

    final payload = <String, dynamic>{
      'filter': filter,
      // 特殊处理说明：
      // 参照 AniBaka 实践，Bangumi v0 检索接口对于无关键词的纯标签/分类筛选，
      // 若不提供 keyword 会被服务端直接拒绝或超时，必须传递 '*' 保持纯过滤搜索 (filter-only search)。
      'keyword': trimmed.isNotEmpty ? trimmed : '*',
    };
    if (upstreamSort != null && upstreamSort.isNotEmpty) {
      payload['sort'] = upstreamSort;
    }

    return payload;
  }
}
