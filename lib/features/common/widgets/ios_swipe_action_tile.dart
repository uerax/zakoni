import 'package:flutter/material.dart';

/// 仿 iOS 原生列表项向左滑动露出删除按钮的操作组件
class IosSwipeActionTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final double actionWidth;

  const IosSwipeActionTile({
    super.key,
    required this.child,
    required this.onDelete,
    this.actionWidth = 72.0,
  });

  @override
  State<IosSwipeActionTile> createState() => _IosSwipeActionTileState();
}

class _IosSwipeActionTileState extends State<IosSwipeActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    _animateTo(-widget.actionWidth);
  }

  void _close() {
    _animateTo(0.0);
  }

  void _animateTo(double target) {
    _animation = Tween<double>(
      begin: _dragExtent,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
      setState(() {
        _dragExtent = _animation.value;
      });
    });
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final revealWidth = (-_dragExtent).clamp(0.0, widget.actionWidth);

    return TapRegion(
      onTapOutside: (_) {
        if (_dragExtent < 0) {
          _close();
        }
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 浮层：随着水平手势滑动的卡片行主体
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragExtent += details.primaryDelta!;
                _dragExtent = _dragExtent.clamp(-widget.actionWidth * 1.15, 0.0);
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragExtent < -widget.actionWidth / 2 || details.primaryVelocity! < -250) {
                _open();
              } else {
                _close();
              }
            },
            child: Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: widget.child,
            ),
          ),

          // 右侧露出的 M3 红色删除块（宽度随滑动动态展开，不透底）
          if (revealWidth > 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: revealWidth,
              child: ClipRect(
                child: Material(
                  color: Theme.of(context).colorScheme.error,
                  child: InkWell(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.onError,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '删除',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 当已经滑开展开删除按钮时，点击左侧非按钮区域自动回弹关闭
          if (_dragExtent < 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: revealWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
        ],
      ),
    );
  }
}
