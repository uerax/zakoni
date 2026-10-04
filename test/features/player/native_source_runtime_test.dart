import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/source/native_source_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('测试 NativeSourceRuntime 初始化与源列表', () async {
    final runtime = NativeSourceRuntime();
    await runtime.initialize();

    expect(runtime.isInitialized, isTrue);
    expect(runtime.bundleMeta.version, contains('native'));

    final sources = runtime.availableSources;
    expect(sources.length, 12);
    expect(sources.any((s) => s.id == 'xifan-next'), isTrue);
    expect(sources.any((s) => s.id == 'girigiri'), isTrue);
    expect(sources.any((s) => s.id == 'mifun'), isTrue);
    expect(sources.any((s) => s.id == 'cycani'), isTrue);
    expect(sources.any((s) => s.id == 'moonci'), isTrue);
    expect(sources.any((s) => s.id == 'tvtfun'), isTrue);
    expect(sources.any((s) => s.id == 'lzizy'), isTrue);
    expect(sources.any((s) => s.id == 'animoe'), isTrue);
    expect(sources.any((s) => s.id == 'mxdm'), isTrue);
    expect(sources.any((s) => s.id == 'omofun'), isTrue);
    expect(sources.any((s) => s.id == 'anime1'), isTrue);
    expect(sources.any((s) => s.id == 'libvio'), isTrue);

    runtime.dispose();
  });

  test('测试原生视频源搜索、分集拉取与直链解析全流程', () async {
    final runtime = NativeSourceRuntime();
    await runtime.initialize();

    // 1. 验证量子资源原生搜索、分集与解析
    final lzizyHits = await runtime.search('lzizy', '葬送的芙莉莲');
    expect(lzizyHits, isNotEmpty);
    expect(lzizyHits.first.name, contains('芙莉莲'));

    final lzizyRoads = await runtime.chapters('lzizy', lzizyHits.first.url);
    expect(lzizyRoads, isNotEmpty);
    expect(lzizyRoads.first.episodes, isNotEmpty);

    final lzizyMedia = await runtime.resolve('lzizy', lzizyRoads.first.episodes.first.url);
    expect(lzizyMedia.url, startsWith('http'));

    // 2. 验证稀饭原生搜索、章节与解析
    final xifanHits = await runtime.search('xifan-next', '葬送的芙莉莲');
    expect(xifanHits, isNotEmpty);

    final xifanRoads = await runtime.chapters('xifan-next', xifanHits.first.url);
    expect(xifanRoads, isNotEmpty);

    final xifanMedia = await runtime.resolve('xifan-next', xifanRoads.first.episodes.first.url);
    expect(xifanMedia.url, startsWith('http'));

    // 3. 验证次元城原生搜索、分集与解析
    final cycHits = await runtime.search('cycani', '葬送的芙莉莲');
    expect(cycHits, isNotEmpty);

    final cycRoads = await runtime.chapters('cycani', cycHits.first.url);
    expect(cycRoads, isNotEmpty);

    final cycMedia = await runtime.resolve('cycani', cycRoads.first.episodes.first.url);
    expect(cycMedia.url, startsWith('http'));

    runtime.dispose();
  });
}
