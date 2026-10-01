import 'bangumi_item.dart';

class BangumiWeekday {
  final int id;
  final String en;
  final String cn;
  final String ja;

  const BangumiWeekday({
    required this.id,
    required this.en,
    required this.cn,
    required this.ja,
  });

  factory BangumiWeekday.fromJson(Map<String, dynamic> json) {
    return BangumiWeekday(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
      en: json['en']?.toString() ?? '',
      cn: json['cn']?.toString() ?? '',
      ja: json['ja']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'en': en,
        'cn': cn,
        'ja': ja,
      };
}

class BangumiCalendarDay {
  final BangumiWeekday weekday;
  final List<BangumiItem> items;

  const BangumiCalendarDay({
    required this.weekday,
    required this.items,
  });

  factory BangumiCalendarDay.fromJson(Map<String, dynamic> json) {
    final weekdayJson = (json['weekday'] as Map<String, dynamic>?) ?? {};
    final rawItems = json['items'];
    final List<BangumiItem> itemsList = [];

    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          itemsList.add(BangumiItem.fromJson(it));
        }
      }
    }

    return BangumiCalendarDay(
      weekday: BangumiWeekday.fromJson(weekdayJson),
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
      };
}
