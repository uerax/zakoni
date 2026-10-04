import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

/// 纯视频画面与弹幕复合渲染表面
/// 严格使用 RepaintBoundary 对视频画面和弹幕图层进行独立光栅化隔离
class VideoSurface extends StatelessWidget {
  const VideoSurface({
    super.key,
    required this.controller,
    this.danmakuController,
    this.overlay,
  });

  final ZakoniPlaybackController controller;
  final DanmakuController? danmakuController;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 底层：mpv 视频渲染层
          ValueListenableBuilder<VideoController?>(
            valueListenable: controller.videoControllerNotifier,
            builder: (context, videoController, _) {
              if (videoController == null) {
                return const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white70,
                    ),
                  ),
                );
              }

              return ValueListenableBuilder<PlaybackCoreState>(
                valueListenable: controller.core,
                builder: (context, coreState, _) {
                  return RepaintBoundary(
                    child: Video(
                      controller: videoController,
                      controls: NoVideoControls, // 使用完全自研的高定制控制条
                      fit: coreState.videoFit,
                      pauseUponEnteringBackgroundMode: false,
                      resumeUponEnteringForegroundMode: true,
                    ),
                  );
                },
              );
            },
          ),

          // 2. 中层：纯 Flutter 原生高性能 Canvas 弹幕层
          if (danmakuController != null)
            Positioned.fill(
              child: DanmakuView(
                controller: danmakuController!,
              ),
            ),

          // 3. 缓冲中指示器
          ValueListenableBuilder<PlaybackCoreState>(
            valueListenable: controller.core,
            builder: (context, coreState, _) {
              if (coreState.buffering && !coreState.loading) {
                return const Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              if (coreState.hasError) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      coreState.errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // 4. 顶层：控制层 UI 浮层
          ?overlay,
        ],
      ),
    );
  }
}
