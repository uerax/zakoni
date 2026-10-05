import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:zakoni/features/player/source/models/source_models.dart';
import 'package:zakoni/features/player/source/source_aggregator.dart';
import 'package:zakoni/features/player/source/source_bundle_manager.dart';
import '../../common/widgets/bouncing_scale_card.dart';

/// 视频源实体项
class VideoSourceItem {
  final String id;
  final String name;
  final String description;
  final String statusText;
  final bool isReady;
  final bool isDefault;

  const VideoSourceItem({
    required this.id,
    required this.name,
    required this.description,
    this.statusText = '已就绪',
    this.isReady = true,
    this.isDefault = false,
  });
}

/// 默认从 SourceBundleManager 生成的标准视频源列表
List<VideoSourceItem> getDefaultSourceItems() {
  const descriptions = {
    'xifan-next': '1080P · 官方推荐综合主线',
    'girigiri': '1080P · Cloudflare CDN 原画直连',
    'mifun': '1080P · 字节/百度 CDN 高速切片',
    'cycani': '1080P · 纯净 REST API 多线路',
    'moonci': '1080P · 零 Referer 防盗链直连',
    'tvtfun': '1080P · 国内直连线路 D 优先',
    'lzizy': 'HLS · 全品类影视 0ms 纯直链',
    'animoe': 'HLS · 网易云音乐 CDN 节点',
    'mxdm': 'HLS · 备用多线路模板解析',
    'omofun': '1080P · 备用解析线路',
    'anime1': 'MP4 · 动画全集带鉴权直连',
    'libvio': '1080P · 动态发布页实时探活镜像',
  };

  const sourceNames = {
    'xifan-next': '稀饭Next',
    'girigiri': 'girigiri',
    'mifun': 'MiFun',
    'cycani': '次元城',
    'moonci': '月之祠',
    'tvtfun': 'TvTFun',
    'lzizy': '量子资源',
    'animoe': 'Animoe',
    'mxdm': 'MX动漫',
    'omofun': 'OmoFun',
    'anime1': 'Anime1',
    'libvio': 'LIBVIO',
  };

  final dynamicSources = SourceBundleManager.instance.sources;
  if (dynamicSources.isEmpty) {
    return descriptions.entries.map((e) {
      return VideoSourceItem(
        id: e.key,
        name: sourceNames[e.key] ?? e.key,
        description: e.value,
        isDefault: e.key == 'xifan-next',
      );
    }).toList();
  }

  return dynamicSources.map((s) {
    return VideoSourceItem(
      id: s.id,
      name: s.name,
      description: descriptions[s.id] ?? 'v${s.version} · 动态解析',
      isDefault: s.id == 'xifan-next',
    );
  }).toList();
}

typedef SourceHitSelectCallback = void Function(
  VideoSourceItem src,
  SourceSearchResult hit, [
  List<SourceChapterRoad>? cachedRoads,
]);

/// iOS 现代化视频源看板 (1:1 严格对齐 animaku SourceBoard 交互与视觉设计)
class VideoSourceView extends StatefulWidget {
  const VideoSourceView({
    super.key,
    required this.sources,
    required this.selectedSourceId,
    required this.onSourceSelected,
    this.onSelectHit,
    this.aggregator,
    this.hintMessage,
    this.keywordOptions = const [],
    this.onUserAction,
    this.currentEpisodeNumber,
  });

  final List<VideoSourceItem> sources;
  final String selectedSourceId;
  final ValueChanged<VideoSourceItem> onSourceSelected;
  final SourceHitSelectCallback? onSelectHit;
  final SourceAggregator? aggregator;
  final String? hintMessage;
  final List<String> keywordOptions;
  final VoidCallback? onUserAction;
  final int? currentEpisodeNumber;

  @override
  State<VideoSourceView> createState() => _VideoSourceViewState();
}

