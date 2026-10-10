import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../source_keyword_matcher.dart';

/// 视频源持久化绑定记录项 (1:1 对齐 animaku SourceBindingEntry)
class SourceBindingEntry {
  final int bangumiId;
  final String sourceId;
  final String sourceUrl;
  final String title;
  final double? similarity;
  final int? danmakuOffset;
  final int updatedAt;

  const SourceBindingEntry({
    required this.bangumiId,
    required this.sourceId,
    required this.sourceUrl,
    required this.title,
    this.similarity,
    this.danmakuOffset,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'bangumiId': bangumiId,
        'sourceId': sourceId,
        'sourceUrl': sourceUrl,
        'title': title,
        if (similarity != null) 'similarity': similarity,
        if (danmakuOffset != null) 'danmakuOffset': danmakuOffset,
        'updatedAt': updatedAt,
      };

  factory SourceBindingEntry.fromJson(Map<String, dynamic> json) {
    return SourceBindingEntry(
      bangumiId: json['bangumiId'] as int? ?? 0,
      sourceId: json['sourceId']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      similarity: (json['similarity'] as num?)?.toDouble(),
      danmakuOffset: json['danmakuOffset'] as int?,
      updatedAt: json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 视频源历史绑定与持久化存储服务 (1:1 对齐 animaku SourceBindingStore)
/// 核心价值：
/// 1. 记忆用户在特定番剧下选择的具体视频源条目 (如选定某源的国语版/未删减版)；
/// 2. 下次播放或切源时实现 0ms 秒级直开，完全跳过网络搜索与耗时对比；
/// 3. 支持 LRU 淘汰机制，上限 1000 条。
class SourceBindingService {
  SourceBindingService._();
  static final SourceBindingService instance = SourceBindingService._();

  static const String _storageKey = 'zakoway_source_bindings_v1';
  static const int _maxBindings = 1000;

  final Map<String, SourceBindingEntry> _bindings = {};
  bool _initialized = false;

  String _makeKey(int bangumiId, String sourceId) =>
      '$bangumiId:${sourceId.toLowerCase().trim()}';

  /// 初始化并从 SharedPreferences 加载持久化缓存
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) {
              final entry = SourceBindingEntry.fromJson(Map<String, dynamic>.from(v));
              if (entry.bangumiId > 0 && entry.sourceUrl.isNotEmpty) {
                _bindings[k.toString()] = entry;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[SourceBindingService] 加载绑定记录失败: $e');
    } finally {
      _initialized = true;
    }
  }

  /// 获取指定番剧与源的绑定条目
  SourceBindingEntry? getBinding(int bangumiId, String sourceId) {
    if (bangumiId <= 0 || sourceId.isEmpty) return null;
    final key = _makeKey(bangumiId, sourceId);
    return _bindings[key];
  }

  /// 保存或更新视频源绑定条目
  Future<bool> setBinding({
    required int bangumiId,
    required String sourceId,
    required String sourceUrl,
    required String title,
    double? similarity,
    int? danmakuOffset,
    List<String>? referenceTitles,
  }) async {
    if (bangumiId <= 0 || sourceId.isEmpty || sourceUrl.trim().isEmpty) {
      return false;
    }

    double? effectiveSim = similarity;
    if (effectiveSim == null && referenceTitles != null && referenceTitles.isNotEmpty) {
      effectiveSim = SourceKeywordMatcher.bestSimilarity(title, referenceTitles);
    }

    final key = _makeKey(bangumiId, sourceId);
    final existing = _bindings[key];

    final newEntry = SourceBindingEntry(
      bangumiId: bangumiId,
      sourceId: sourceId,
      sourceUrl: sourceUrl.trim(),
      title: title.trim(),
      similarity: effectiveSim ?? existing?.similarity,
      danmakuOffset: danmakuOffset ?? existing?.danmakuOffset,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _bindings[key] = newEntry;
    _enforceLru();
    await _saveToStorage();
    return true;
  }

  /// 删除指定番剧与源的绑定 (用于播放失败或源改版时自愈)
  Future<void> removeBinding(int bangumiId, String sourceId) async {
    if (bangumiId <= 0 || sourceId.isEmpty) return;
    final key = _makeKey(bangumiId, sourceId);
    if (_bindings.remove(key) != null) {
      await _saveToStorage();
    }
  }

  /// LRU 淘汰：超过 1000 条时删除最旧记录
  void _enforceLru() {
    if (_bindings.length <= _maxBindings) return;
    final entries = _bindings.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt));
    final overflowCount = _bindings.length - _maxBindings;
    for (var i = 0; i < overflowCount; i++) {
      _bindings.remove(entries[i].key);
    }
  }

  /// 异步持久化写入
  Future<void> _saveToStorage() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final map = {for (final e in _bindings.entries) e.key: e.value.toJson()};
      await sp.setString(_storageKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[SourceBindingService] 持久化保存失败: $e');
    }
  }

  /// 清空所有绑定记录
  Future<void> clear() async {
    _bindings.clear();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_storageKey);
  }
}
