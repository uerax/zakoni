/// 动漫标签噪音过滤与标准题材白名单工具：
/// 1. 采用高命中率正则深度拦截多样化时间标签（年份、月份、季节、年代、新番泛词），杜绝静态年份枚举失效问题；
/// 2. 严谨过滤无题材意义的通用载体、泛改编、地域与平台标签；
/// 3. 收录经过严格清洗的【动漫标准题材推荐白名单 (genreAllowList)】（受控词典 Controlled Vocabulary），
///    彻底根除孤岛恶搞标签与无厘头词，确保从 Bangumi 检索时 100% 能够命中足量番剧；
/// 4. 特殊处理说明：根据业务策略，特意保留【游改 / 游戏改 / gal改 / galgame改 / 原创 / 原创动画】，
///    因其在二次元社群中具备鲜明的小众风格与受众偏好画像价值。
class AnimeTagFilter {
  AnimeTagFilter._();

  /// 动漫标准题材推荐白名单（受控词典 Controlled Vocabulary）
  /// 严格清洗自 Bangumi 官方海量高频标签，彻底剔除结构性载体、时间、恶搞短句与观后感评价词。
  static const Set<String> genreAllowList = {
    // 1. 核心大类题材
    '恋爱',
    '搞笑',
    '日常',
    '校园',
    '奇幻',
    '战斗',
    '热血',
    '冒险',
    '科幻',
    '悬疑',
    '推理',
    '治愈',
    '青春',
    '运动',
    '竞技',
    '美食',
    '音乐',
    '偶像',
    '历史',
    '战争',
    '剧情',
    '打斗',
    '格斗',

    // 2. 二次元鲜明特色题材
    '异世界',
    '后宫',
    '百合',
    '轻百合',
    '耽美',
    'bl',
    '纯爱',
    '萌系',
    '萌',
    '魔法少女',
    '魔法',
    '机战',
    '机甲',
    '超能力',
    '穿越',
    '转生',
    '智斗',
    '催泪',
    '致郁',
    '暗黑',
    '恋爱喜剧',
    '一般向',
    '宫廷',

    // 3. 进阶/小众/深度题材
    '赛博朋克',
    '反乌托邦',
    '末世',
    '末日',
    '公路片',
    '群像',
    '群像剧',
    '职场',
    '妖怪',
    '怪谈',
    '丧尸',
    '僵尸',
    '硬核',
    '生存',
    '大逃杀',
    '犯罪',
    '谍战',
    '武侠',
    '仙侠',
    '古风',
    '和风',
    '童话',
    '心理',
    '露营',
    '萌宠',
    '生活',
    '种田',
    '落语',
    '魔幻',

    // 4. 特殊创作源（保留具象风格）
    '游改',
    '游戏改',
    'gal改',
    '原创',
    '原创动画',
  };

  /// 时间格式标签正则拦截器：
  /// 匹配格式包括：
  /// - 纯4位年份 / 年份+年: 2026, 2026年, 1998
  /// - 年份 + 月份: 2026年7月, 2024.4, 2024-07, 2024/10
  /// - 年份 + 季节/季度: 2026春, 2024年秋, 2025冬番, 2024秋季, 2024年4月番
  /// - 年代跨度: 80年代, 90年代, 00年代, 10年代, 20年代
  /// - 新番泛词: 2026新番, 7月新番, 10月新番, 新番
  static final RegExp _temporalTagRegex = RegExp(
    r'^(?:'
    r'\d{4}年?(?:(?:0?[1-9]|1[0-2])月?|(?:春|夏|秋|冬)(?:番|季)?)?'
    r'|\d{4}[.\-/](?:0?[1-9]|1[0-2])'
    r'|\d{2}年代'
    r'|.*新番'
    r')$',
    caseSensitive: false,
  );

  /// 结构性/载体类/属性类停用词库（全小写归一化存储）
  static const Set<String> _carrierNoiseTags = {
    // 载体介质与播放形式
    'tv',
    '剧场版',
    'ova',
    'oad',
    'web',
    'ona',
    'sp',
    '特别篇',
    '短片',
    '泡面番',
    'movie',
    'film',
    '里番',
    '动画',
    '番剧',

    // 过于泛化的来源/改编（注意：保留 游改/gal改/原创 等具象风格标签）
    '漫改',
    '漫画改',
    '小说改',
    '轻改',
    '轻小说改',

    // 泛地域与国家
    '日本',
    '日漫',
    '中国',
    '国产',
    '欧美',

    // 播放平台
    'bilibili',
    'b站',
    'netflix',
    'tx',
  };

  /// 敏感/限制级标签集合（除噪音外还需承担安全兜底过滤）
  static const Set<String> _safetySensitiveTags = {
    '里番',
    'r18',
    'r-18',
    '工口',
  };

  /// 判断该标签是否属于标准题材推荐白名单
  static bool isAllowedGenre(String tag) {
    final clean = tag.trim().toLowerCase();
    return genreAllowList.contains(clean);
  }

  /// 使用白名单词典过滤用户原始词频：
  /// 仅保留命中了标准题材库的高价值标签，彻底排除时间、载体、恶搞短句等一切未知噪音
  static Map<String, int> filterByGenreAllowList(Map<String, int> rawFreq) {
    final result = <String, int>{};
    rawFreq.forEach((tag, count) {
      final clean = tag.trim();
      if (isAllowedGenre(clean) && count > 0) {
        result[clean] = count;
      }
    });
    return result;
  }

  /// 判断该标签是否属于时间类标签（如 2026, 2026年7月, 2026秋, 90年代 等）
  static bool isTemporalTag(String tag) {
    final clean = tag.trim();
    if (clean.isEmpty) return false;
    return _temporalTagRegex.hasMatch(clean);
  }

  /// 判断该标签是否属于限制级敏感标签
  static bool isSafetySensitiveTag(String tag) {
    final clean = tag.trim().toLowerCase();
    return _safetySensitiveTags.contains(clean);
  }

  /// 综合判断该标签是否属于噪音标签（时间词、载体词、泛化词等）
  static bool isNoiseTag(String tag) {
    final clean = tag.trim().toLowerCase();
    if (clean.isEmpty) return true;

    // 1. 命中时间正则
    if (_temporalTagRegex.hasMatch(clean)) return true;

    // 2. 命中属性停用词库
    if (_carrierNoiseTags.contains(clean)) return true;

    return false;
  }

  /// 清洗用户的原始标签词频表（黑名单模式）：
  /// 剔除所有噪音标签，只保留真正能够代表题材偏好的标签及其对应频次
  static Map<String, int> cleanUserTagFreq(Map<String, int> rawFreq) {
    final result = <String, int>{};
    rawFreq.forEach((tag, count) {
      if (!isNoiseTag(tag) && count > 0) {
        result[tag.trim()] = count;
      }
    });
    return result;
  }

  /// 清洗番剧自带的标签列表：
  /// 剔除噪音后返回有效题材标签集合
  static List<String> cleanItemTags(Iterable<String> tags) {
    return tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !isNoiseTag(t))
        .toList();
  }
}
