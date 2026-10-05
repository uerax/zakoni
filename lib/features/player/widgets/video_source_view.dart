import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

/// 默认从 SourceBundleManager 生成的 11 个标准视频源
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
    'girigiri': '爱动漫',
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

/// iOS 现代化视频源选择看板 (Apple Inset Grouped & Vibrancy Style)
class VideoSourceView extends StatelessWidget {
  const VideoSourceView({
    super.key,
    required this.sources,
    required this.selectedSourceId,
    required this.onSourceSelected,
    this.aggregator,
    this.hintMessage,
  });

  final List<VideoSourceItem> sources;
  final String selectedSourceId;
  final ValueChanged<VideoSourceItem> onSourceSelected;
  final SourceAggregator? aggregator;
  final String? hintMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final bundleMeta = SourceBundleManager.instance.meta;

    final effectiveSources = sources.isEmpty ? getDefaultSourceItems() : sources;

    final currentSource = effectiveSources.firstWhere(
      (s) => s.id == selectedSourceId,
      orElse: () => effectiveSources.first,
    );

    final probeStates = aggregator?.items ?? const <AggregatedSourceState>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // 1. 顶部提示条 (当默认源未命中时给出优雅的 iOS 磨砂胶囊提示)
        if (hintMessage != null)
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
                    hintMessage!,
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

        // 2. 当前正在生效的视频源高亮卡片 (iOS Highlighted Card)
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
                      '当前视频源：${currentSource.name}',
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

        // 3. 标题与状态栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  '可用视频源列表',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (aggregator?.isProbing == true) ...[
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
            if (bundleMeta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v${bundleMeta.version}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // 4. iOS Inset Grouped 视频源列表
        ...effectiveSources.map((src) {
          final isSelected = src.id == selectedSourceId;

          // 获取该源的探测状态
          final probe = probeStates.cast<AggregatedSourceState?>().firstWhere(
                (p) => p?.meta.id == src.id,
                orElse: () => null,
              );

          Widget statusBadge;
          if (probe != null) {
            switch (probe.status) {
              case SourceProbeStatus.probing:
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 8, height: 8, child: CupertinoActivityIndicator(radius: 4)),
                      SizedBox(width: 4),
                      Text('探测中', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
                break;
              case SourceProbeStatus.ready:
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.green, size: 12),
                      SizedBox(width: 2),
                      Text('已命中', style: TextStyle(fontSize: 10.5, color: Colors.green, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
                break;
              case SourceProbeStatus.empty:
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '未收录',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                );
                break;
              case SourceProbeStatus.error:
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('异常', style: TextStyle(fontSize: 10.5, color: Colors.red)),
                );
                break;
              case SourceProbeStatus.idle:
                statusBadge = const SizedBox.shrink();
                break;
            }
          } else {
            statusBadge = const SizedBox.shrink();
          }

          final subtitle = probe?.matchedHit?.name != null
              ? '命中资源: ${probe!.matchedHit!.name}'
              : src.description;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: BouncingScaleCard(
              scaleDown: 0.97,
              onTap: () => onSourceSelected(src),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: isDark ? 0.18 : 0.1)
                      : (isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(7)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.5)
                        : (isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12)),
                    width: isSelected ? 1.2 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: 0.25)
                            : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.smart_display_outlined,
                        color: isSelected ? primaryColor : theme.textTheme.bodySmall?.color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.textTheme.bodySmall?.color,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    statusBadge,
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
