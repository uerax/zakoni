import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zakoway/features/player/source/models/source_models.dart';
import 'package:zakoway/features/player/source/source_bundle_manager.dart';

/// 适配器 Bundle 管理器 Provider
final sourceBundleManagerProvider = Provider<SourceBundleManager>((ref) {
  final manager = SourceBundleManager.instance;
  // 确保首次监听时触发初始化
  if (!manager.isReady) {
    manager.initialize();
  }
  return manager;
});

/// 当前可用视频源列表 Provider
final availableSourcesProvider = Provider<List<SourceMeta>>((ref) {
  final manager = ref.watch(sourceBundleManagerProvider);
  return manager.sources;
});

/// 当前解析器版本元数据 Provider
final sourceBundleMetaProvider = Provider<SourceBundleMeta?>((ref) {
  final manager = ref.watch(sourceBundleManagerProvider);
  return manager.meta;
});
