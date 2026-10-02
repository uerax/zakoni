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

  factory BangumiSearchResult.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List?) ?? const [];
    return BangumiSearchResult(
      items: itemsList
          .whereType<Map<String, dynamic>>()
          .map((item) => BangumiItem.fromJson(item))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'limit': limit,
        'offset': offset,
      };

  static const empty = BangumiSearchResult(
    items: [],
    total: 0,
    limit: 20,
    offset: 0,
  );
}
