import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/bouncing_scale_card.dart';
import '../../common/widgets/cached_anime_image.dart';
import '../../common/widgets/shimmer_loading.dart';

/// 首页精选顶部横幅轮播图组件：
/// 1. 响应式布局：手机端几乎吃满屏幕宽度（极窄边距），平板/PC 桌面端限制最大宽度并水平居中；
/// 2. 海报高清偏上裁切：采用 800px 高分辨率大图，锚点偏向上方 Alignment(0, -0.4) 聚焦人物面部；
/// 3. 原生流畅体验：基于 PageView.builder 惰性加载，支持手势触摸感知与平滑自动轮播；
/// 4. 视觉信息沉浸：覆盖微渐变暗色遮罩、金星评分、热播勋章与动态胶囊指示器。
class HomeBannerCarousel extends StatefulWidget {
  final List<BangumiItem> items;
  final int maxCount;
  final Duration autoPlayInterval;

  const HomeBannerCarousel({
    super.key,
    required this.items,
    this.maxCount = 5,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;
  bool _isInteracting = false;

  List<BangumiItem> get _carouselItems => widget.items.take(widget.maxCount).toList();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      if (_currentIndex >= _carouselItems.length && _carouselItems.isNotEmpty) {
        _currentIndex = 0;
      }
      _restartAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_carouselItems.length <= 1) return;

    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (timer) {
      if (!mounted || _isInteracting || !_pageController.hasClients) return;
      final count = _carouselItems.length;
      if (count <= 1) return;

      final nextPage = (_currentIndex + 1) % count;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _restartAutoPlay() {
    _autoPlayTimer?.cancel();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _carouselItems;
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 600;

        // 手机端几乎吃满宽度（左右微边距 10px），平板及电脑宽屏居中并限宽 840px
        final double horizontalPadding = isNarrow ? 10.0 : 20.0;
        final double bannerHeight = isNarrow ? 195.0 : 250.0;
        final double borderRadiusValue = isNarrow ? 14.0 : 18.0;

        Widget content = Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: SizedBox(
            height: bannerHeight,
            child: Listener(
              // 手势交互探测：按下或滑动时暂时暂停定时器，松开后恢复，防止与用户操作打架
              onPointerDown: (_) {
                _isInteracting = true;
                _autoPlayTimer?.cancel();
              },
              onPointerUp: (_) {
                _isInteracting = false;
                _startAutoPlay();
              },
              onPointerCancel: (_) {
                _isInteracting = false;
                _startAutoPlay();
              },
              child: Stack(
                children: [
                  // 1. 轮播视图核心（PageView.builder 懒加载构建）
                  PageView.builder(
                    controller: _pageController,
                    itemCount: items.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildBannerCard(
                        context: context,
                        item: item,
                        borderRadius: BorderRadius.circular(borderRadiusValue),
                      );
                    },
                  ),

                  // 2. 右下角动态平滑胶囊指示器
                  if (items.length > 1)
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: _buildPageIndicator(items.length),
                    ),
                ],
              ),
            ),
          ),
        );

        if (!isNarrow) {
          content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }

  /// 单张横幅轮播卡片
  Widget _buildBannerCard({
    required BuildContext context,
    required BangumiItem item,
    required BorderRadius borderRadius,
  }) {
    return BouncingScaleCard(
      onTap: () => showAnimeDetailSheet(context, item),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景高清封面图：对准焦点偏上方 Alignment(0, -0.4) 优先保留人物头部与五官
            CachedAnimeImage(
              imageUrl: item.coverUrl,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.4),
              resizeWidth: 800,
            ),

            // 全局微暗底色，增强层次感
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(20),
              ),
            ),

            // 底部深色渐变遮罩，衬托白色文字
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(150),
                      Colors.black.withAlpha(220),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // 底部纯标题（简洁大气，无多余冗余参数遮挡画面）
            Positioned(
              left: 14,
              right: 76, // 右侧预留指示器避让空间
              bottom: 12,
              child: Text(
                item.preferredName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 动态平滑胶囊指示器
  Widget _buildPageIndicator(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (index) {
          final isSelected = index == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: isSelected ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withAlpha(100),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

/// 1:1 轮播图流光骨架屏
class ShimmerBannerCarousel extends StatelessWidget {
  const ShimmerBannerCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 600;

        final double horizontalPadding = isNarrow ? 10.0 : 20.0;
        final double bannerHeight = isNarrow ? 195.0 : 250.0;
        final double borderRadiusValue = isNarrow ? 14.0 : 18.0;

        Widget skeleton = Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ShimmerLoading(
            child: Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadiusValue),
              ),
            ),
          ),
        );

        if (!isNarrow) {
          skeleton = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: skeleton,
            ),
          );
        }

        return skeleton;
      },
    );
  }
}
