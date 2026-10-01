import '../../utils/html_utils.dart';
import 'bangumi_user.dart';

class BangumiComment {
  final BangumiUser user;
  final int rate;
  final String comment;
  final String updatedAt;

  const BangumiComment({
    required this.user,
    required this.rate,
    required this.comment,
    required this.updatedAt,
  });

  factory BangumiComment.fromJson(Map<String, dynamic> json) {
    final userJson = (json['user'] as Map<String, dynamic>?) ?? {};
    final rawRate = json['rate'];
    final rate = (rawRate is num) ? rawRate.toInt() : (int.tryParse('$rawRate') ?? 0);

    return BangumiComment(
      user: BangumiUser.fromJson(userJson),
      rate: rate,
      comment: decodeHtmlEntities(json['comment']?.toString() ?? ''),
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'rate': rate,
        'comment': comment,
        'updated_at': updatedAt,
      };
}
