import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoway/features/player/danmaku/models/danmaku_item.dart';
import 'package:zakoway/features/player/danmaku/source/dandan_config_manager.dart';
import 'package:zakoway/features/player/services/player_preferences_service.dart';
import 'package:zakoway/features/player/source/models/source_models.dart';
import 'package:zakoway/features/player/source/native_source_runtime.dart';
import 'package:zakoway/features/player/source/sources/video_source.dart';

class _FakeVideoSource extends VideoSource {
  int searchCount = 0;
  int chaptersCount = 0;
  int resolveCount = 0;

  @override
  String get id => 'fake_source';
  @override
  String get name => 'Fake Source';
  @override
  String get version => '1.0.0';
  @override
  String get description => 'Testing Source';

  @override
  Future<List<SourceSearchResult>> search(String keyword) async {
    searchCount++;
    return [
      SourceSearchResult(name: '测试番剧: $keyword', url: 'https://fake.tv/$keyword'),
    ];
  }

  @override
  Future<List<SourceChapterRoad>> chapters(String animeUrl) async {
    chaptersCount++;
    return [
      const SourceChapterRoad(
        name: '线路1',
        episodes: [
          SourceEpisode(name: '第1集', url: 'https://fake.tv/ep1'),
        ],
      ),
    ];
  }

  @override
  Future<SourceResolveResult> resolve(String episodeUrl) async {
    resolveCount++;
    return SourceResolveResult(
      url: 'https://fake.stream/video.m3u8',
      format: 'hls',
      headers: {'Referer': 'https://fake.tv'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('DandanConfigManager 鉴权与配置测试', () {
    test('初始未配置时，默认使用内置 fallback 凭据与 legacy 鉴权模式', () async {
      final config = DandanConfigManager.instance;
      await config.initialize();
      await config.resetToDefault();

      expect(config.isCustomCredentials, isFalse);
      expect(config.effectiveAppId, equals('hvf6pzvxcm'));
      expect(config.effectiveAppSecret, equals('IZhcUIakoxFaK9xBBDJ9Bs1OU2s4kK5t'));
      expect(config.effectiveAuthMode, equals(DandanAuthMode.legacy));
      expect(config.effectiveEndpoint, equals('https://api.dandanplay.net'));
    });

    test('保存用户自定义凭证后，自动切换为 open 鉴权模式与生效配置', () async {
      final config = DandanConfigManager.instance;
      await config.initialize();

      await config.saveConfig(
        appId: 'my_app_id_123',
        appSecret: 'my_secret_456',
        apiEndpoint: 'https://custom.dandan.net/',
      );

      expect(config.isCustomCredentials, isTrue);
      expect(config.effectiveAppId, equals('my_app_id_123'));
      expect(config.effectiveAppSecret, equals('my_secret_456'));
      expect(config.effectiveAuthMode, equals(DandanAuthMode.open));
      expect(config.effectiveEndpoint, equals('https://custom.dandan.net'));

      // 重置回默认
      await config.resetToDefault();
      expect(config.isCustomCredentials, isFalse);
    });

    test('generateSignature 生成标准的 SHA-256 Base64 开放平台签名', () {
      final sig = DandanConfigManager.generateSignature(
        path: '/api/v2/bangumi/bgmtv/1',
        timestamp: 1700000000,
        appId: 'test_id',
        appSecret: 'test_secret',
      );

      expect(sig, isNotEmpty);
      expect(sig.length, greaterThan(20));
      // 验证幂等性
      final sig2 = DandanConfigManager.generateSignature(
        path: '/api/v2/bangumi/bgmtv/1',
        timestamp: 1700000000,
        appId: 'test_id',
        appSecret: 'test_secret',
      );
      expect(sig, equals(sig2));
    });
  });

  group('PlayerPreferencesService 播放倍速与音量持久化测试', () {
    test('默认倍速为 1.0，音量为 0.5', () async {
      final prefs = PlayerPreferencesService.instance;
      await prefs.initialize();

      expect(prefs.playbackRate, equals(1.0));
      expect(prefs.volume, equals(0.5));
    });

    test('保存倍速与音量后持久化存储并可恢复', () async {
      final prefs = PlayerPreferencesService.instance;
      await prefs.initialize();

      await prefs.savePlaybackRate(1.5);
      await prefs.saveVolume(0.8);

      expect(prefs.playbackRate, equals(1.5));
      expect(prefs.volume, equals(0.8));

      // 验证弹幕外观设置保存
      const customDanmaku = DanmakuSettings(
        opacity: 0.6,
        fontSizeScale: 1.25,
        speed: 1.5,
        filters: ['垃圾', '/test.*/'],
      );
      await prefs.saveDanmakuSettings(customDanmaku);
      expect(prefs.danmakuSettings.opacity, equals(0.6));
      expect(prefs.danmakuSettings.fontSizeScale, equals(1.25));
      expect(prefs.danmakuSettings.filters.length, equals(2));
    });
  });

  group('NativeSourceRuntime 全局统一双层缓存测试', () {
    test('视频源搜索、选集与直链解析命中双层缓存且去重，bypassCache 时可重新请求', () async {
      final runtime = NativeSourceRuntime();
      final fakeSource = _FakeVideoSource();
      runtime.registerSource(fakeSource);

      // 1. 首次搜索
      final res1 = await runtime.search('fake_source', '葬送');
      expect(res1.length, equals(1));
      expect(fakeSource.searchCount, equals(1));

      // 2. 第二次搜索相同词 -> 命中缓存，不发起网络请求
      final res2 = await runtime.search('fake_source', '葬送');
      expect(res2.length, equals(1));
      expect(fakeSource.searchCount, equals(1));

      // 3. 强制 bypassCache 搜索 -> 绕过缓存发起网络请求
      final res3 = await runtime.search('fake_source', '葬送', bypassCache: true);
      expect(res3.length, equals(1));
      expect(fakeSource.searchCount, equals(2));

      // 4. 选集线路章节缓存
      final ch1 = await runtime.chapters('fake_source', 'https://fake.tv/ep');
      expect(ch1.length, equals(1));
      expect(fakeSource.chaptersCount, equals(1));

      final ch2 = await runtime.chapters('fake_source', 'https://fake.tv/ep');
      expect(ch2.length, equals(1));
      expect(fakeSource.chaptersCount, equals(1));

      // 5. 直链解析缓存
      final r1 = await runtime.resolve('fake_source', 'https://fake.tv/ep1');
      expect(r1.url, equals('https://fake.stream/video.m3u8'));
      expect(fakeSource.resolveCount, equals(1));

      final r2 = await runtime.resolve('fake_source', 'https://fake.tv/ep1');
      expect(r2.url, equals('https://fake.stream/video.m3u8'));
      expect(fakeSource.resolveCount, equals(1));

      // 6. 验证清空缓存
      runtime.clearMemoryCache();
      expect(runtime.memoryCacheSizeBytes, equals(0));
    });
  });
}
