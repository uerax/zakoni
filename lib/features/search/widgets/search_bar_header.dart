import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 搜索页面顶部导航栏与胶囊输入框
class SearchBarHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const SearchBarHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSearch,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1E).withAlpha(190)
            : Colors.white.withAlpha(200),
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withAlpha(18),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
              child: Row(
                children: [
                  // 1. 返回按钮（遵循 iOS 规范 44×44pt 触控热区）
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onBack();
                    },
                    icon: Icon(
                      CupertinoIcons.chevron_back,
                      size: 22,
                      color: theme.colorScheme.onSurface,
                    ),
                    tooltip: '返回',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),

                  // 2. 居中一体化胶囊输入框
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withAlpha(18)
                            : Colors.black.withAlpha(12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withAlpha(22)
                              : Colors.black.withAlpha(15),
                          width: 0.8,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) {
                                HapticFeedback.selectionClick();
                                onSearch();
                              },
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: '搜索番剧…',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withAlpha(150),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          // 清空输入文本按钮
                          ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) {
                              if (controller.text.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onClear();
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withAlpha(60)
                                          : Colors.black.withAlpha(45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3. 右侧搜索操作按钮
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onSearch();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(44, 36),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('搜索'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
