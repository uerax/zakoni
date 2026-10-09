import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/category_controller.dart';
import '../controllers/category_state.dart';
import '../models/category_constants.dart';

class CategoryGenreChips extends ConsumerWidget {
  final CategoryInitialArgs initialArgs;

  const CategoryGenreChips({
    super.key,
    this.initialArgs = const CategoryInitialArgs(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedTags = ref.watch(
      categoryControllerProvider(initialArgs).select((s) => s.filter.selectedTags),
    );
    final controller = ref.read(categoryControllerProvider(initialArgs).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：形式分类（TV / 剧场版 / OVA，无单选限制，可多选并存）
        _buildMediaTypeRow(context, controller, selectedTags, theme, isDark),

        const SizedBox(height: 8),

        // 第二行：题材分类（横向滑动流 + 右侧“展开 ▾”呼出 iOS 全量题材弹窗）
        _buildCollapsedGenreRow(context, controller, selectedTags, theme, isDark),
      ],
    );
  }

  /// 第一行：形式分类（全部、TV、剧场版、OVA）
  Widget _buildMediaTypeRow(
    BuildContext context,
    CategoryController controller,
    Set<String> selectedTags,
    ThemeData theme,
    bool isDark,
  ) {
    final types = CategoryConstants.mediaTypes;
    final hasAnyTypeSelected = types.any(selectedTags.contains);

    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChip(
              label: '全部',
              isSelected: !hasAnyTypeSelected,
              theme: theme,
              isDark: isDark,
              onTap: () => controller.setType(null),
            ),
            for (final type in types) ...[
              const SizedBox(width: 6),
              _buildChip(
                label: type,
                isSelected: selectedTags.contains(type),
                theme: theme,
                isDark: isDark,
                onTap: () => controller.toggleTag(type),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 第二行：横向滑动流 + 右侧“展开 ▾”胶囊按钮
  Widget _buildCollapsedGenreRow(
    BuildContext context,
    CategoryController controller,
    Set<String> selectedTags,
    ThemeData theme,
    bool isDark,
  ) {
    final genres = CategoryConstants.genres;
    final hasAnyGenreSelected = genres.any(selectedTags.contains);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // 左侧横向滚动题材流
          Expanded(
            child: SizedBox(
              height: 28,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: genres.length + 1, // +1 for "全部"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildChip(
                        label: '全部',
                        isSelected: !hasAnyGenreSelected,
                        theme: theme,
                        isDark: isDark,
                        onTap: controller.clearGenres,
                      ),
                    );
                  }

                  final genre = genres[index - 1];
                  final isSelected = selectedTags.contains(genre);

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildChip(
                      label: genre,
                      isSelected: isSelected,
                      theme: theme,
                      isDark: isDark,
                      onTap: () => controller.toggleTag(genre),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 右侧“展开 ▾”微型胶囊（呼出 iOS 风格全量题材选择窗口）
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showGenrePickerModal(context, controller, selectedTags, theme, isDark),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '展开',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 呼出 iOS 风格的全部题材/类型窗口：
  /// 1. 窗口内平铺所有标签胶囊（包含形式与题材，无单选限制，紧凑自适应文字宽度，不再撑满整行）；
  /// 2. 选择过程中完全不做网络请求；
  /// 3. 用户点击“完成”或滑下关闭窗口时，统一判断所选标签是否发生变化，有变化才发起单次请求。
  void _showGenrePickerModal(
    BuildContext context,
    CategoryController controller,
    Set<String> currentSelectedTags,
    ThemeData theme,
    bool isDark,
  ) {
    HapticFeedback.lightImpact();

    // 局部临时多选状态（操作期间不发请求）
    final tempSelected = Set<String>.from(currentSelectedTags);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (bottomSheetContext) {
        final screenHeight = MediaQuery.of(bottomSheetContext).size.height;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(maxHeight: screenHeight * 0.72),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部操作栏（重置 / 标题 / 完成）
                    Row(
                      children: [
                        // 重置按钮
                        GestureDetector(
                          onTap: tempSelected.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() {
                                    tempSelected.clear();
                                  });
                                },
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            '重置',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: tempSelected.isEmpty
                                  ? (isDark ? Colors.white24 : Colors.black26)
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const Spacer(),

                        // 居中主标题
                        Text(
                          '全部题材与分类',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleMedium?.color,
                          ),
                        ),
                        const Spacer(),

                        // 完成按钮（点击直接关闭窗口，并在退出时判断是否请求）
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(bottomSheetContext).pop();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 20),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '完成',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 状态提示副标题
                    Text(
                      tempSelected.isEmpty
                          ? '当前未限制标签，展示全部分类'
                          : '已勾选 ${tempSelected.length} 项（可多选组合过滤）',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 滚动标签内容区（自然流式平铺，自适应文字宽度，不再占满全行）
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. 形式类型分组
                            Text(
                              '形式类型 (可多选)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant.withAlpha(200),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: CategoryConstants.mediaTypes.map((type) {
                                final isSelected = tempSelected.contains(type);
                                return _buildModalChip(
                                  label: type,
                                  isSelected: isSelected,
                                  theme: theme,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setModalState(() {
                                      if (isSelected) {
                                        tempSelected.remove(type);
                                      } else {
                                        tempSelected.add(type);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 18),

                            // 2. 题材风格分组
                            Text(
                              '题材风格 (可多选)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant.withAlpha(200),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: CategoryConstants.genres.map((genre) {
                                final isSelected = tempSelected.contains(genre);
                                return _buildModalChip(
                                  label: genre,
                                  isSelected: isSelected,
                                  theme: theme,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setModalState(() {
                                      if (isSelected) {
                                        tempSelected.remove(genre);
                                      } else {
                                        tempSelected.add(genre);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // 弹窗关闭时，比对最终结果是否与展开前一致；仅在发生实质变化时发起一次网络请求
      if (!setEquals(tempSelected, currentSelectedTags)) {
        controller.setTags(tempSelected);
      }
    });
  }

  /// 弹窗内部自适应文字宽度的胶囊（M3 Stadium 胶囊）
  Widget _buildModalChip({
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            widthFactor: 1.0,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 统一定制轻量级微型胶囊（M3 表现力 StadiumBorder 药丸）
  Widget _buildChip({
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
