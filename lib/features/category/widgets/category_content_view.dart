import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../controllers/category_controller.dart';

class CategoryContentView extends ConsumerWidget {
  final String? initialCategory;

  const CategoryContentView({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isLoading = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.isLoading),
    );
    final errorMessage = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.errorMessage),
    );
    final items = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.items),
    );
    final controller = ref.read(categoryControllerProvider(initialCategory).notifier);

    // 1. 初次或切换条件加载中：呈现与 AnimeCard 1:1 的高性能流光骨架屏
    if (isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.crossAxisExtent;
            final count = width < 500 ? 3 : (width < 750 ? 4 : (width < 1000 ? 5 : 6));
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                childAspectRatio: 0.58,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ShimmerAnimeCard(),
                childCount: 12,
              ),
            );
          },
        ),
      );
    }

    // 2. 异常失败状态
    if (errorMessage != null && items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                '获取番剧列表失败',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: controller.fetchFirstPage,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新尝试'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. 空结果状态
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  size: 36,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '未找到匹配的番剧条目',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '可尝试放宽年份或切换为其他题材分类',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: controller.resetToDefault,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('恢复默认'),
              ),
            ],
          ),
        ),
      );
    }

    // 4. 正常数据呈现：自适应 3 列（移动端推荐）/ 4~6 列（宽屏）网格瀑布流
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final count = width < 500 ? 3 : (width < 750 ? 4 : (width < 1000 ? 5 : 6));

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return AnimeCard(
                  key: ValueKey('anime_cat_${item.id}'),
                  item: item,
                  compact: true,
                );
              },
              childCount: items.length,
            ),
          );
        },
      ),
    );
  }
}
