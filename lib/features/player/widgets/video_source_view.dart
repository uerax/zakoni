import 'package:flutter/material.dart';
import 'package:zakoni/features/player/source/source_aggregator.dart';
import 'package:zakoni/features/player/source/source_bundle_manager.dart';

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

/// 参考 animaku SourceBoard 的视频源选择 Tab 组件
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
    final bundleMeta = SourceBundleManager.instance.meta;

    final effectiveSources = sources.isEmpty ? getDefaultSourceItems() : sources;

    final currentSource = effectiveSources.firstWhere(
      (s) => s.id == selectedSourceId,
      orElse: () => effectiveSources.first,
    );

    final probeStates = aggregator?.items ?? const <AggregatedSourceState>[];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 顶部提示条 (当默认源未命中时给出醒目提示)
        if (hintMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hintMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        // 顶部当前源高亮卡片
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.live_tv_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前视频源：${currentSource.name}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentSource.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '当前生效',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Text(
                    '可用视频源列表',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (aggregator?.isProbing == true) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '并发探测中...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (bundleMeta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'v${bundleMeta.version}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('探测中', style: TextStyle(fontSize: 10, color: Colors.blue)),
                );
                break;
              case SourceProbeStatus.ready:
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('🟢 已命中', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                );
                break;
              case SourceProbeStatus.empty:
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('未收录', style: TextStyle(fontSize: 10, color: Colors.grey)),
                );
                break;
              case SourceProbeStatus.error:
                statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('超时/异常', style: TextStyle(fontSize: 10, color: Colors.red)),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSourceSelected(src),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFF7F8FA)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.12),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                      size: 18,
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
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (src.isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '默认',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              statusBadge,
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: probe?.status == SourceProbeStatus.ready
                                  ? theme.colorScheme.primary
                                  : theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
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
