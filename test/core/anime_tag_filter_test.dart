import 'package:flutter_test/flutter_test.dart';
import 'package:zakoway/core/utils/anime_tag_filter.dart';

void main() {
  group('AnimeTagFilter tests', () {
    test('Correctly identifies temporal tags across multiple patterns', () {
      final temporalSamples = [
        '2026',
        '2026年',
        '1998',
        '2026年7月',
        '2026年07月',
        '2024.4',
        '2024-10',
        '2024/07',
        '2026春',
        '2024年秋',
        '2025冬番',
        '2024秋季',
        '80年代',
        '90年代',
        '00年代',
        '2026新番',
        '10月新番',
        '新番',
      ];

      for (final tag in temporalSamples) {
        expect(AnimeTagFilter.isTemporalTag(tag), isTrue, reason: 'Failed for $tag');
        expect(AnimeTagFilter.isNoiseTag(tag), isTrue, reason: 'Failed isNoiseTag for $tag');
      }
    });

    test('Correctly filters carrier and generic noise tags', () {
      final noiseSamples = [
        'TV',
        'tv',
        '剧场版',
        'OVA',
        'oad',
        'WEB',
        'ona',
        '里番',
        '日本',
        '日漫',
        '漫画改',
        '漫改',
        '小说改',
        '轻改',
        '轻小说改',
        'bilibili',
        'b站',
      ];

      for (final tag in noiseSamples) {
        expect(AnimeTagFilter.isNoiseTag(tag), isTrue, reason: 'Failed for $tag');
      }
    });

    test('Preserves special creator source tags per business requirement', () {
      final preservedSourceTags = [
        '游改',
        '游戏改',
        'gal改',
        'galgame改',
        '原创',
        '原创动画',
      ];

      for (final tag in preservedSourceTags) {
        expect(AnimeTagFilter.isNoiseTag(tag), isFalse, reason: 'Should NOT filter $tag');
      }
    });

    test('Preserves genuine genre/theme tags', () {
      final genreTags = [
        '恋爱',
        '悬疑',
        '科幻',
        '萌系',
        '百合',
        '奇幻',
        '日常',
        '热血',
      ];

      for (final tag in genreTags) {
        expect(AnimeTagFilter.isNoiseTag(tag), isFalse, reason: 'Should NOT filter $tag');
      }
    });

    test('cleanUserTagFreq correctly cleans user frequency dictionary', () {
      final rawUserFreq = {
        'TV': 110,
        '日本': 110,
        '2026年7月': 40,
        '2026': 30,
        '恋爱': 66,
        '悬疑': 22,
        '科幻': 5,
        '萌系': 3,
        '百合': 2,
        'gal改': 8, // 保留
        '原创': 12, // 保留
      };

      final cleaned = AnimeTagFilter.cleanUserTagFreq(rawUserFreq);

      expect(cleaned, equals({
        '恋爱': 66,
        '悬疑': 22,
        '科幻': 5,
        '萌系': 3,
        '百合': 2,
        'gal改': 8,
        '原创': 12,
      }));
      expect(cleaned.containsKey('TV'), isFalse);
      expect(cleaned.containsKey('日本'), isFalse);
      expect(cleaned.containsKey('2026年7月'), isFalse);
      expect(cleaned.containsKey('2026'), isFalse);
    });

    test('filterByGenreAllowList matches only controlled vocabulary tags', () {
      final rawUserFreq = {
        'TV': 110,
        '日本': 110,
        '大沼心请退役': 99,
        '这番太乐了': 50,
        '恋爱': 66,
        '悬疑': 22,
        '打斗': 15,
        '宫廷': 8,
        '一般向': 5,
        'gal改': 4,
      };

      final matched = AnimeTagFilter.filterByGenreAllowList(rawUserFreq);

      expect(matched, equals({
        '恋爱': 66,
        '悬疑': 22,
        '打斗': 15,
        '宫廷': 8,
        '一般向': 5,
        'gal改': 4,
      }));
      expect(matched.containsKey('大沼心请退役'), isFalse);
      expect(matched.containsKey('这番太乐了'), isFalse);
      expect(matched.containsKey('TV'), isFalse);
      expect(AnimeTagFilter.isAllowedGenre('打斗'), isTrue);
      expect(AnimeTagFilter.isAllowedGenre('宫廷'), isTrue);
      expect(AnimeTagFilter.isAllowedGenre('一般向'), isTrue);
      expect(AnimeTagFilter.isAllowedGenre('未知吐槽'), isFalse);
    });
  });
}
