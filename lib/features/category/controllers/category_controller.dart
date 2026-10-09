import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/bangumi_providers.dart';
import '../../../core/utils/responsive.dart';
import '../models/category_constants.dart';
import 'category_state.dart';

final categoryControllerProvider = NotifierProvider
    .family<CategoryController, CategoryState, CategoryInitialArgs?>(
  CategoryController.new,
);

class CategoryController extends Notifier<CategoryState> {
  final CategoryInitialArgs? initialArgs;
  int _requestSeq = 0;
  CancelToken? _cancelToken;
  Timer? _debounceTimer;
  bool _isDisposed = false;
  bool _hasStartedInitialFetch = false;

  CategoryController([this.initialArgs]);

  @override
  CategoryState build() {
    _isDisposed = false;
    _hasStartedInitialFetch = false;
    ref.onDispose(() {
      _isDisposed = true;
      _debounceTimer?.cancel();
      _cancelToken?.cancel('notifier_disposed');
    });

    final filter = CategoryFilter.fromInitial(initialArgs);
    // 工业级标准：初始状态只负责渲染极轻量静态骨架屏，绝不自动发起任何网络请求，
    // 杜绝冷启动与页面切换动画期间并发抢占 CPU 与带宽
    return CategoryState(filter: filter, isLoading: true);
  }

  /// 确保首次数据加载（仅在页面真正进入可视区或切换到位后按需调用）
  void ensureLoaded() {
    if (_hasStartedInitialFetch && (state.items.isNotEmpty || !state.isLoading)) return;
    _hasStartedInitialFetch = true;
    fetchFirstPage();
  }

