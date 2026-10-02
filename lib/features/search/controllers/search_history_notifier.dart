import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/app_preferences.dart';

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(
  SearchHistoryNotifier.new,
);

/// 搜索历史记录状态管理器（遵循 Animaku 规范：上限 15 条，去重置顶，支持单删与全量清空，本地持久化）
class SearchHistoryNotifier extends Notifier<List<String>> {
  static const int maxHistoryItems = 15;

  @override
  List<String> build() {
    return AppPreferences.getSearchHistory();
  }

  /// 添加/更新一条搜索关键词（置顶、去重并限制条数）
  Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final next = [
      trimmed,
      ...state.where((item) => item != trimmed),
    ];
    final limited = next.length > maxHistoryItems
        ? next.sublist(0, maxHistoryItems)
        : next;

    state = limited;
    await AppPreferences.saveSearchHistory(limited);
  }

  /// 删除单条历史搜索词
  Future<void> removeSearch(String query) async {
    final next = state.where((item) => item != query).toList();
    state = next;
    await AppPreferences.saveSearchHistory(next);
  }

  /// 清空全部搜索历史
  Future<void> clearAll() async {
    state = const [];
    await AppPreferences.saveSearchHistory(const []);
  }
}
