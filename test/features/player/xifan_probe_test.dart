import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/source/sources/xifan_next_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('测试 xifan-next 3403 选集与三线路独立解析', () async {
    final source = XifanNextSource();

    final roads = await source.chapters('https://next.xifanacg.com/anime/3403');
    expect(roads.length, 3);
    expect(roads[0].name, contains('稀饭新番主线-1'));
    expect(roads[1].name, contains('稀饭新番主线-2'));
    expect(roads[2].name, contains('稀饭备用-1'));

    // 1. 测试未指定线路（默认走国内沃云主线）
    final res0 = await source.resolve('https://next.xifanacg.com/anime/3403/play/121397');
    expect(res0.url, contains('moedot.net'));
    expect(res0.format, 'mp4');

    // 2. 测试严格指定线路 0 (稀饭新番主线-1 -> 国内沃云)
    final resRoad0 = await source.resolve(roads[0].episodes.first.url);
    expect(resRoad0.url, contains('moedot.net'));
    expect(resRoad0.format, 'mp4');

    // 3. 测试严格指定线路 1 (稀饭新番主线-2 -> 海外源)
    final resRoad1 = await source.resolve(roads[1].episodes.first.url);
    expect(resRoad1.url, contains('play.xfvod.pro:8088'));
    expect(resRoad1.format, 'mp4');

    // 4. 测试严格指定线路 2 (稀饭备用-1 -> 国内 HLS)
    final resRoad2 = await source.resolve(roads[2].episodes.first.url);
    expect(resRoad2.url, contains('dl.playxf.top'));
    expect(resRoad2.format, 'hls');
  });
}
