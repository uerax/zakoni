import '../../utils/html_utils.dart';
import '../../utils/image_utils.dart';

class BangumiTag {
  final String name;
  final int count;

  const BangumiTag({
    required this.name,
    this.count = 0,
  });

  factory BangumiTag.fromJson(dynamic json) {
    if (json is String) {
      return BangumiTag(name: json);
    }
    if (json is Map<String, dynamic>) {
      return BangumiTag(
        name: json['name']?.toString() ?? '',
        count: (json['count'] is num) ? (json['count'] as num).toInt() : 0,
      );
    }
    return BangumiTag(name: json?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
      };
}

enum BangumiAirStatus {
  upcoming,
  airing,
  finished,
  unknown,
}

class BangumiAirProgress {
  final BangumiAirStatus status;
  final int airedEpisodes;
  final int eps;

  const BangumiAirProgress({
    required this.status,
    required this.airedEpisodes,
    required this.eps,
  });
}

class BangumiItem {
  final int id;
  final int type;
  final String name;
  final String nameCn;
  final String summary;
  final String airDate;
  final int airWeekday;
  final int rank;
  final Map<String, String> images;
  final List<BangumiTag> tags;
  final List<String> alias;
  final double ratingScore;
  final int votes;
  final String? info;
  final int eps;
  final int totalEpisodes;
  final int? doing;
  final int? collect;
  final int? heat;

  const BangumiItem({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.rank,
    required this.images,
    required this.tags,
    required this.alias,
    required this.ratingScore,
    required this.votes,
    this.info,
    required this.eps,
    required this.totalEpisodes,
    this.doing,
    this.collect,
    this.heat,
  });

  /// 获取优先展示的中文名称，若为空则降级为原名
  String get preferredName => nameCn.isNotEmpty ? nameCn : name;

  /// 封面图快捷获取（优先 large，其次 common/medium/small）
  String get coverUrl =>
      images['large'] ??
      images['common'] ??
      images['medium'] ??
      images['small'] ??
      images['grid'] ??
      '';

  /// 列表缩略图（优先 large，并通过 preferResizedCover 动态挂接 400px 高清切片，杜绝使用 150px 模糊小图）
  String get thumbnailUrl {
    final raw = images['large'] ??
        images['common'] ??
        images['medium'] ??
        images['small'] ??
        images['grid'] ??
        '';
    return preferResizedCover(raw, maxEdge: 400);
  }

