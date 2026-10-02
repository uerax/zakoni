import 'bangumi_item.dart';

/// Bangumi 搜索与分类检索分页结果封装
class BangumiSearchResult {
  final List<BangumiItem> items;
  final int total;
  final int limit;
  final int offset;

  const BangumiSearchResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  bool get hasMore => offset + items.length < total;

  static const empty = BangumiSearchResult(
    items: [],
    total: 0,
    limit: 20,
    offset: 0,
  );
}
