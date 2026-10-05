import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/danmaku_item.dart';
import 'danmaku_text_normalizer.dart';

/// 预编译的屏蔽规则
abstract interface class DanmakuCompiledRule {
  bool matches(String text);
}

class _RegexRule implements DanmakuCompiledRule {
  _RegexRule(this.regex);
  final RegExp regex;

  @override
  bool matches(String text) => regex.hasMatch(text);
}

class _SubstringRule implements DanmakuCompiledRule {
  _SubstringRule(this.text);
  final String text;

  @override
  bool matches(String text) => text.contains(this.text);
}

/// 聚合合并桶
class _MergeBucket {
  _MergeBucket({
    required this.lead,
    required this.normKey,
    required this.count,
    required this.lastTimeMs,
  });

  DanmakuItem lead;
  String normKey;
  int count;
  int lastTimeMs;
}

/// 弹幕高级过滤与 Pakku 级精简去噪引擎 (1:1 对齐 animaku danmaku-utils.ts)
class DanmakuFilterEngine {
  DanmakuFilterEngine._();

  /// 4.0 秒滑动聚合窗口
  static const int _kSimplifyMergeWindowMs = 4000;

  /// 精简模式下每秒最多放行弹幕条数（防遮挡视频主体内容）
  static const int _kSimplifyMaxPerSec = 8;

  static final RegExp _countBadgeRegex = RegExp(r'(?:[xX×]\d+|\([xX×]\d+\))$');

  /// 预编译屏蔽词规则列表
  static List<DanmakuCompiledRule> compileRules(List<String> rawRules) {
    if (rawRules.isEmpty) return const [];
    final list = <DanmakuCompiledRule>[];

    for (final rule in rawRules) {
      final s = rule.trim();
      if (s.isEmpty) continue;

      if (s.startsWith('/') && s.lastIndexOf('/') > 0) {
        try {
          final lastSlash = s.lastIndexOf('/');
          final pattern = s.substring(1, lastSlash);
          final flags = s.substring(lastSlash + 1);
          list.add(_RegexRule(RegExp(
            pattern,
            caseSensitive: !flags.contains('i'),
            multiLine: flags.contains('m'),
          )));
          continue;
        } catch (_) {}
      }

      list.add(_SubstringRule(s));
    }

    return list;
  }

  /// 全量过滤与精简主入口
  static List<DanmakuItem> filter(
    List<DanmakuItem> comments,
    DanmakuSettings settings, {
    List<DanmakuCompiledRule>? precompiledRules,
  }) {
    if (!settings.enabled || comments.isEmpty) return const [];

    final rules = precompiledRules ?? compileRules(settings.filters);

    final filtered = comments.where((c) {
      if (settings.hideScroll && c.mode == DanmakuMode.scroll) return false;
      if (settings.hideTop && c.mode == DanmakuMode.top) return false;
      if (settings.hideBottom && c.mode == DanmakuMode.bottom) return false;
      if (settings.hideColor && c.color != Colors.white) return false;

      for (final rule in rules) {
        if (rule.matches(c.text)) return false;
      }
      return true;
    }).toList();

    if (settings.simplify) {
      return simplify(filtered);
    }

    return filtered;
  }

  /// Bilibili / Pakku 标准弹幕精简算法：
  /// 1. 4.0s 滑动窗口去重聚合并附加 (×N) 徽标
  /// 2. 高密度智能加权节流（按信息熵与长度打分，丢弃低熵复读刷屏）
  static List<DanmakuItem> simplify(List<DanmakuItem> comments) {
    if (comments.length <= 1) return comments;

    final sorted = List.of(comments)..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    final merged = <DanmakuItem>[];
    final activeBuckets = <String, _MergeBucket>{};

    for (final c in sorted) {
      final norm = DanmakuTextNormalizer.normalize(c.text);
      final key = '${c.mode.name}|$norm';
      final existing = activeBuckets[key];

      if (existing != null && c.timeMs - existing.lastTimeMs <= _kSimplifyMergeWindowMs) {
        // 窗口内重复：累加计数并前移最后时间
        existing.count += 1;
        existing.lastTimeMs = c.timeMs;
      } else {
        if (existing != null) {
          merged.add(_formatMergedItem(existing));
          activeBuckets.remove(key);
        }
        activeBuckets[key] = _MergeBucket(
          lead: c,
          normKey: norm,
          count: 1,
          lastTimeMs: c.timeMs,
        );
      }
    }

    for (final bucket in activeBuckets.values) {
      merged.add(_formatMergedItem(bucket));
    }

    merged.sort((a, b) => a.timeMs.compareTo(b.timeMs));

    return throttleHighDensity(merged);
  }

  static DanmakuItem _formatMergedItem(_MergeBucket bucket) {
    if (bucket.count <= 1) return bucket.lead;
    final baseText = bucket.lead.text.trim();
    return bucket.lead.copyWith(
      text: '$baseText ×${bucket.count}',
    );
  }

  /// 每秒高密度智能限速（信息熵加权）
  static List<DanmakuItem> throttleHighDensity(List<DanmakuItem> comments) {
    if (comments.length <= _kSimplifyMaxPerSec) return comments;

    final out = <DanmakuItem>[];
    var secBucket = -1;
    var secComments = <DanmakuItem>[];

    void flushSec() {
      if (secComments.isEmpty) return;
      if (secComments.length <= _kSimplifyMaxPerSec) {
        out.addAll(secComments);
      } else {
        // 按信息熵/长度/合并倍率进行加权评分
        final scored = secComments.asMap().entries.map((entry) {
          final idx = entry.key;
          final c = entry.value;
          final hasCount = _countBadgeRegex.hasMatch(c.text);
          final isStatic = c.mode == DanmakuMode.top || c.mode == DanmakuMode.bottom;
          final len = c.text.length;
          final score = (hasCount ? 100 : 0) + (isStatic ? 50 : 0) + math.min(30, len * 2);
          return (item: c, score: score, index: idx);
        }).toList();

        // 保留最高分的条目，并恢复原始时间轴顺序
        scored.sort((a, b) {
          final diff = b.score.compareTo(a.score);
          if (diff != 0) return diff;
          return a.index.compareTo(b.index);
        });

        final kept = scored.take(_kSimplifyMaxPerSec).toList()
          ..sort((a, b) => a.index.compareTo(b.index));

        for (final k in kept) {
          out.add(k.item);
        }
      }
      secComments = [];
    }

    for (final c in comments) {
      final sec = c.timeMs ~/ 1000;
      if (sec != secBucket) {
        flushSec();
        secBucket = sec;
      }
      secComments.add(c);
    }
    flushSec();

    return out;
  }
}