  factory BangumiItem.fromJson(Map<String, dynamic> json) {
    final rating = (json['rating'] as Map<String, dynamic>?) ?? {};
    final collection = (json['collection'] as Map<String, dynamic>?) ?? {};

    final doingRaw = (collection['doing'] ?? json['doing'] ?? json['watchers'] ?? 0) as num?;
    final doing = (doingRaw != null && doingRaw > 0) ? doingRaw.toInt() : null;

    final collectRaw = (collection['collect'] ?? json['collect'] ?? 0) as num?;
    final collect = (collectRaw != null && collectRaw > 0) ? collectRaw.toInt() : null;

    final heatRaw = (json['heat'] ?? json['count'] ?? 0) as num?;
    final heat = (heatRaw != null && heatRaw > 0) ? heatRaw.toInt() : null;

    Map<String, String> imagesMap = {};
    if (json['images'] is Map) {
      final img = json['images'] as Map;
      img.forEach((k, v) {
        if (v != null) imagesMap[k.toString()] = v.toString();
      });
    } else if (json['image'] is String && (json['image'] as String).isNotEmpty) {
      final imgStr = json['image'] as String;
      imagesMap = {
        'large': imgStr,
        'common': imgStr,
        'medium': imgStr,
        'small': imgStr,
        'grid': imgStr,
      };
    }

    final nameCnRaw = (json['name_cn'] ?? json['nameCN'] ?? json['name'] ?? '').toString();
    final info = json['info']?.toString() ?? '';
    final fromInfo = parseBangumiInfoMeta(info);

    String airDate = (json['date'] ??
            (json['airtime'] is Map ? (json['airtime'] as Map)['date'] : null) ??
            json['air_date'] ??
            '')
        .toString();
    if (airDate.isEmpty && fromInfo.airDate.isNotEmpty) {
      airDate = fromInfo.airDate;
    }

    final epsRaw = (json['eps'] ?? 0) as num?;
    final epsFromApi = (epsRaw != null && epsRaw > 0) ? epsRaw.toInt() : 0;
    final eps = epsFromApi > 0 ? epsFromApi : (fromInfo.eps > 0 ? fromInfo.eps : 0);

    final totalRaw = (json['total_episodes'] ?? json['totalEpisodes'] ?? 0) as num?;
    final totalEpisodes = (totalRaw != null && totalRaw > 0) ? totalRaw.toInt() : 0;

    final tagsRaw = json['tags'];
    final List<BangumiTag> tagsList = [];
    if (tagsRaw is List) {
      for (final t in tagsRaw) {
        tagsList.add(BangumiTag.fromJson(t));
      }
    }

    final rawScore = rating['score'] as num?;
    final score = rawScore != null ? double.parse(rawScore.toStringAsFixed(1)) : 0.0;

    return BangumiItem(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
      type: (json['type'] is num) ? (json['type'] as num).toInt() : 2,
      name: decodeHtmlEntities(json['name']?.toString() ?? ''),
      nameCn: decodeHtmlEntities(nameCnRaw),
      summary: decodeHtmlEntities(json['summary']?.toString() ?? ''),
      airDate: airDate,
      airWeekday: dateToWeekday(airDate),
      rank: (rating['rank'] is num) ? (rating['rank'] as num).toInt() : 0,
      images: imagesMap,
      tags: tagsList,
      alias: parseBangumiAliases(json),
      ratingScore: score,
      votes: (rating['total'] is num) ? (rating['total'] as num).toInt() : 0,
      info: info.isNotEmpty ? info : null,
      eps: eps,
      totalEpisodes: totalEpisodes,
      doing: doing,
      collect: collect,
      heat: heat,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'nameCn': nameCn,
        'summary': summary,
        'airDate': airDate,
        'airWeekday': airWeekday,
        'rank': rank,
        'images': images,
        'tags': tags.map((t) => t.toJson()).toList(),
        'alias': alias,
        'ratingScore': ratingScore,
        'votes': votes,
        'info': info,
        'eps': eps,
        'totalEpisodes': totalEpisodes,
        'doing': doing,
        'collect': collect,
        'heat': heat,
      };
}

/// 解析 next.bgm.tv 列表常见的 info 字符串 (如 "12话 / 2026年7月6日 / 監督…")
({int eps, String airDate}) parseBangumiInfoMeta(String info) {
  final text = info.trim();
  if (text.isEmpty) return (eps: 0, airDate: '');

  int eps = 0;
  final epsMatch = RegExp(r'(\d+)\s*话').firstMatch(text);
  if (epsMatch != null) {
    eps = int.tryParse(epsMatch.group(1) ?? '') ?? 0;
  }

  String airDate = '';
  final cnMatch = RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日').firstMatch(text);
  if (cnMatch != null) {
    final y = cnMatch.group(1)!;
    final m = cnMatch.group(2)!.padLeft(2, '0');
    final d = cnMatch.group(3)!.padLeft(2, '0');
    airDate = '$y-$m-$d';
  } else {
    final isoMatch = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b').firstMatch(text);
    if (isoMatch != null) {
      airDate = isoMatch.group(1)!;
    }
  }

  return (eps: eps, airDate: airDate);
}

/// 从 infobox 中提取别名
List<String> parseBangumiAliases(Map<String, dynamic> json) {
  final infobox = json['infobox'];
  if (infobox is! List) return const [];

  for (final item in infobox) {
    if (item is! Map) continue;
    if (item['key']?.toString() != '别名') continue;
    final raw = item['values'] ?? item['value'];
    if (raw == null) return const [];
    if (raw is List) {
      final List<String> result = [];
      for (final el in raw) {
        String str = '';
        if (el is Map && el.containsKey('v')) {
          str = el['v']?.toString() ?? '';
        } else {
          str = el?.toString() ?? '';
        }
        final cleaned = decodeHtmlEntities(str).trim();
        if (cleaned.isNotEmpty) result.add(cleaned);
      }
      return result;
    }
    final text = decodeHtmlEntities(raw.toString()).trim();
    return text.isNotEmpty ? [text] : const [];
  }
  return const [];
}

/// 日期转换为星期几 (1=Mon .. 7=Sun, 0=未知)
int dateToWeekday(String dateStr) {
  if (dateStr.isEmpty) return 0;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(dateStr.trim());
  if (match != null) {
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final dt = DateTime.utc(y, m, d);
    return dt.weekday; // DateTime.weekday 在 Dart 中正好是 1=Mon .. 7=Sun
  }
  final dt = DateTime.tryParse(dateStr);
  return dt != null ? dt.toUtc().weekday : 0;
}

/// 严格优先级解析国家 Tag: 日本 -> 国产 -> 欧美 -> 韩国 (兜底为 日本)
String resolveCountryTag(List<dynamic>? tags) {
  if (tags == null || tags.isEmpty) return '日本';
  final names = tags.map((t) {
    if (t is String) return t;
    if (t is BangumiTag) return t.name;
    if (t is Map) return t['name']?.toString() ?? '';
    return '';
  }).where((n) => n.isNotEmpty).toList();

  if (names.contains('日本')) return '日本';
  if (names.contains('国产')) return '国产';
  if (names.contains('欧美')) return '欧美';
  if (names.contains('韩国')) return '韩国';
  return '日本';
}

/// 估算番剧更新进度
BangumiAirProgress estimateAirProgress(
  String airDate,
  int eps, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(airDate.trim());
  if (match == null) {
    return BangumiAirProgress(status: BangumiAirStatus.unknown, airedEpisodes: 0, eps: eps);
  }

  final y = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);

