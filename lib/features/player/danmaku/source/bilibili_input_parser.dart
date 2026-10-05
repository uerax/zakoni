/// Bilibili 输入标识类型
enum BilibiliTargetType {
  /// 番剧单集 (ep86012)
  ep,

  /// 番剧季度 (ss28277)
  ss,

  /// 媒体详情 (md28229015)
  md,

  /// Bangumi.tv 关联 ID (bgm1728)
  bgm,

  /// UGC 视频 BV 号 (BV1TT4y1g77n)
  bv,

  /// 经典 AV 号 (av925796497)
  av,

  /// b23.tv 短链 (https://b23.tv/xxx)
  b23,
}

/// 结构化 Bilibili 目标对象 (1:1 对齐 animaku BilibiliTarget)
class BilibiliTarget {
  const BilibiliTarget({
    required this.type,
    required this.raw,
    this.epId,
    this.seasonId,
    this.mediaId,
    this.bangumiId,
    this.bvid,
    this.aid,
    this.url,
    this.page,
  });

  final BilibiliTargetType type;
  final String raw;
  final int? epId;
  final int? seasonId;
  final int? mediaId;
  final int? bangumiId;
  final String? bvid;
  final int? aid;
  final String? url;
  final int? page;

  BilibiliTarget copyWith({
    BilibiliTargetType? type,
    String? raw,
    int? epId,
    int? seasonId,
    int? mediaId,
    int? bangumiId,
    String? bvid,
    int? aid,
    String? url,
    int? page,
  }) {
    return BilibiliTarget(
      type: type ?? this.type,
      raw: raw ?? this.raw,
      epId: epId ?? this.epId,
      seasonId: seasonId ?? this.seasonId,
      mediaId: mediaId ?? this.mediaId,
      bangumiId: bangumiId ?? this.bangumiId,
      bvid: bvid ?? this.bvid,
      aid: aid ?? this.aid,
      url: url ?? this.url,
      page: page ?? this.page,
    );
  }
}

/// Bilibili 各种链接与标识语法解析器 (1:1 对齐 animaku parseBilibiliInput)
class BilibiliInputParser {
  BilibiliInputParser._();

  static final RegExp _pageRegex = RegExp(r'[?&](?:p|page)=(\d+)', caseSensitive: false);
  static final RegExp _epRegex = RegExp(r'(?:^|/|[?&]ep_id=|\b)ep(\d+)', caseSensitive: false);
  static final RegExp _ssRegex = RegExp(r'(?:^|/|[?&]season_id=|\b)ss(\d+)', caseSensitive: false);
  static final RegExp _mdRegex = RegExp(r'(?:^|/|[?&]media_id=|\b)md(\d+)', caseSensitive: false);
  static final RegExp _bgmRegex = RegExp(r'(?:^|/|[?&](?:bgm_id|bgm|bangumi_id)=|\b)bgm(\d+)|bangumi\.tv/subject/(\d+)', caseSensitive: false);
  static final RegExp _bvRegex = RegExp(r'BV[0-9A-Za-z]+', caseSensitive: false);
  static final RegExp _avRegex = RegExp(r'(?:^|/|[?&]aid=|\b)av(\d+)', caseSensitive: false);
  static final RegExp _b23Regex = RegExp(r'(?:https?://)?(?:www\.)?b23\.tv/([A-Za-z0-9_-]+)', caseSensitive: false);

  /// 解析各类 B 站链接与 ID 输入格式：
  /// - 番剧单集: https://www.bilibili.com/bangumi/play/ep86012, ep86012, ep_id=86012
  /// - 番剧季度: https://www.bilibili.com/bangumi/play/ss28277, ss28277, season_id=28277
  /// - 媒体详情: https://www.bilibili.com/bangumi/media/md28229015, md28229015
  /// - Bangumi ID: bgm1728, /subject/1728
  /// - UGC BV 视频: https://www.bilibili.com/video/BV1TT4y1g77n, BV1TT4y1g77n
  /// - UGC AV 视频: https://www.bilibili.com/video/av925796497, av925796497, aid=925796497
  /// - b23.tv 短链: https://b23.tv/ep86012, https://b23.tv/BV1xx, https://b23.tv/XyZ123
  /// 自动提取 ?p=N 或 &p=N 分页参数。
  static BilibiliTarget? parse(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;

    // 1. 提取可选的分P参数 (?p=2, ?page=2, &p=2)
    int? page;
    final pageMatch = _pageRegex.firstMatch(s);
    if (pageMatch != null) {
      final p = int.tryParse(pageMatch.group(1) ?? '');
      if (p != null && p > 0) page = p;
    }

    // 2. Generic b23.tv 短链 (优先于 BV/ep 匹配，因为短链必须通过 Location 重定向解析真实终点)
    final b23Match = _b23Regex.firstMatch(s);
    if (b23Match != null) {
      final fullUrl = s.startsWith('http') ? s : 'https://$s';
      return BilibiliTarget(
        type: BilibiliTargetType.b23,
        url: fullUrl,
        page: page,
        raw: s,
      );
    }

    // 3. Bangumi Episode (ep86012)
    final epMatch = _epRegex.firstMatch(s);
    if (epMatch != null) {
      final id = int.tryParse(epMatch.group(1) ?? '');
      if (id != null) {
        return BilibiliTarget(
          type: BilibiliTargetType.ep,
          epId: id,
          page: page,
          raw: s,
        );
      }
    }

    // 3. Bangumi Season (ss28277)
    final ssMatch = _ssRegex.firstMatch(s);
    if (ssMatch != null) {
      final id = int.tryParse(ssMatch.group(1) ?? '');
      if (id != null) {
        return BilibiliTarget(
          type: BilibiliTargetType.ss,
          seasonId: id,
          page: page,
          raw: s,
        );
      }
    }

    // 4. Bangumi Media (md28229015)
    final mdMatch = _mdRegex.firstMatch(s);
    if (mdMatch != null) {
      final id = int.tryParse(mdMatch.group(1) ?? '');
      if (id != null) {
        return BilibiliTarget(
          type: BilibiliTargetType.md,
          mediaId: id,
          page: page,
          raw: s,
        );
      }
    }

    // 5. Bangumi.tv Subject (bgm1728)
    final bgmMatch = _bgmRegex.firstMatch(s);
    if (bgmMatch != null) {
      final idStr = bgmMatch.group(1) ?? bgmMatch.group(2) ?? '';
      final id = int.tryParse(idStr);
      if (id != null) {
        return BilibiliTarget(
          type: BilibiliTargetType.bgm,
          bangumiId: id,
          page: page,
          raw: s,
        );
      }
    }

    // 6. Standard BV (BV1TT4y1g77n)
    final bvMatch = _bvRegex.firstMatch(s);
    if (bvMatch != null) {
      return BilibiliTarget(
        type: BilibiliTargetType.bv,
        bvid: bvMatch.group(0),
        page: page,
        raw: s,
      );
    }

    // 6. Classic AV / AID (av925796497)
    final avMatch = _avRegex.firstMatch(s);
    if (avMatch != null) {
      final id = int.tryParse(avMatch.group(1) ?? '');
      if (id != null) {
        return BilibiliTarget(
          type: BilibiliTargetType.av,
          aid: id,
          page: page,
          raw: s,
        );
      }
    }

    return null;
  }

  /// 从输入文本中提取 BV 号
  static String? extractBvid(String input) {
    final target = parse(input);
    if (target?.type == BilibiliTargetType.bv) return target?.bvid;
    final m = _bvRegex.firstMatch(input);
    return m?.group(0);
  }
}
