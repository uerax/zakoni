import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../danmaku/models/danmaku_item.dart';

/// 播放器用户偏好设置持久化服务
/// 记录上次的播放倍速、音量与弹幕外观偏好，应用重启后保持记忆
class PlayerPreferencesService extends ChangeNotifier {
  PlayerPreferencesService._();
  static final PlayerPreferencesService instance = PlayerPreferencesService._();

  static const String _kPlaybackRateKey = 'zakoni_player_playback_rate';
  static const String _kVolumeKey = 'zakoni_player_volume';
  static const String _kDanmakuSettingsKey = 'zakoni_player_danmaku_settings';

  double _playbackRate = 1.0;
  double _volume = 1.0;
  DanmakuSettings _danmakuSettings = const DanmakuSettings();
  bool _initialized = false;

  double get playbackRate => _playbackRate;
  double get volume => _volume;
  DanmakuSettings get danmakuSettings => _danmakuSettings;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final sp = await SharedPreferences.getInstance();
      _playbackRate = sp.getDouble(_kPlaybackRateKey) ?? 1.0;
      _volume = sp.getDouble(_kVolumeKey) ?? 1.0;

      final danmakuRaw = sp.getString(_kDanmakuSettingsKey);
      if (danmakuRaw != null && danmakuRaw.isNotEmpty) {
        final decoded = jsonDecode(danmakuRaw);
        if (decoded is Map<String, dynamic>) {
          _danmakuSettings = DanmakuSettings.fromJson(decoded);
        }
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  Future<void> savePlaybackRate(double rate) async {
    if ((_playbackRate - rate).abs() < 0.01) return;
    _playbackRate = rate;
    notifyListeners();

    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(_kPlaybackRateKey, rate);
    } catch (_) {}
  }

  Future<void> saveVolume(double vol) async {
    if ((_volume - vol).abs() < 0.01) return;
    _volume = vol;
    notifyListeners();

    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(_kVolumeKey, vol);
    } catch (_) {}
  }

  Future<void> saveDanmakuSettings(DanmakuSettings settings) async {
    _danmakuSettings = settings;
    notifyListeners();

    try {
      final sp = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(settings.toJson());
      await sp.setString(_kDanmakuSettingsKey, jsonStr);
    } catch (_) {}
  }
}
