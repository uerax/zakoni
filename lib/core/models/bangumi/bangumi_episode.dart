import '../../utils/html_utils.dart';

class BangumiEpisode {
  final int id;
  final int type; // 0=正片, 1=SP, 2=OP, 3=ED
  final double sort;
  final String name;
  final String nameCn;
  final String airdate;
  final double? ep;
  final int durationSeconds;

  const BangumiEpisode({
    required this.id,
    required this.type,
    required this.sort,
    required this.name,
    required this.nameCn,
    required this.airdate,
    this.ep,
    this.durationSeconds = 0,
  });

  /// 优先展示中文标题，若为空降级为原名；若仍为空则展示 "第 X 话"
  String get displayTitle {
    if (nameCn.isNotEmpty) return nameCn;
    if (name.isNotEmpty) return name;
    final epNum = ep ?? sort;
    return epNum > 0 ? '第 $epNum 话' : '第 $id 话';
  }

  /// 话数标签 (例如 "01" 或 "12.5" 或 "SP01")
  String get episodeLabel {
    final epNum = ep ?? sort;
    final isInt = epNum == epNum.roundToDouble();
    final numStr = isInt ? epNum.toInt().toString().padLeft(2, '0') : epNum.toString();
    if (type == 1) return 'SP$numStr';
    return numStr;
  }

  factory BangumiEpisode.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] is num ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0;
    final typeVal = json['type'] is num ? (json['type'] as num).toInt() : int.tryParse('${json['type']}') ?? 0;

    final rawSort = json['sort'];
    final sort = rawSort is num ? rawSort.toDouble() : double.tryParse('$rawSort') ?? 0.0;

    final rawEp = json['ep'];
    final ep = rawEp is num ? rawEp.toDouble() : (rawEp != null ? double.tryParse('$rawEp') : null);

    final rawDurationSec = json['duration_seconds'];
    int durationSec = 0;
    if (rawDurationSec is num) {
      durationSec = rawDurationSec.toInt();
    } else if (json['duration'] is String) {
      durationSec = parseDurationSeconds(json['duration'] as String);
    }

    return BangumiEpisode(
      id: idVal,
      type: typeVal,
      sort: sort,
      name: decodeHtmlEntities(json['name']?.toString() ?? ''),
      nameCn: decodeHtmlEntities((json['name_cn'] ?? json['nameCN'] ?? '').toString()),
      airdate: (json['airdate'] ?? json['air_date'] ?? '').toString(),
      ep: ep,
      durationSeconds: durationSec,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'sort': sort,
        'name': name,
        'name_cn': nameCn,
        'airdate': airdate,
        'ep': ep,
        'duration_seconds': durationSeconds,
      };
}

/// 解析类似 "00:24:00" 或 "24:00" 的时间字符串为秒数
int parseDurationSeconds(String str) {
  final parts = str.trim().split(':');
  if (parts.length == 3) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = int.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  } else if (parts.length == 2) {
    final m = int.tryParse(parts[0]) ?? 0;
    final s = int.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }
  return 0;
}
