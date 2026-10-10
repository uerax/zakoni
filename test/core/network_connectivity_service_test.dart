import 'package:flutter_test/flutter_test.dart';
import 'package:zakoway/core/services/network_connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkConnectivityService 单例与状态测试', () {
    test('初始状态与单例实例健全性', () {
      final service = NetworkConnectivityService.instance;
      expect(service, isNotNull);
      // 桌面环境默认视作非计费高速网络
      expect(service.isMetered, isA<bool>());
      expect(service.isMeteredListenable.value, equals(service.isMetered));
    });
  });
}