  final startDay = DateTime(y, m, d);
  final todayDay = DateTime(current.year, current.month, current.day);

  if (startDay.isAfter(todayDay)) {
    return BangumiAirProgress(status: BangumiAirStatus.upcoming, airedEpisodes: 0, eps: eps);
  }

  final days = todayDay.difference(startDay).inDays;
  int aired = (days ~/ 7) + 1;
  if (aired < 1) aired = 1;

  if (eps > 0) {
    if (aired >= eps) {
      return BangumiAirProgress(status: BangumiAirStatus.finished, airedEpisodes: eps, eps: eps);
    }
    return BangumiAirProgress(status: BangumiAirStatus.airing, airedEpisodes: aired, eps: eps);
  }

  if (days > 180) {
    return BangumiAirProgress(status: BangumiAirStatus.finished, airedEpisodes: aired, eps: 0);
  }

  return BangumiAirProgress(status: BangumiAirStatus.airing, airedEpisodes: aired, eps: 0);
}

/// 卡片与元数据状态文案: '已完结' | '连载中' | '未开播' | null
String? airProgressLabel(String airDate, int eps, {DateTime? now}) {
  final p = estimateAirProgress(airDate, eps, now: now);
  switch (p.status) {
    case BangumiAirStatus.finished:
      return '已完结';
    case BangumiAirStatus.upcoming:
      return '未开播';
    case BangumiAirStatus.airing:
      return '连载中';
    case BangumiAirStatus.unknown:
      return null;
  }
}

/// 数字格式化 (如 2058 -> '2.1k', 12500 -> '1.3w')
String formatCompactCount(int? count) {
  if (count == null || count <= 0) return '';
  if (count >= 10000) {
    final v = (count / 10000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '${v}w';
  }
  if (count >= 1000) {
    final v = (count / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '${v}k';
  }
  return '$count';
}

String? formatDoingLabel(int? count) {
  final text = formatCompactCount(count);
  return text.isNotEmpty ? '$text 人在看' : null;
}

String? formatHeatLabel(int? count) {
  final text = formatCompactCount(count);
  return text.isNotEmpty ? '$text 热度' : null;
}

String? formatCollectLabel(int? count) {
  final text = formatCompactCount(count);
  return text.isNotEmpty ? '$text 看过' : null;
}

/// 封面底部浮标文案 (如: '连载中 · 4.6k热度' | '已完结 · 5.9w看过')
String? airBadgeLabel({
  required String airDate,
  required int eps,
  int? heat,
  int? doing,
  int? collect,
  DateTime? now,
}) {
  final status = airProgressLabel(airDate, eps, now: now);
  String? statText;

  if (heat != null && heat > 0) {
    statText = '${formatCompactCount(heat)} 热度';
  } else if (status == '已完结' && collect != null && collect > 0) {
    statText = '${formatCompactCount(collect)} 看过';
  } else if (doing != null && doing > 0) {
    statText = '${formatCompactCount(doing)}人在看';
  } else if (collect != null && collect > 0) {
    statText = '${formatCompactCount(collect)} 看过';
  }

  if (status != null && statText != null) {
    return '$status · $statText';
  }
  return status ?? statText;
}
