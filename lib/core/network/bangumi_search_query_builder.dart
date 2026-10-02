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
    int type = 2, // 2 = 动画
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
      'type': [type],
      'nsfw': false,
    };
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
    };
    if (trimmed.isNotEmpty) {
      payload['keyword'] = trimmed;
    }
    if (upstreamSort != null && upstreamSort.isNotEmpty) {
      payload['sort'] = upstreamSort;
    }

    return payload;
  }
}
