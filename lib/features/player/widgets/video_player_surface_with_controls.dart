import 'package:flutter/material.dart';
import 'package:zakoni/core/services/bangumi_oped_service.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'player_controls.dart';
import 'player_side_panel.dart';
import 'video_player_placeholder.dart';
import 'video_surface.dart';

/// 播放器带控制层、解析错误浮层与 HUD 的完整视频视口组件
class VideoPlayerSurfaceWithControls extends StatelessWidget {
  const VideoPlayerSurfaceWithControls({
    super.key,
    required this.controller,
    required this.title,
    this.danmakuController,
    this.danmakuCoordinator,
    this.isFullscreen = false,
    required this.onToggleFullscreen,
    required this.onBackPressed,
    this.onOpenEpisodePicker,
    this.onOpenSidePanel,
    this.onNextEpisode,
    this.onPrevEpisode,
    this.opedSegment,
    this.hudToast,
    this.resolveError,
    required this.primaryColor,
    required this.onRetryResolve,
    required this.onSwitchSource,
    this.autoPlayNextNotifier,
  });

  final ZakoniPlaybackController controller;
  final String title;
  final DanmakuController? danmakuController;
  final DanmakuSessionCoordinator? danmakuCoordinator;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onBackPressed;
  final VoidCallback? onOpenEpisodePicker;
  final ValueChanged<PlayerSidePanelTab>? onOpenSidePanel;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;
  final EpisodeOpedSegment? opedSegment;
  final String? hudToast;
  final String? resolveError;
  final Color primaryColor;
  final VoidCallback onRetryResolve;
  final VoidCallback onSwitchSource;
  final ValueNotifier<bool>? autoPlayNextNotifier;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VideoSurface(
          controller: controller,
          danmakuController: danmakuController,
          overlay: PlayerControls(
            controller: controller,
            title: title,
            danmakuController: danmakuController,
            danmakuCoordinator: danmakuCoordinator,
            isFullscreen: isFullscreen,
            onToggleFullscreen: onToggleFullscreen,
            onBackPressed: onBackPressed,
            onOpenEpisodePicker: onOpenEpisodePicker,
            onOpenSidePanel: onOpenSidePanel,
            onNextEpisode: onNextEpisode,
            onPrevEpisode: onPrevEpisode,
            opedSegment: opedSegment,
            autoPlayNextNotifier: autoPlayNextNotifier,
          ),
        ),

        // HUD Toast 悬浮提示胶囊
        if (hudToast != null)
          VideoPlayerHudToast(message: hudToast!),

        // iOS 风格解析失败提示磨砂卡片
        if (resolveError != null)
          VideoPlayerResolveErrorCard(
            errorText: resolveError!,
            primaryColor: primaryColor,
            onRetry: onRetryResolve,
            onSwitchSource: onSwitchSource,
          ),
      ],
    );
  }
}
