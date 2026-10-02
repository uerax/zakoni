import 'package:flutter/material.dart';

/// 高性能极速原地下拉菜单组件：
/// 1. 规避原生 PopupMenuButton 的路由 push 延迟与全量同步 layout 掉帧；
/// 2. 采用纯 OverlayEntry 原位弹窗 + 定高 ListView.builder 懒加载 (O(1) 绘制)，大量选项秒开无卡顿；
/// 3. 支持自动定位到当前选中项的滚动偏移，点击外部瞬间移除。
class InstantDropdownButton<T> extends StatefulWidget {
  final Widget child;
  final List<T> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final Widget Function(BuildContext context, T value, bool isSelected) itemBuilder;
  final double menuWidth;
  final double maxMenuHeight;
  final bool alignRight;

  const InstantDropdownButton({
    super.key,
    required this.child,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    required this.itemBuilder,
    this.menuWidth = 136,
    this.maxMenuHeight = 280,
    this.alignRight = false,
  });

  @override
  State<InstantDropdownButton<T>> createState() => _InstantDropdownButtonState<T>();
}

class _InstantDropdownButtonState<T> extends State<InstantDropdownButton<T>>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _closeMenu(immediately: true);
    _animController.dispose();
    super.dispose();
  }

  void _closeMenu({bool immediately = false}) {
    if (_overlayEntry == null) return;
    if (immediately) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _animController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    double left = widget.alignRight
        ? (offset.dx + size.width - widget.menuWidth)
        : offset.dx;

    // 屏幕边缘安全间距
    if (left < 10) left = 10;
    if (left + widget.menuWidth > screenWidth - 10) {
      left = screenWidth - widget.menuWidth - 10;
    }

    double top = offset.dy + size.height + 4;
    // 如果底部空间不足，向上弹出
    if (top + widget.maxMenuHeight > screenHeight - 60) {
      top = offset.dy - widget.maxMenuHeight - 4;
    }

    final selectedIndex = widget.items.indexOf(widget.selectedValue);
    final initialOffset = selectedIndex > 0
        ? (selectedIndex * 38.0).clamp(0.0, widget.items.length * 38.0)
        : 0.0;
    final scrollController = ScrollController(
      initialScrollOffset: initialOffset > 80 ? initialOffset - 38.0 : 0.0,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 全屏透明遮罩，点击外部瞬间关闭
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _closeMenu(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: widget.menuWidth,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  alignment: widget.alignRight ? Alignment.topRight : Alignment.topLeft,
                  child: Material(
                    elevation: 10,
                    color: isDark ? const Color(0xFF222226) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: widget.maxMenuHeight),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
                        ),
                      ),
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: widget.items.length,
                        itemExtent: 38,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final isSelected = item == widget.selectedValue;
                          return InkWell(
                            onTap: () {
                              _closeMenu();
                              widget.onSelected(item);
                            },
                            child: widget.itemBuilder(context, item, isSelected),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleMenu,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
