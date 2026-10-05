import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'package:zakoni/features/player/widgets/player_side_panel.dart';

/// 顶部药丸微光按钮
class PlayerPillButton extends StatelessWidget {
  const PlayerPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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

/// 播放器顶部导航栏（包含返回键、标题、选集、换源、弹幕侧栏、截图按钮）
class PlayerControlsTopBar extends StatelessWidget {
  const PlayerControlsTopBar({
    super.key,
    required this.title,
    this.isFullscreen = false,
    this.onBackPressed,
    this.onOpenEpisodePicker,
    this.onOpenSidePanel,
    this.onScreenshot,
    this.danmakuController,
  });

  final String title;
  final bool isFullscreen;
  final VoidCallback? onBackPressed;
  final VoidCallback? onOpenEpisodePicker;
  final ValueChanged<PlayerSidePanelTab>? onOpenSidePanel;
  final VoidCallback? onScreenshot;
  final DanmakuController? danmakuController;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            if (onBackPressed != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                        width: 0.5,
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: onBackPressed,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            if (onOpenEpisodePicker != null || onOpenSidePanel != null) ...[
              const SizedBox(width: 8),
              PlayerPillButton(
                icon: Icons.video_library_rounded,
                label: '选集',
                onTap: () {
                  if (onOpenSidePanel != null) {
                    onOpenSidePanel!(PlayerSidePanelTab.episodes);
                  } else {
                    onOpenEpisodePicker?.call();
                  }
                },
              ),
              if (isFullscreen && onOpenSidePanel != null) ...[
                const SizedBox(width: 6),
                PlayerPillButton(
                  icon: Icons.swap_horiz_rounded,
                  label: '换源',
                  onTap: () {
                    onOpenSidePanel!(PlayerSidePanelTab.sources);
                  },
                ),
                if (danmakuController != null) ...[
                  const SizedBox(width: 6),
                  PlayerPillButton(
                    icon: Icons.tune_rounded,
                    label: '弹幕',
                    onTap: () {
                      onOpenSidePanel!(PlayerSidePanelTab.danmaku);
                    },
                  ),
                ],
              ],
              if (onScreenshot != null) ...[
                const SizedBox(width: 6),
                PlayerPillButton(
                  icon: Icons.camera_alt_outlined,
                  label: '截图',
                  onTap: onScreenshot!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
