// ignore_for_file: avoid_print

import 'package:zakoni/core/network/bangumi_client.dart';

void main() async {
  print('🚀 正在请求 Bangumi 官方 API (https://api.bgm.tv/calendar) ...\n');
  final client = BangumiClient();

  try {
    final calendar = await client.getCalendar();
    print('✅ 成功获取每日放送数据！共 ${calendar.length} 天：\n');

    for (final day in calendar) {
      print('📅 【${day.weekday.cn} (${day.weekday.ja})】 今日放送 ${day.items.length} 部番剧：');
      for (final item in day.items.take(3)) {
        final score = item.ratingScore > 0 ? '${item.ratingScore}分' : '暂无评分';
        print('   - [${item.id}] ${item.preferredName} ($score)');
      }
      if (day.items.length > 3) {
        print('     ... 还有 ${day.items.length - 3} 部番剧\n');
      } else {
        print('');
      }
    }

    // 再测试一条具体条目的详情
    print('🔍 正在测试单条目详情拉取 (ID: 253)...');
    final subject = await client.getSubject(253);
    print('✅ 条目获取成功: 《${subject.preferredName}》');
    print('   原名: ${subject.name}');
    print('   评分: ${subject.ratingScore} (${subject.votes} 人评价)');
    print('   封面: ${subject.coverUrl}');
    print('   简介: ${subject.summary.replaceAll('\n', ' ').substring(0, subject.summary.length > 60 ? 60 : subject.summary.length)}...\n');

    print('🎉 全部真实接口连通测试通过！');
  } catch (e) {
    print('❌ 请求异常: $e');
  }
}