class _VideoSourceViewState extends State<VideoSourceView> {
  String? _expandedSourceId;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String sourceId) {
    return _controllers.putIfAbsent(sourceId, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final effectiveSources = widget.sources.isEmpty ? getDefaultSourceItems() : widget.sources;

    final currentSource = effectiveSources.firstWhere(
      (s) => s.id == widget.selectedSourceId,
      orElse: () => effectiveSources.first,
    );

    final probeStates = widget.aggregator?.states ?? const <String, AggregatedSourceState>{};
    final totalCount = effectiveSources.length;
    final readyCount = probeStates.values.where((s) => s.status == SourceProbeStatus.ready).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 1. 顶部提示条 (默认源未搜到或全灭时的醒目提示)
        if (widget.hintMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.28),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.hintMessage!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.amber,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 2. 当前正在生效的视频源高亮卡片
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.live_tv_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前视频源：${currentSource.name}${widget.currentEpisodeNumber != null ? " · 第 ${widget.currentEpisodeNumber} 话" : ""}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentSource.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.textTheme.bodySmall?.color,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                    SizedBox(width: 4),
                    Text(
                      '当前生效',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 3. 标题与状态栏 (展示 X/Y 就绪数)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '视频源列表',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '($readyCount/$totalCount 就绪)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.normal,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                if (widget.aggregator?.isAutoProbing == true) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CupertinoActivityIndicator(radius: 6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '并发探测中...',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4. 视频源卡片列表 (含可展开抽屉 Drawer)
        ...effectiveSources.map((src) {
          final isSelected = src.id == widget.selectedSourceId;
          final state = probeStates[src.id] ??
              AggregatedSourceState(
                meta: SourceMeta(id: src.id, name: src.name, version: '1.0.0'),
                status: SourceProbeStatus.idle,
              );

          final isExpanded = _expandedSourceId == src.id;
          final matchedTitle = state.matchedHit?.name ?? state.binding?.title ?? '';

          // 状态徽标与药丸按钮文本
          Widget statusDot;
          Widget pillButton;

          switch (state.status) {
            case SourceProbeStatus.probing:
              statusDot = Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              );
              pillButton = _buildPill(
                label: '探活中',
                color: primaryColor,
                isLoading: true,
                onTap: null,
              );
              break;

            case SourceProbeStatus.ready:
              statusDot = Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              );
              pillButton = _buildPill(
                label: isSelected ? '当前' : '切换',
                color: isSelected ? primaryColor : Colors.green,
                isFilled: isSelected,
                onTap: () {
                  widget.onUserAction?.call();
                  if (isSelected) {
                    setState(() {
                      _expandedSourceId = isExpanded ? null : src.id;
                    });
                  } else if (state.matchedHit != null) {
                    widget.onSelectHit != null
                        ? widget.onSelectHit!(src, state.matchedHit!, state.roads)
                        : widget.onSourceSelected(src);
                  }
                },
              );
              break;

            case SourceProbeStatus.needsPick:
              statusDot = Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              );
              pillButton = _buildPill(
                label: '选条目',
                color: Colors.amber,
                onTap: () {
                  widget.onUserAction?.call();
                  setState(() {
                    _expandedSourceId = isExpanded ? null : src.id;
                  });
                },
              );
              break;

            case SourceProbeStatus.empty:
            case SourceProbeStatus.error:
              statusDot = Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              );
              pillButton = _buildPill(
                label: '换词',
                color: Colors.redAccent,
                onTap: () {
                  widget.onUserAction?.call();
                  setState(() {
                    _expandedSourceId = isExpanded ? null : src.id;
                  });
                },
              );
              break;

            case SourceProbeStatus.idle:
              statusDot = Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.disabledColor,
                  shape: BoxShape.circle,
                ),
              );
              pillButton = _buildPill(
                label: '探活',
                color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                onTap: () {
                  widget.onUserAction?.call();
                  widget.aggregator?.prioritizeSource(src.id, isUserAction: true);
                },
              );
              break;
          }

          // 副标题提示文字
          String statusDescription;
          Color statusDescriptionColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

          if (state.status == SourceProbeStatus.probing) {
            statusDescription = '探活检索中...';
            statusDescriptionColor = primaryColor;
          } else if (state.status == SourceProbeStatus.ready) {
            statusDescription = matchedTitle.isNotEmpty ? matchedTitle : '已命中番剧条目';
            statusDescriptionColor = isSelected ? primaryColor : Colors.green;
          } else if (state.status == SourceProbeStatus.needsPick) {
            statusDescription = '搜到 ${state.items.length} 条候选 (点击展开选条目)';
            statusDescriptionColor = Colors.amber;
          } else if (state.status == SourceProbeStatus.empty) {
            statusDescription = '未搜到结果 (点击展开换词)';
          } else if (state.status == SourceProbeStatus.error) {
            statusDescription = state.errorMsg ?? '请求异常 (点击换词)';
            statusDescriptionColor = Colors.redAccent;
          } else {
            statusDescription = '待探活 (点击探活)';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withValues(alpha: isDark ? 0.16 : 0.08)
                  : (isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(7)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.5)
                    : (isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12)),
                width: isSelected ? 1.2 : 0.5,
              ),
            ),
            child: Column(
              children: [
                // 卡片主行
                BouncingScaleCard(
                  scaleDown: 0.98,
                  onTap: () {
                    widget.onUserAction?.call();
                    widget.aggregator?.prioritizeSource(src.id, isUserAction: true);
                    if (isSelected) {
                      setState(() {
                        _expandedSourceId = isExpanded ? null : src.id;
                      });
                      return;
                    }

                    if (state.status == SourceProbeStatus.ready && state.matchedHit != null) {
                      // 仅绿色状态才切源跳转至选集 Tab
                      widget.onSelectHit != null
                          ? widget.onSelectHit!(src, state.matchedHit!, state.roads)
                          : widget.onSourceSelected(src);
                    } else if (state.status == SourceProbeStatus.idle) {
                      // 待探活状态：点击立即发起插队探活，留在当前页面，绝不跳转选集！
                      widget.aggregator?.prioritizeSource(src.id, isUserAction: true);
                    } else {
                      // 探活中、需选条目、未收录、异常报错：点击仅展开或收起抽屉，绝不跳转选集！
                      setState(() {
                        _expandedSourceId = isExpanded ? null : src.id;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // 首字母头像 + 状态指示灯
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (src.name.isNotEmpty ? src.name[0] : '?').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: statusDot,
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // 视频源名称与命中条目
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    src.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: isSelected ? primaryColor : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  if (src.isDefault) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '默认',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                statusDescription,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: statusDescriptionColor,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        pillButton,
                      ],
                    ),
                  ),
                ),

                // 抽屉展开区域 (Expandable Drawer)
                if (isExpanded)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withAlpha(25) : Colors.white.withAlpha(120),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A: 探测中状态条
                        if (state.status == SourceProbeStatus.probing) ...[
                          Row(
                            children: [
                              const CupertinoActivityIndicator(radius: 6),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '正在使用「${state.keyword ?? "关键词"}」检索 ${src.name}...',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],

                        // B: 候选条目列表 (供用户点选绑定)
                        if (state.items.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                state.status == SourceProbeStatus.needsPick
                                    ? '请点选匹配的番剧条目以绑定：'
                                    : '搜到 ${state.items.length} 条候选条目：',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: state.status == SourceProbeStatus.needsPick
                                      ? Colors.amber
                                      : theme.textTheme.bodySmall?.color,
                                ),
                              ),
                              if (state.keyword != null)
                                Text(
                                  '搜索词: ${state.keyword}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.disabledColor,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: state.items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 4),
                              itemBuilder: (context, idx) {
                                final hit = state.items[idx];
                                final isHitActive = isSelected && state.matchedHit?.url == hit.url;
                                return InkWell(
                                  onTap: () {
                                    widget.onUserAction?.call();
                                    widget.onSelectHit != null
                                        ? widget.onSelectHit!(src, hit, isHitActive ? state.roads : const [])
                                        : widget.onSourceSelected(src);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isHitActive
                                          ? primaryColor.withValues(alpha: 0.16)
                                          : (isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(4)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isHitActive
                                            ? primaryColor.withValues(alpha: 0.5)
                                            : Colors.transparent,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            hit.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isHitActive ? FontWeight.w600 : FontWeight.normal,
                                              color: isHitActive ? primaryColor : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isHitActive ? primaryColor : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8)),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isHitActive ? '在播' : '选用',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isHitActive ? Colors.white : theme.textTheme.bodySmall?.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // C: 候选关键词变体胶囊 (最多 8 个)
                        if (widget.keywordOptions.isNotEmpty) ...[
                          Text(
                            '推荐候选关键词：',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: widget.keywordOptions.take(8).map((kw) {
                              final isCurrentKw = state.keyword == kw;
                              return InkWell(
                                onTap: () {
                                  widget.onUserAction?.call();
                                  _getController(src.id).text = kw;
                                  widget.aggregator?.reProbeSource(src.id, kw);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCurrentKw
                                        ? primaryColor.withValues(alpha: 0.16)
                                        : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5)),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCurrentKw ? primaryColor : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10)),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        kw,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isCurrentKw ? primaryColor : theme.colorScheme.onSurface,
                                          fontWeight: isCurrentKw ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.search_rounded,
                                        size: 11,
                                        color: isCurrentKw ? primaryColor : theme.disabledColor,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // D: 自定义关键词手动输入框
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: TextField(
                                  controller: _getController(src.id),
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: '输入针对 ${src.name} 的关键词...',
                                    hintStyle: TextStyle(fontSize: 11, color: theme.disabledColor),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      widget.onUserAction?.call();
                                      widget.aggregator?.reProbeSource(src.id, val.trim());
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: () {
                                  final val = _getController(src.id).text.trim();
                                  if (val.isNotEmpty) {
                                    widget.onUserAction?.call();
                                    widget.aggregator?.reProbeSource(src.id, val);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('重搜', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPill({
    required String label,
    required Color color,
    bool isFilled = false,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isFilled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: isFilled ? 1.0 : 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 8,
                height: 8,
                child: CupertinoActivityIndicator(radius: 4, color: color),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isFilled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