  /// 根据当前运行端型（手机 12 / 平板 20 / 桌面 24）动态计算单页最优请求量
  int get _effectivePageSize {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view != null) {
        final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
        return AppBreakpoints.responsivePageSize(logicalWidth);
      }
    } catch (_) {}
    return CategoryConstants.pageSize;
  }

  /// 构建当前筛选条件的日期与参数，向 Bangumi 发起第一页请求
  /// 若本地已有缓存，则 0ms 同步秒出，彻底消除骨架屏闪烁
  Future<void> fetchFirstPage({bool forceRefresh = false}) async {
    final seq = ++_requestSeq;

    // 核心工程优化：若前序请求仍在网络线路上飞行，立即执行物理级 CancelToken 熔断，
    // 释放客户端 Socket 与带宽，确保新选中的标签享有 100% 独立带宽
    _cancelToken?.cancel('filter_changed');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    final filter = state.filter;
    final tagList = filter.allTags;
    final limit = _effectivePageSize;

    List<String>? airDate;
    int? yearParam;

    if (filter.selectedMonth != null && filter.selectedMonth! > 0) {
      final targetYear = filter.selectedYear ?? CategoryConstants.currentYear;
      yearParam = targetYear;
      airDate = CategoryConstants.seasonAirDate(targetYear, filter.selectedMonth!);
    } else if (filter.selectedYear != null) {
      yearParam = filter.selectedYear;
    }

    final client = ref.read(bangumiClientProvider);

    // 1. 若命中未过期缓存且非下拉强制刷新，直接 0ms 瞬间切换出新数据，不闪骨架屏
    if (!forceRefresh) {
      final cached = client.peekSearchCache(
        '',
        tags: tagList,
        year: yearParam,
        airDate: airDate,
        sort: filter.selectedSort,
        limit: limit,
        offset: 0,
      );
      if (cached != null) {
        state = state.copyWith(
          items: cached.items,
          total: cached.total,
          hasMore: cached.hasMore,
          isLoading: false,
          errorMessage: null,
        );
        return;
      }
    }

    // 2. 关键体验优化（平滑过渡）：未命中缓存时坚决保留现有 items，绝不物理清空，
    // 仅在非加载状态时标记 isLoading，避免初始状态下重复广播变更导致全页多余重构
    if (!state.isLoading) {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
      );
    }

    try {
      final result = await client.searchWithTotal(
        '',
        tags: tagList,
        year: yearParam,
        airDate: airDate,
        sort: filter.selectedSort,
        limit: limit,
        offset: 0,
        forceRefresh: forceRefresh,
        cancelToken: cancelToken,
      );

      if (_isDisposed || cancelToken.isCancelled || seq != _requestSeq) return;

      state = state.copyWith(
        items: result.items,
        total: result.total,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      if (_isDisposed || cancelToken.isCancelled || seq != _requestSeq) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 筛选微防抖调度器：
  /// 1. 优先同步探测本地内存缓存：若已命中缓存则 0ms 同步秒切，无任何迟滞感；
  /// 2. 未命中缓存时，施加 180ms 轻量防抖，防止用户连续快速切换筛选时并发向 Bangumi 发送无谓的重叠请求。
  void _triggerFetchWithDebounce({Duration delay = const Duration(milliseconds: 180)}) {
    _debounceTimer?.cancel();

    final filter = state.filter;
    final tagList = filter.allTags;

    List<String>? airDate;
    int? yearParam;

    if (filter.selectedMonth != null && filter.selectedMonth! > 0) {
      final targetYear = filter.selectedYear ?? CategoryConstants.currentYear;
      yearParam = targetYear;
      airDate = CategoryConstants.seasonAirDate(targetYear, filter.selectedMonth!);
    } else if (filter.selectedYear != null) {
      yearParam = filter.selectedYear;
    }

    final client = ref.read(bangumiClientProvider);
    final limit = _effectivePageSize;
    final cached = client.peekSearchCache(
      '',
      tags: tagList,
      year: yearParam,
      airDate: airDate,
      sort: filter.selectedSort,
      limit: limit,
      offset: 0,
    );

    if (cached != null) {
      _cancelToken?.cancel('filter_changed');
      state = state.copyWith(
        items: cached.items,
        total: cached.total,
        hasMore: cached.hasMore,
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    // 未命中缓存：立即进入平滑过渡态，保留当前数据不白屏
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    if (delay <= Duration.zero) {
      fetchFirstPage();
    } else {
      _debounceTimer = Timer(delay, () {
        if (_isDisposed) return;
        fetchFirstPage();
      });
    }
  }

  /// 滚动触底加载下一页数据
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final filter = state.filter;
      final tagList = filter.allTags;

      List<String>? airDate;
      int? yearParam;

      if (filter.selectedMonth != null && filter.selectedMonth! > 0) {
        final targetYear = filter.selectedYear ?? CategoryConstants.currentYear;
        yearParam = targetYear;
        airDate = CategoryConstants.seasonAirDate(targetYear, filter.selectedMonth!);
      } else if (filter.selectedYear != null) {
        yearParam = filter.selectedYear;
      }

      final client = ref.read(bangumiClientProvider);
      final limit = _effectivePageSize;
      final result = await client.searchWithTotal(
        '',
        tags: tagList,
        year: yearParam,
        airDate: airDate,
        sort: filter.selectedSort,
        limit: limit,
        offset: state.items.length,
      );

      if (_isDisposed) return;

      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// 批量更新已选标签集合（包含类型与题材，弹窗关闭或点击完成时统一调用一次，杜绝多选过程中的频繁请求）
  void setTags(Set<String> tags) {
    if (setEquals(state.filter.selectedTags, tags)) return;
    state = state.copyWith(
      filter: state.filter.copyWith(selectedTags: Set<String>.from(tags)),
      isTagExpanded: false,
    );
    _triggerFetchWithDebounce(delay: Duration.zero);
  }

  /// 切换单个标签勾选状态（无单选限制）
  void toggleTag(String tag) {
    final cur = Set<String>.from(state.filter.selectedTags);
    if (cur.contains(tag)) {
      cur.remove(tag);
    } else {
      cur.add(tag);
    }
    setTags(cur);
  }

  /// 清空所有标签
  void clearTags() {
    if (state.filter.selectedTags.isEmpty) return;
    setTags(const {});
  }

  /// 切换形式分类（支持多选，传 '全部' 时仅清空当前形式类型）
  void setType(String? type) {
    if (type == null || type == '全部') {
      final cur = Set<String>.from(state.filter.selectedTags)
        ..removeWhere((t) => CategoryConstants.mediaTypes.contains(t));
      setTags(cur);
    } else {
      toggleTag(type);
    }
  }

  /// 批量更新题材多选集合
  void setGenres(Set<String> genres) {
    final mediaTypes = state.filter.selectedTags.where((t) => CategoryConstants.mediaTypes.contains(t));
    setTags({...mediaTypes, ...genres});
  }

  /// 切换单个题材分类
  void toggleGenre(String genre) => toggleTag(genre);

  /// 清空所有已选题材（保留已选的形式类型）
  void clearGenres() {
    final mediaTypes = state.filter.selectedTags.where((t) => CategoryConstants.mediaTypes.contains(t)).toSet();
    setTags(mediaTypes);
  }

  /// 兼容旧版单一 tag 访问
  void setTag(String? tag) {
    if (tag == null || tag == '全部') {
      clearTags();
    } else {
      setTags({tag});
    }
  }

  void setYear(int? year) {
    if (state.filter.selectedYear == year) return;
    state = state.copyWith(
      filter: state.filter.copyWith(selectedYear: year),
    );
    _triggerFetchWithDebounce();
  }

  void setMonth(int? month) {
    final targetMonth = (month == null || month == 0) ? null : month;
    if (state.filter.selectedMonth == targetMonth) return;

    int? newYear = state.filter.selectedYear;
    // 友好联动：若此前为“全部年份”，点击具体季度自动对齐到今年
    if (targetMonth != null && newYear == null) {
      newYear = CategoryConstants.currentYear;
    }

    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedMonth: targetMonth,
        selectedYear: newYear,
      ),
    );
    _triggerFetchWithDebounce();
  }

  void setSort(String sort) {
    if (state.filter.selectedSort == sort) return;
    state = state.copyWith(
      filter: state.filter.copyWith(selectedSort: sort),
    );
    _triggerFetchWithDebounce();
  }

  void toggleTagExpanded([bool? expanded]) {
    state = state.copyWith(
      isTagExpanded: expanded ?? !state.isTagExpanded,
    );
  }

  /// 一键复位至“当季新番”
  void resetToCurrentSeason() {
    if (state.filter.isCurrentSeason) return;
    state = state.copyWith(
      filter: state.filter.copyWith(
        selectedTags: const {},
        selectedYear: CategoryConstants.currentYear,
        selectedMonth: CategoryConstants.currentSeasonMonth,
        selectedSort: 'heat',
      ),
      isTagExpanded: false,
    );
    _triggerFetchWithDebounce(delay: Duration.zero);
  }

  /// 复原到初始默认选项（若有初始参数则恢复该分类与年月，否则复原为当季新番默认选项）
  void resetToDefault() {
    if (state.filter.isDefaultState) return;
    state = state.copyWith(
      filter: CategoryFilter.fromInitial(initialArgs),
      isTagExpanded: false,
    );
    _triggerFetchWithDebounce(delay: Duration.zero);
  }
}
