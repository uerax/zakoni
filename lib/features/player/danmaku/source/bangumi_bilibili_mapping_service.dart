import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bangumi_bilibili_preset_data.dart';

/// 跨站番剧关联服务 (1:1 对齐 animaku bangumi-data.ts)
/// 负责将 Bangumi.tv 条目 ID 转换为 Bilibili 对应标识 (media_id / season_id / ep / BV)
class BangumiBilibiliMappingService {
  BangumiBilibiliMappingService._();
  static final BangumiBilibiliMappingService instance = BangumiBilibiliMappingService._();

  static const String _kStorageKey = 'zakoway_bgm_bili_mapping_v1';
  static const String _kLastSyncKey = 'zakoway_bgm_bili_last_sync_v1';
  static const int _kSyncIntervalMs = 7 * 24 * 60 * 60 * 1000; // 7 天周期

  static const List<String> _kCdnUrls = [
    'https://cdn.jsdelivr.net/npm/bangumi-data@latest/dist/data.json',
    'https://unpkg.com/bangumi-data@latest/dist/data.json',
    'https://raw.githubusercontent.com/bangumi-data/bangumi-data/master/dist/data.json',
  ];

  final Map<int, String> _dynamicMemoryMap = {};
  bool _initialized = false;
  bool _isSyncing = false;

  /// 初始化本地存储增量并按需触发后台同步
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            final bgmId = int.tryParse(k.toString());
            if (bgmId != null && v != null) {
              _dynamicMemoryMap[bgmId] = v.toString();
            }
          });
        }
      }

      final lastSync = sp.getInt(_kLastSyncKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - lastSync > _kSyncIntervalMs) {
        syncRemoteInBackground().ignore();
      }
    } catch (e) {
      developer.log('[MappingService] 初始化失败: $e');
    } finally {
      _initialized = true;
    }
  }

  /// 根据 Bangumi ID 获取 Bilibili 目标标识 (O(1) 复杂度)
  Future<String?> getBilibiliTargetId(int bangumiId) async {
    if (bangumiId <= 0) return null;
    if (!_initialized) {
      await initialize();
    }

    // 1. 优先查动态更新的增量字典
    final dynamicHit = _dynamicMemoryMap[bangumiId];
    if (dynamicHit != null && dynamicHit.isNotEmpty) {
      return dynamicHit;
    }

    // 2. 查内置预置的 3300+ 条番剧映射字典 (0ms 秒出)
    final presetHit = kPresetBangumiBilibiliMap[bangumiId];
    if (presetHit != null && presetHit.isNotEmpty) {
      return presetHit;
    }

    return null;
  }

  /// 后台非阻塞拉取最新 bangumi-data 同步新番映射
  Future<void> syncRemoteInBackground() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final dio = Dio();
    try {
      developer.log('[MappingService] 开始增量同步远程 bangumi-data 映射库...');
      Map<String, dynamic>? rawJson;

      for (final url in _kCdnUrls) {
        try {
          final res = await dio.get<Map<String, dynamic>>(
            url,
            options: Options(
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
            ),
          );
          if (res.data != null && res.data!['items'] is List) {
            rawJson = res.data;
            break;
          }
        } catch (_) {}
      }

      if (rawJson == null) return;
      final rawItems = rawJson['items'] as List<dynamic>? ?? const [];
      final newEntries = <int, String>{};

      for (final item in rawItems) {
        if (item is! Map<String, dynamic>) continue;
        final rawSites = item['sites'] as List<dynamic>? ?? const [];
        int bgmId = 0;
        String? biliId;

        for (final s in rawSites) {
          if (s is! Map<String, dynamic>) continue;
          final siteName = s['site']?.toString();
          final idStr = s['id']?.toString();
          if (siteName == 'bangumi' && idStr != null) {
            bgmId = int.tryParse(idStr) ?? 0;
          } else if (siteName == 'bilibili' && idStr != null && idStr.isNotEmpty) {
            biliId = idStr;
          } else if (siteName == 'bilibili_hk_mo_tw' && idStr != null && idStr.isNotEmpty && biliId == null) {
            biliId = idStr;
          }
        }

        if (bgmId > 0 && biliId != null && biliId.isNotEmpty) {
          newEntries[bgmId] = biliId;
        }
      }

      if (newEntries.isNotEmpty) {
        _dynamicMemoryMap.addAll(newEntries);
        final sp = await SharedPreferences.getInstance();
        final stringKeyMap = {for (final e in _dynamicMemoryMap.entries) e.key.toString(): e.value};
        await sp.setString(_kStorageKey, jsonEncode(stringKeyMap));
        await sp.setInt(_kLastSyncKey, DateTime.now().millisecondsSinceEpoch);
        developer.log('[MappingService] 映射库同步完成，当前动态收录总数: ${_dynamicMemoryMap.length}');
      }
    } catch (e) {
      developer.log('[MappingService] 同步异常: $e');
    } finally {
      dio.close();
      _isSyncing = false;
    }
  }
}
