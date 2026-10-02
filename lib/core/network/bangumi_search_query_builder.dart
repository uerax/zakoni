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

    // 智能时间感知分流：提取当前检索的目标年份
    int? effectiveYear = year;
    if (effectiveYear == null && airDate != null && airDate.isNotEmpty) {
      final match = RegExp(r'\d{4}').firstMatch(airDate.first);
      if (match != null) {
        effectiveYear = int.tryParse(match.group(0)!);
      }
    }

    // 特殊处理说明：
    // 1. 历史已完结年份或全量大库搜索时，必须过滤 rank > 0，防止 Bangumi 数据库将未上榜的 rank=0 条目在升序排位中置顶；
    // 2. 当前正在播出的当季新番（年份 >= 当前年份），绝大多数条目尚未结榜（rank 仍为 0），不加此过滤以确保完整展示当前季度的所有新番条目。
    final isCurrentOrFuture = effectiveYear != null && effectiveYear >= DateTime.now().year;
    if (!isCurrentOrFuture && (upstreamSort == 'rank' || upstreamSort == 'score')) {
      filter['rank'] = ['>0', '<=99999'];
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
