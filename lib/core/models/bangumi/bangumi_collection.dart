enum CollectType {
  none(0, '未收藏'),
  watching(1, '在看'),
  planToWatch(2, '想看'),
  onHold(3, '搁置'),
  watched(4, '看过'),
  abandoned(5, '抛弃');

  final int value;
  final String label;
  const CollectType(this.value, this.label);

  static CollectType fromValue(int? val) {
    if (val == null) return CollectType.none;
    for (final t in CollectType.values) {
      if (t.value == val) return t;
    }
    return CollectType.none;
  }

  /// 转换为 Bangumi 官方 API 的 collection_type
  /// 官方标准: 1: 想看, 2: 看过, 3: 在看, 4: 搁置, 5: 抛弃
  int? toBangumiType() {
    switch (this) {
      case CollectType.planToWatch:
        return 1;
      case CollectType.watched:
        return 2;
      case CollectType.watching:
        return 3;
      case CollectType.onHold:
        return 4;
      case CollectType.abandoned:
        return 5;
      case CollectType.none:
        return null;
    }
  }

  /// 从 Bangumi 官方 API 的 collection_type 转换
  static CollectType fromBangumiType(int? remote) {
    switch (remote) {
      case 1:
        return CollectType.planToWatch;
      case 2:
        return CollectType.watched;
      case 3:
        return CollectType.watching;
      case 4:
        return CollectType.onHold;
      case 5:
        return CollectType.abandoned;
      default:
        return CollectType.none;
    }
  }
}

class BangumiCollectionEntry {
  final int subjectId;
  final CollectType type;
  final String? updatedAt;
  final int? rate;
  final String? comment;
  final int? epStatus;

  const BangumiCollectionEntry({
    required this.subjectId,
    required this.type,
    this.updatedAt,
    this.rate,
    this.comment,
    this.epStatus,
  });

  factory BangumiCollectionEntry.fromJson(Map<String, dynamic> json) {
    final typeVal = json['type'] ?? json['type_id'];
    return BangumiCollectionEntry(
      subjectId: json['subject_id'] is int ? json['subject_id'] : int.tryParse('${json['subject_id']}') ?? 0,
      type: typeVal is int ? CollectType.fromBangumiType(typeVal) : CollectType.none,
      updatedAt: json['updated_at']?.toString(),
      rate: json['rate'] is int ? json['rate'] : int.tryParse('${json['rate']}'),
      comment: json['comment']?.toString(),
      epStatus: json['ep_status'] is int ? json['ep_status'] : int.tryParse('${json['ep_status']}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'type': type.toBangumiType(),
      'updated_at': updatedAt,
      'rate': rate,
      'comment': comment,
      'ep_status': epStatus,
    };
  }
}
