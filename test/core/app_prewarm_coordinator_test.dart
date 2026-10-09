import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/core/services/app_preferences.dart';
import 'package:zakoni/core/services/app_prewarm_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.init();
    AppPrewarmCoordinator.instance.invalidateCacheSizes();

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });
  });

  group('AppPrewarmCoordinator utility & state tests', () {
    test('formatBytes correctly formats sizes in B, KB, MB', () {
      expect(AppPrewarmCoordinator.formatBytes(0), equals('0.0 MB'));
      expect(AppPrewarmCoordinator.formatBytes(-10), equals('0.0 MB'));
      expect(AppPrewarmCoordinator.formatBytes(512), equals('0.5 KB'));
      expect(AppPrewarmCoordinator.formatBytes(1024), equals('1.0 KB'));
      expect(AppPrewarmCoordinator.formatBytes(1024 * 1024), equals('1.0 MB'));
      expect(AppPrewarmCoordinator.formatBytes(5 * 1024 * 1024), equals('5.0 MB'));
    });

    test('getCachedSizeStrings returns null before caching and formatted strings after', () {
      final coordinator = AppPrewarmCoordinator.instance;
      expect(coordinator.getCachedSizeStrings(), isNull);

      coordinator.cachedImageBytes = 2048;
      coordinator.cachedDataBytes = 1024 * 1024 * 2;

      final strings = coordinator.getCachedSizeStrings();
      expect(strings, isNotNull);
      expect(strings!.image, equals('2.0 KB'));
      expect(strings.data, equals('2.0 MB'));

      coordinator.invalidateCacheSizes();
      expect(coordinator.getCachedSizeStrings(), isNull);
    });

    test('prewarmSettings single-flight idempotency returns the exact same Future', () async {
      final coordinator = AppPrewarmCoordinator.instance;
      final client = BangumiClient();

      final future1 = coordinator.prewarmSettings(client);
      final future2 = coordinator.prewarmSettings(client);

      // 验证单飞机制：两次调用共享同一个 Future 实例，防止并发重复扫描磁盘
      expect(identical(future1, future2), isTrue);

      final result = await future1;
      expect(result.imgBytes, isA<int>());
      expect(result.dataBytes, isA<int>());
    });
  });
}
