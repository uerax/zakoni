import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/bangumi_client.dart';

/// 全局 BangumiClient 实例 Provider
/// 支持在测试中通过 `bangumiClientProvider.overrideWithValue(mockClient)` 注入 Mock 客户端
final bangumiClientProvider = Provider<BangumiClient>((ref) {
  return BangumiClient();
});
