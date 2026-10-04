/// Animaku / Bangumi 经典分类常量与辅助计算工具
class CategoryConstants {
  CategoryConstants._();

  static const mediaTypes = [
    'TV',
    '剧场版',
    'OVA',
  ];

  static const genres = [
    '热血',
    '奇幻',
    '战斗',
    '校园',
    '日常',
    '治愈',
    '科幻',
    '悬疑',
    '恋爱',
    '搞笑',
    '异世界',
    '机战',
    '音乐',
    '运动',
    '偶像',
    '冒险',
    '百合',
    '后宫',
    '致郁',
    '催泪',
  ];

  static const popularTags = [
    '全部',
    'TV',
    '剧场版',
    'OVA',
    '热血',
    '奇幻',
    '战斗',
    '校园',
    '日常',
    '治愈',
    '科幻',
    '悬疑',
    '恋爱',
    '搞笑',
    '异世界',
    '机战',
    '音乐',
    '运动',
    '偶像',
    '冒险',
    '百合',
    '后宫',
    '致郁',
    '催泪',
  ];

  static const sortOptions = [
    (key: 'heat', label: '热度'),
    (key: 'score', label: '评分'),
    (key: 'date', label: '时间'),
  ];

  // 季度简明标签：精简为 图标 + 月份，适配所有手机屏幕宽度，绝不溢出换行
  static const seasons = [
    (month: 0, label: '全部'),
    (month: 1, label: '❄️ 1月'),
    (month: 4, label: '🌸 4月'),
    (month: 7, label: '☀️ 7月'),
    (month: 10, label: '🍁 10月'),
  ];

  /// 分页拉取基准尺寸：
  static const int defaultMobilePageSize = 12;
  static const int defaultTabletPageSize = 20;
  static const int defaultDesktopPageSize = 24;

  /// 基础回退分页尺寸（手机端 12 部）
  static const int pageSize = defaultMobilePageSize;

  static int get currentYear => DateTime.now().year;

  /// 计算当前现实播放季度的起始月份 (1/4/7/10)
  static int get currentSeasonMonth {
    final m = DateTime.now().month;
    if (m <= 3) return 1;
    if (m <= 6) return 4;
    if (m <= 9) return 7;
    return 10;
  }

  /// 季度名称简写
  static String seasonShortName(int month) {
    switch (month) {
      case 1:
        return '冬季番';
      case 4:
        return '春季番';
      case 7:
        return '夏季番';
      case 10:
        return '秋季番';
      default:
        return '全年';
    }
  }

  /// 构造 Bangumi 规范的季度放送日期连续区间表达式 (例如 4月季为 >=YYYY-04-01 到 <YYYY-07-01)
  static List<String> seasonAirDate(int year, int month) {
    switch (month) {
      case 1:
        return ['>=$year-01-01', '<$year-04-01'];
      case 4:
        return ['>=$year-04-01', '<$year-07-01'];
      case 7:
        return ['>=$year-07-01', '<$year-10-01'];
      case 10:
        return ['>=$year-10-01', '<${year + 1}-01-01'];
      default:
        return ['>=$year-01-01', '<=$year-12-31'];
    }
  }
}
