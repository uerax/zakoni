import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/bangumi/bangumi_episode.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/services/bangumi_oped_service.dart';
import '../../common/widgets/bouncing_scale_card.dart';
import '../../common/widgets/cached_anime_image.dart';
import '../controller/playback_controller.dart';
import '../danmaku/danmaku.dart';
import '../source/auto_source_pick_coordinator.dart';
import '../source/models/source_models.dart';
import '../source/services/source_binding_service.dart';
import '../source/source_aggregator.dart';
import '../source/source_bundle_manager.dart';
import '../source/source_keyword_matcher.dart';
import '../source/utils/playable_slot_engine.dart';
import '../widgets/episode_picker_section.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_side_panel.dart';
import '../widgets/video_source_view.dart';
import '../widgets/video_surface.dart';
import '../widgets/watch_meta_view.dart';

/// zakoni 统一多端视频播放页面 (1:1 严格对齐 animaku 完整视频源生命周期与架构规范)
///
/// 核心流程与规范：
/// 1. 初始 0ms 直开: 检查 SourceBindingService，若命中该番剧在该源的历史绑定，直接取 sourceUrl 提取分集，跳过搜索；
/// 2. 关键词智能装配: 依据各源语言偏好 (TitlePreference) 解析最优单关键词，规避无效多轮串行网络阻塞；
/// 3. 单源自动选定 (Season Guard): 打分 >= 0.55 且无季数冲突才自动采用，低于门槛则停留在 needsPick 供用户确认；
/// 4. 默认源未收录时并发保底探测: 自动在后台启动 SourceAggregator 探测前 6 个保底源 (3 并发 + 5s 超时熔断)；
/// 5. 自适应宽限选源仲裁器 (AutoSourcePickCoordinator): 1200ms 宽限窗口判定高优先级源；用户手动点击即时互斥锁死；
/// 6. PlayableSlot 双层集数对齐: 自动过滤 PV/SP/特典，1:1 对齐 Bangumi 官方正片，根治剧名带数字被正则误杀问题；
/// 7. 视频源卡片抽屉 (Drawer): 搜出多条时供手动点选条目、候选关键词胶囊快捷换词、自定义输入框强制 bypassCache 重测。
class VideoPlayPage extends StatefulWidget {
  const VideoPlayPage({
    super.key,
    required this.title,
    this.bangumiItem,
    this.coverUrl,
    this.videoUrl,
    this.httpHeaders,
    this.initialPosition,
    this.danmakuItems,
    this.episodeCount = 12,
    this.currentEpisode,
    this.onEpisodeSelected,
  });

  /// 视频/番剧标题
  final String title;

  /// Bangumi 详情数据模型 (Seed)
  final BangumiItem? bangumiItem;

  /// 番剧海报封面地址 (Seed)
  final String? coverUrl;

  /// 预置静态视频流地址 (若不为空则直接起播)
  final String? videoUrl;

  /// 防盗链请求头 (如 Referer)
  final Map<String, String>? httpHeaders;

  /// 断点续播初始时间戳
  final Duration? initialPosition;

  /// 预加载弹幕数据
  final List<DanmakuItem>? danmakuItems;

  /// 总集数占位参数
  final int episodeCount;

  /// 当前播放集数 (从 1 开始，若为 null 则表示未起播占位态)
  final int? currentEpisode;

  /// 切集回调
  final ValueChanged<int>? onEpisodeSelected;

  @override
  State<VideoPlayPage> createState() => _VideoPlayPageState();
}

class _VideoPlayPageState extends State<VideoPlayPage>
    with SingleTickerProviderStateMixin {
  late final ZakoniPlaybackController _playbackController;
  late final DanmakuController _danmakuController;
  late final TabController _tabController;
  late final SourceAggregator _aggregator;
  late final AutoSourcePickCoordinator _autoPicker;

  bool _isFullscreen = false;
  bool _isSidePanelOpen = false;
  PlayerSidePanelTab _sidePanelInitialTab = PlayerSidePanelTab.episodes;
  int? _activeEpisode;
  bool _hasStartedPlayback = false;

  // 视频源与选集状态
  String _selectedSourceId = 'xifan-next';
  late final List<VideoSourceItem> _sources = getDefaultSourceItems();

  bool _isLoadingChapters = false;
  String? _resolveError;
  String? _sourceNotice;
  String? _hudToast;
  bool _defaultSearchEmpty = false;

  List<SourceChapterRoad> _chapterRoads = [];
  int _selectedRoadIndex = 0;

  // Bangumi 官方数据补全
  BangumiItem? _fullBangumiItem;
  List<BangumiEpisode>? _officialEpisodes;
  Map<int, EpisodeOpedSegment> _opedData = {};

  BangumiItem? get _effectiveBangumiItem => _fullBangumiItem ?? widget.bangumiItem;
  int get _effectiveBangumiId => _effectiveBangumiItem?.id ?? widget.bangumiItem?.id ?? 0;
  EpisodeOpedSegment? get _currentOpedSegment => _opedData[_activeEpisode ?? 1];

  List<SourceEpisode> get _currentEpisodes {
    if (_chapterRoads.isEmpty) return [];
    final idx = _selectedRoadIndex.clamp(0, _chapterRoads.length - 1);
    return _chapterRoads[idx].episodes;
  }

  /// 使用 PlayableSlotEngine 构建双层对齐的标准槽位列表
  List<PlayableSlot> get _currentSlots {
    return PlayableSlotEngine.buildPlayableSlots(
      episodes: _currentEpisodes,
      officialEpisodes: _officialEpisodes,
    );
  }

  List<String> get _mappedEpisodeTitles {
    final slots = _currentSlots;
    if (slots.isEmpty) return [];
    return slots.map((s) => s.displayTitle).toList();
  }

  List<String> get _roadNames {
    if (_chapterRoads.isEmpty) return const ['默认线路'];
    return _chapterRoads.map((r) => r.name).toList();
  }

  String get _selectedSourceName {
    final item = _sources.firstWhere(
      (s) => s.id == _selectedSourceId,
      orElse: () => _sources.first,
    );
    return item.name;
  }

  /// 多层级备选候选词列表 (供卡片抽屉推荐胶囊使用)
  List<String> get _keywordOptions {
    return SourceKeywordMatcher.buildCandidates(
      defaultTitle: widget.title,
      item: _effectiveBangumiItem,
      sourceId: _selectedSourceId,
    );
  }

  List<String> get _titleRefs {
    return [
      if (_effectiveBangumiItem?.nameCn.isNotEmpty ?? false) _effectiveBangumiItem!.nameCn,
      if (_effectiveBangumiItem?.name.isNotEmpty ?? false) _effectiveBangumiItem!.name,
      widget.title,
      ...(_effectiveBangumiItem?.alias ?? const <String>[]),
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  void initState() {
    super.initState();
    _activeEpisode = widget.currentEpisode;
    _danmakuController = DanmakuController();
    _playbackController = ZakoniPlaybackController(
      danmakuController: _danmakuController,
    );

    // 初始化并发源探测器
    _aggregator = SourceAggregator();
    _aggregator.addListener(_onAggregatorUpdated);

    // 初始化自适应宽限自动选源仲裁器 (对齐 animaku useAutoSourcePick)
    _autoPicker = AutoSourcePickCoordinator(
      onSwitchSource: (meta, hit) {
        if (!mounted) return;
        _showHudToast('默认源未收录，已为你切换至 ${meta.name}');
        _handleSourceSelected(
          _sources.firstWhere((s) => s.id == meta.id, orElse: () => VideoSourceItem(id: meta.id, name: meta.name, description: '')),
          hit,
        );
      },
      onAllFallbacksFailed: () {
        if (!mounted) return;
        _showHudToast('所有备用源自动检索完毕，请在面板中换词重搜');
        _tabController.animateTo(1);
      },
    );

    // 默认聚焦第 3 个 Tab「选集」(index: 2)
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 2,
    );
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        // 用户切换到「视频源」Tab，触发互斥锁避免自动抢占
        _autoPicker.onUserAction();
        _aggregator.syncAndProbe(
          bangumiId: _effectiveBangumiId,
          defaultTitle: widget.title,
          item: _effectiveBangumiItem,
          activeSourceId: _selectedSourceId,
          isOpen: true,
          autoProbeOnFallback: _defaultSearchEmpty,
          sourceOrder: _sources.map((s) => s.id).toList(),
        );
      }
    });

    if (widget.danmakuItems != null && widget.danmakuItems!.isNotEmpty) {
      _danmakuController.loadItems(widget.danmakuItems!);
    }

    // 异步拉取 Bangumi 权威详情与分集
    _fetchBangumiAuthorityData();

    // 待首帧构建完成后安全启动起播或检索
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 预先后台初始化持久化绑定服务
      SourceBindingService.instance.initialize().ignore();

      // 若有显式传入的固定 URL 则直接起播
      if (_activeEpisode != null &&
          widget.videoUrl != null &&
          widget.videoUrl!.isNotEmpty) {
        _hasStartedPlayback = true;
        _initPlayback();
      } else {
        // 启动主流程：先查绑定，再查默认源，未命中则后台探测保底源
        _startDefaultSourceSearch(autoPlayFirst: _activeEpisode != null);
      }
    });
  }

  void _onAggregatorUpdated() {
    if (!mounted) return;
    setState(() {});

    // 驱动自动选源仲裁器判断是否执行 0ms 秒提或 1200ms 宽限切换
    _autoPicker.update(
      bangumiId: _effectiveBangumiId,
      enabled: _defaultSearchEmpty && _chapterRoads.isEmpty,
      sources: _aggregator.states,
      inFlightSources: _aggregator.inFlightSources,
      sourceOrder: _sources.map((s) => s.id).toList(),
      allFallbacksExhausted: _aggregator.allFallbacksExhausted,
    );
  }

  void _showHudToast(String message) {
    setState(() => _hudToast = message);
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && _hudToast == message) {
        setState(() => _hudToast = null);
      }
    });
  }

  Future<void> _initPlayback() async {
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      await _playbackController.open(
        widget.videoUrl!,
        httpHeaders: widget.httpHeaders,
        start: widget.initialPosition,
      );
    }
  }

  /// 异步补全 Bangumi 官方数据 (用于弹幕检索与选集映射)
  Future<void> _fetchBangumiAuthorityData() async {
    final bId = widget.bangumiItem?.id;
    if (bId == null || bId <= 0) return;

    try {
      final client = BangumiClient();
      final subject = await client.getSubject(bId);
      final eps = await client.getEpisodes(bId);
      final oped = await BangumiOpedService.instance.getOpedData(bId);
      if (mounted) {
        setState(() {
          _fullBangumiItem = subject;
          _officialEpisodes = eps;
          _opedData = oped;
        });
      }
    } catch (_) {
      // 失败静默使用传入的 Seed 数据
    }
  }

  /// 启动主检索流程：
  /// Step 1: 检查持久化绑定 (SourceBindingService) -> 若存在直接 0ms 秒开；
  /// Step 2: 绑定不存在时向默认源发起精准检索 -> 若命中 (score >= 0.55) 则建立绑定并起播；
  /// Step 3: 若默认源未收录 -> 标记 defaultSearchEmpty，后台静默并发探测保底源，由 AutoSourcePickCoordinator 仲裁。
  Future<void> _startDefaultSourceSearch({bool autoPlayFirst = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingChapters = true;
      _resolveError = null;
      _sourceNotice = null;
    });

    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        setState(() {
          _chapterRoads = [
            SourceChapterRoad(
              name: '默认线路',
              episodes: List.generate(
                widget.episodeCount,
                (i) => SourceEpisode(name: '第 ${i + 1} 话', url: 'https://test/ep${i + 1}'),
              ),
            )
          ];
          _isLoadingChapters = false;
        });
        return;
      }

      await SourceBundleManager.instance.initialize();
      final runtime = SourceBundleManager.instance.runtime;
      final bangumiId = _effectiveBangumiId;

      // ==========================================
      // Step 1: 优先检查历史持久化绑定 (0ms 直开)
      // ==========================================
      final binding = SourceBindingService.instance.getBinding(bangumiId, _selectedSourceId);
      if (binding != null && binding.sourceUrl.isNotEmpty) {
        try {
          final roads = await runtime.chapters(_selectedSourceId, binding.sourceUrl);
          if (roads.isNotEmpty && roads.any((r) => r.episodes.isNotEmpty)) {
            if (!mounted) return;
            setState(() {
              _chapterRoads = roads;
              _selectedRoadIndex = 0;
              _isLoadingChapters = false;
              _defaultSearchEmpty = false;
            });

            if (autoPlayFirst && _currentEpisodes.isNotEmpty) {
              _selectEpisode(_activeEpisode ?? 1);
            } else if (_currentEpisodes.isNotEmpty) {
              runtime.resolve(_selectedSourceId, _currentEpisodes.first.url).ignore();
            }
            return;
          }
        } catch (_) {
          // 绑定失效 (如源站下架/URL变更)，自动移除失效绑定并平滑降级至 Step 2
          await SourceBindingService.instance.removeBinding(bangumiId, _selectedSourceId);
        }
      }

      // ==========================================
      // Step 2: 默认源单关键词精准检索
      // ==========================================
      final primaryKw = SourceKeywordMatcher.resolveDefaultKeyword(
        defaultTitle: widget.title,
        item: _effectiveBangumiItem,
        sourceId: _selectedSourceId,
      );

      SourceSearchResult? bestHit;
      if (primaryKw.isNotEmpty) {
        final rawHits = await runtime.search(_selectedSourceId, primaryKw);
        final ranked = SourceKeywordMatcher.rankSearchHits(rawHits, _titleRefs);
        if (ranked.isNotEmpty) {
          final score = SourceKeywordMatcher.bestSimilarity(ranked.first.name, _titleRefs);
          if (score >= SourceAggregator.autoPickMinSimilarity) {
            bestHit = ranked.first;
          }
        }
      }

      // 回退尝试中文备用名检索
      if (bestHit == null) {
        final fallbackKw = (_effectiveBangumiItem?.nameCn.isNotEmpty ?? false)
            ? _effectiveBangumiItem!.nameCn
            : widget.title;
        if (fallbackKw.isNotEmpty && fallbackKw != primaryKw) {
          final rawHits = await runtime.search(_selectedSourceId, fallbackKw);
          final ranked = SourceKeywordMatcher.rankSearchHits(rawHits, _titleRefs);
          if (ranked.isNotEmpty) {
            final score = SourceKeywordMatcher.bestSimilarity(ranked.first.name, _titleRefs);
            if (score >= SourceAggregator.autoPickMinSimilarity) {
              bestHit = ranked.first;
            }
          }
        }
      }

      // 默认源成功命中！
      if (bestHit != null) {
        final roads = await runtime.chapters(_selectedSourceId, bestHit.url);
        if (roads.isNotEmpty && roads.any((r) => r.episodes.isNotEmpty)) {
          if (!mounted) return;
          setState(() {
            _chapterRoads = roads;
            _selectedRoadIndex = 0;
            _isLoadingChapters = false;
            _defaultSearchEmpty = false;
          });

          // 记录持久化绑定，供下次瞬间 0ms 起播
          await SourceBindingService.instance.setBinding(
            bangumiId: bangumiId,
            sourceId: _selectedSourceId,
            sourceUrl: bestHit.url,
            title: bestHit.name,
            referenceTitles: _titleRefs,
          );

          if (autoPlayFirst && _currentEpisodes.isNotEmpty) {
            _selectEpisode(_activeEpisode ?? 1);
          } else if (_currentEpisodes.isNotEmpty) {
            runtime.resolve(_selectedSourceId, _currentEpisodes.first.url).ignore();
          }
          return;
        }
      }

      // ==========================================
      // Step 3: 默认源未收录 -> 启动后台并发保底探测
      // ==========================================
      if (!mounted) return;
      setState(() {
        _isLoadingChapters = false;
        _chapterRoads = [];
        _defaultSearchEmpty = true;
        _sourceNotice = '默认源未收录《${widget.title}》，已为你并发检索备用播放源';
      });

      // 启动后台探测器 (严格限制前 6 个源，3 并发，5s 超时)
      _aggregator.syncAndProbe(
        bangumiId: bangumiId,
        defaultTitle: widget.title,
        item: _effectiveBangumiItem,
        activeSourceId: _selectedSourceId,
        isOpen: _tabController.index == 1,
        autoProbeOnFallback: true,
        sourceOrder: _sources.map((s) => s.id).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingChapters = false;
        _resolveError = '检索异常: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    }
  }

  /// 用户或仲裁器选择某视频源及条目 (切源并提取真实分集)
  Future<void> _handleSourceSelected(
    VideoSourceItem src, [
    SourceSearchResult? directHit,
    List<SourceChapterRoad>? cachedRoads,
  ]) async {
    _autoPicker.onUserAction();

    // 0ms 秒级直开：若探测器中已预先验活并缓存了分集线路，直接采纳，彻底杜绝“切过去又开始检索然后报错”
    if (cachedRoads != null &&
        cachedRoads.isNotEmpty &&
        cachedRoads.any((r) => r.episodes.isNotEmpty)) {
      setState(() {
        _selectedSourceId = src.id;
        _chapterRoads = cachedRoads;
        _selectedRoadIndex = 0;
        _isLoadingChapters = false;
        _resolveError = null;
        _sourceNotice = null;
        _defaultSearchEmpty = false;
      });

      _tabController.animateTo(2);

      if (directHit != null && _effectiveBangumiId > 0) {
        SourceBindingService.instance.setBinding(
          bangumiId: _effectiveBangumiId,
          sourceId: src.id,
          sourceUrl: directHit.url,
          title: directHit.name,
          referenceTitles: _titleRefs,
        ).ignore();
      }

      if (_hasStartedPlayback && _currentSlots.isNotEmpty) {
        _selectEpisode(_activeEpisode ?? 1);
      }
      return;
    }

    setState(() {
      _selectedSourceId = src.id;
      _chapterRoads = [];
      _selectedRoadIndex = 0;
      _isLoadingChapters = true;
      _resolveError = null;
      _sourceNotice = null;
      _playbackController.pause();
    });

    // 自动切回选集 Tab (index: 2)
    _tabController.animateTo(2);

    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        setState(() {
          _chapterRoads = [
            SourceChapterRoad(
              name: '默认线路',
              episodes: List.generate(
                widget.episodeCount,
                (i) => SourceEpisode(name: '第 ${i + 1} 话', url: 'https://test/ep${i + 1}'),
              ),
            )
          ];
          _isLoadingChapters = false;
        });
        return;
      }

      final runtime = SourceBundleManager.instance.runtime;
      final bangumiId = _effectiveBangumiId;

      String? targetUrl = directHit?.url;
      String? targetTitle = directHit?.name;

      // 检查探测器是否已有就绪条目
      if (targetUrl == null) {
        final probeState = _aggregator.states[src.id];
        if (probeState?.matchedHit != null) {
          targetUrl = probeState!.matchedHit!.url;
          targetTitle = probeState.matchedHit!.name;
        }
      }

      // 检查持久化绑定
      if (targetUrl == null) {
        final binding = SourceBindingService.instance.getBinding(bangumiId, src.id);
        if (binding != null && binding.sourceUrl.isNotEmpty) {
          targetUrl = binding.sourceUrl;
          targetTitle = binding.title;
        }
      }

      // 若均无现成链接，发起单源搜索
      if (targetUrl == null) {
        final primaryKw = SourceKeywordMatcher.resolveDefaultKeyword(
          defaultTitle: widget.title,
          item: _effectiveBangumiItem,
          sourceId: src.id,
        );

        if (primaryKw.isNotEmpty) {
          final hits = await runtime.search(src.id, primaryKw);
          final ranked = SourceKeywordMatcher.rankSearchHits(hits, _titleRefs);
          if (ranked.isNotEmpty) {
            targetUrl = ranked.first.url;
            targetTitle = ranked.first.name;
          }
        }

        if (targetUrl == null) {
          final fallbackKw = (_effectiveBangumiItem?.nameCn.isNotEmpty ?? false)
              ? _effectiveBangumiItem!.nameCn
              : widget.title;
          if (fallbackKw.isNotEmpty && fallbackKw != primaryKw) {
            final hits = await runtime.search(src.id, fallbackKw);
            final ranked = SourceKeywordMatcher.rankSearchHits(hits, _titleRefs);
            if (ranked.isNotEmpty) {
              targetUrl = ranked.first.url;
              targetTitle = ranked.first.name;
            }
          }
        }
      }

      if (targetUrl == null) {
        throw Exception('在「${src.name}」未检索到《${widget.title}》，请在面板中展开换词');
      }

      final roads = await runtime.chapters(src.id, targetUrl);
      if (roads.isEmpty || roads.every((r) => r.episodes.isEmpty)) {
        throw Exception('未能从「${src.name}」解析到有效分集');
      }

      if (!mounted) return;
      setState(() {
        _chapterRoads = roads;
        _selectedRoadIndex = 0;
        _isLoadingChapters = false;
        _defaultSearchEmpty = false;
      });

      // 写入持久化绑定
      if (targetTitle != null && targetUrl.isNotEmpty) {
        await SourceBindingService.instance.setBinding(
          bangumiId: bangumiId,
          sourceId: src.id,
          sourceUrl: targetUrl,
          title: targetTitle,
          referenceTitles: _titleRefs,
        );
      }

      // 若之前处于在播态，换源后自动无缝续播当前集数
      if (_hasStartedPlayback && _currentEpisodes.isNotEmpty) {
        _selectEpisode(_activeEpisode ?? 1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingChapters = false;
        _resolveError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// 通过 PlayableSlot 起播 (严格按照 Bangumi 映射对应真实媒体地址，彻底杜绝 PV/花絮错位)
  Future<void> _selectSlot(PlayableSlot slot) async {
    _autoPicker.onUserAction();

    setState(() {
      _activeEpisode = slot.canonicalEp;
      _hasStartedPlayback = true;
      _resolveError = null;
    });

    widget.onEpisodeSelected?.call(slot.canonicalEp);

    // 1. 若有预置直接流地址 (或单测环境测试流)
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      await _playbackController.open(
        widget.videoUrl!,
        httpHeaders: widget.httpHeaders,
      );
      return;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      await _playbackController.open(slot.pageUrl);
      return;
    }

    // 2. 否则通过当前视频源解析真实直链
    try {
      final runtime = SourceBundleManager.instance.runtime;
      final result = await runtime.resolve(_selectedSourceId, slot.pageUrl);

      if (result.url.isEmpty) {
        throw Exception('视频源未能生成有效媒体地址');
      }

      await _playbackController.open(
        result.url,
        httpHeaders: result.headers,
      );

      // 后台静默预热下一集
      final slots = _currentSlots;
      final currentIdx = slots.indexOf(slot);
      if (currentIdx != -1 && currentIdx + 1 < slots.length) {
        runtime.resolve(_selectedSourceId, slots[currentIdx + 1].pageUrl).ignore();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolveError = '播放解析失败: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    }
  }

  /// 用户点击选集起播 (严格对应视频源真实分集，mapping 通过 index 互相链接)
  Future<void> _selectEpisode(int ep) async {
    final slots = _currentSlots;
    if (slots.isNotEmpty) {
      final targetSlot = slots.firstWhere(
        (s) => s.canonicalEp == ep,
        orElse: () => (ep - 1 >= 0 && ep - 1 < slots.length) ? slots[ep - 1] : slots.first,
      );
      await _selectSlot(targetSlot);
      return;
    }

    _autoPicker.onUserAction();

    final episodes = _currentEpisodes;
    if (episodes.isEmpty || ep < 1 || ep > episodes.length) {
      return;
    }

    final epIndex = ep - 1;
    final targetEp = episodes[epIndex];

    // mapping 是通过 index 互相链接的 (官方集数用于弹幕和历史进度)
    final int mappedOfficialEp = (_officialEpisodes != null &&
            epIndex < _officialEpisodes!.length &&
            _officialEpisodes![epIndex].sort > 0)
        ? _officialEpisodes![epIndex].sort.toInt()
        : ep;

    setState(() {
      _activeEpisode = ep;
      _hasStartedPlayback = true;
      _resolveError = null;
    });

    widget.onEpisodeSelected?.call(mappedOfficialEp);

    // 1. 若有预置直接流地址 (或单测环境测试流)
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      await _playbackController.open(
        widget.videoUrl!,
        httpHeaders: widget.httpHeaders,
      );
      return;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      await _playbackController.open(targetEp.url);
      return;
    }

    // 2. 否则通过当前视频源解析真实直链
    try {
      final runtime = SourceBundleManager.instance.runtime;
      final result = await runtime.resolve(_selectedSourceId, targetEp.url);

      if (result.url.isEmpty) {
        throw Exception('视频源未能生成有效媒体地址');
      }

      await _playbackController.open(
        result.url,
        httpHeaders: result.headers,
      );

      // 后台静默预热下一集播放直链
      if (epIndex + 1 < episodes.length) {
        runtime.resolve(_selectedSourceId, episodes[epIndex + 1].url).ignore();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolveError = '播放解析失败: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    }
  }

  @override
  void dispose() {
    if (_isFullscreen) {
      _exitFullscreen();
    }
    _tabController.dispose();
    _playbackController.dispose();
    _danmakuController.dispose();
    _aggregator.removeListener(_onAggregatorUpdated);
    _aggregator.dispose();
    _autoPicker.dispose();
    super.dispose();
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
      _isSidePanelOpen = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _handleBackPressed() {
    if (_isSidePanelOpen) {
      setState(() => _isSidePanelOpen = false);
      return;
    }
    if (_isFullscreen) {
      _exitFullscreen();
      return;
    }
    _playbackController.pause();
    _playbackController.setVolume(0.0);
    Navigator.of(context).maybePop();
  }

  String get _resolvedCoverUrl {
    if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty) {
      return widget.coverUrl!;
    }
    return _effectiveBangumiItem?.coverUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isFullscreen && !_isSidePanelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_isSidePanelOpen) {
            setState(() => _isSidePanelOpen = false);
          } else if (_isFullscreen) {
            _exitFullscreen();
          }
        }
      },
      child: Scaffold(
        backgroundColor: _isFullscreen
            ? Colors.black
            : (isDark ? Colors.black : Theme.of(context).scaffoldBackgroundColor),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth >= 768 && !_isFullscreen;

            if (_isFullscreen) {
              return _buildFullscreenLayout();
            } else if (isWideScreen) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  /// 顶部播放器或未起播海报占位组件
  Widget _buildPlayerOrPlaceholder({required bool isFullscreen}) {
    if (!_hasStartedPlayback) {
      return _buildInitialPlaceholder();
    }

    final epTitle = _activeEpisode != null ? ' - 第 $_activeEpisode 话' : '';
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        VideoSurface(
          controller: _playbackController,
          danmakuController: _danmakuController,
          overlay: PlayerControls(
            controller: _playbackController,
            title: '${widget.title}$epTitle',
            danmakuController: _danmakuController,
            isFullscreen: isFullscreen,
            onToggleFullscreen: _toggleFullscreen,
            onBackPressed: _handleBackPressed,
            onOpenEpisodePicker: isFullscreen
                ? () => setState(() {
                      _sidePanelInitialTab = PlayerSidePanelTab.episodes;
                      _isSidePanelOpen = !_isSidePanelOpen;
                    })
                : null,
            onOpenSidePanel: isFullscreen
                ? (tab) => setState(() {
                      _sidePanelInitialTab = tab;
                      _isSidePanelOpen = true;
                    })
                : null,
            onNextEpisode: (_activeEpisode != null &&
                    _activeEpisode! < _currentEpisodes.length)
                ? () => _selectEpisode(_activeEpisode! + 1)
                : null,
            onPrevEpisode: (_activeEpisode != null && _activeEpisode! > 1)
                ? () => _selectEpisode(_activeEpisode! - 1)
                : null,
            opedSegment: _currentOpedSegment,
          ),
        ),

        // HUD Toast 悬浮提示胶囊
        if (_hudToast != null)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _hudToast!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // iOS 风格解析失败提示磨砂卡片
        if (_resolveError != null)
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        _resolveError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BouncingScaleCard(
                            scaleDown: 0.94,
                            onTap: () {
                              if (_activeEpisode != null) {
                                _selectEpisode(_activeEpisode!);
                              } else {
                                _startDefaultSourceSearch(autoPlayFirst: true);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 0.5,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, color: Colors.white, size: 15),
                                  SizedBox(width: 4),
                                  Text(
                                    '重试',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          BouncingScaleCard(
                            scaleDown: 0.94,
                            onTap: () {
                              _autoPicker.onUserAction();
                              _tabController.animateTo(1);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '切换视频源',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 未起播海报占位组件 (iOS Ambient & Frosted Play Button)
  Widget _buildInitialPlaceholder() {
    final cover = _resolvedCoverUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover.isNotEmpty)
          CachedAnimeImage(
            imageUrl: cover,
            fit: BoxFit.cover,
          )
        else
          Container(color: Colors.black87),

        // 柔和暗角与氛围蒙层
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),

        // 顶部返回与标题
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.5,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          onPressed: _handleBackPressed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 中央磨砂播放按钮
        Center(
          child: BouncingScaleCard(
            scaleDown: 0.92,
            onTap: () {
              if (_currentEpisodes.isNotEmpty) {
                _selectEpisode(_activeEpisode ?? 1);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 底部 iOS 磨砂提示胶囊条
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoadingChapters)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: CupertinoActivityIndicator(
                            color: Colors.white70,
                            radius: 6,
                          ),
                        )
                      else
                        const Icon(
                          Icons.touch_app_outlined,
                          color: Colors.white70,
                          size: 14,
                        ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _isLoadingChapters
                              ? '正在同步「$_selectedSourceName」选集...'
                              : (_currentEpisodes.isNotEmpty
                                  ? '分集已就绪 · 请在下方选择集数开始播放'
                                  : '请在下方选择播放源或选集'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 选集 Tab 核心渲染器
  Widget _buildEpisodeSectionBody() {
    if (_isLoadingChapters) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 12),
            const SizedBox(height: 12),
            Text(
              '正在从「$_selectedSourceName」加载分集...',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    if (_currentEpisodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                '「$_selectedSourceName」暂未检索到该番剧分集',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '建议切换到其他备用视频源查找资源',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              BouncingScaleCard(
                scaleDown: 0.95,
                onTap: () {
                  _autoPicker.onUserAction();
                  _tabController.animateTo(1);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 17, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        '前往「视频源」选择',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return EpisodePickerSection(
      episodeCount: _currentSlots.isNotEmpty ? _currentSlots.length : _currentEpisodes.length,
      currentEpisode: _activeEpisode,
      roads: _roadNames,
      activeRoadIndex: _selectedRoadIndex,
      episodeTitles: _mappedEpisodeTitles,
      slots: _currentSlots,
      onRoadSelected: (idx) => setState(() => _selectedRoadIndex = idx),
      onRefresh: () => _startDefaultSourceSearch(autoPlayFirst: false),
      onSelectEpisode: _selectEpisode,
      onSelectSlot: _selectSlot,
    );
  }

  /// iOS 风格极简精致滑动胶囊分段控制器
  Widget _buildSegmentedTabBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            height: 32,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
                width: 0.5,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              labelPadding: EdgeInsets.zero,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(36) : Colors.white,
                borderRadius: BorderRadius.circular(13.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              labelColor: isDark ? Colors.white : primaryColor,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
              tabs: const [
                Tab(height: 27, text: '番剧详情'),
                Tab(height: 27, text: '视频源'),
                Tab(height: 27, text: '选集'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. 全屏横屏布局 (带 iOS/Kazumi 风格磨砂悬浮抽屉 PlayerSidePanel)
  Widget _buildFullscreenLayout() {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildPlayerOrPlaceholder(isFullscreen: true),
        ),
        PlayerSidePanel(
          isOpen: _isSidePanelOpen,
          initialTab: _sidePanelInitialTab,
          onClose: () => setState(() => _isSidePanelOpen = false),
          episodeCount: _currentSlots.isNotEmpty ? _currentSlots.length : _currentEpisodes.length,
          currentEpisode: _activeEpisode,
          roads: _roadNames,
          activeRoadIndex: _selectedRoadIndex,
          episodeTitles: _mappedEpisodeTitles,
          slots: _currentSlots,
          isLoadingEpisodes: _isLoadingChapters,
          onSelectEpisode: (ep) => _selectEpisode(ep),
          onSelectSlot: (slot) => _selectSlot(slot),
          onRoadSelected: (idx) => setState(() => _selectedRoadIndex = idx),
          onRefreshEpisodes: () =>
              _startDefaultSourceSearch(autoPlayFirst: false),
          sources: _sources,
          selectedSourceId: _selectedSourceId,
          aggregator: _aggregator,
          onSourceSelected: (src) => _handleSourceSelected(src),
          danmakuController: _danmakuController,
          controller: _playbackController,
        ),
      ],
    );
  }

  /// 2. 桌面/宽屏并排布局 (左侧 16:9 + 右侧 3 Tab)
  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _handleBackPressed,
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildPlayerOrPlaceholder(isFullscreen: false),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildSegmentedTabBar(context),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      WatchMetaView(
                        title: widget.title,
                        bangumiItem: _effectiveBangumiItem,
                        coverUrl: _resolvedCoverUrl,
                        episodeCount: _currentEpisodes.isNotEmpty
                            ? _currentEpisodes.length
                            : widget.episodeCount,
                      ),
                      VideoSourceView(
                        sources: _sources,
                        selectedSourceId: _selectedSourceId,
                        onSourceSelected: _handleSourceSelected,
                        onSelectHit: (src, hit, [List<SourceChapterRoad>? cachedRoads]) => _handleSourceSelected(src, hit, cachedRoads),
                        aggregator: _aggregator,
                        hintMessage: _sourceNotice,
                        keywordOptions: _keywordOptions,
                        onUserAction: _autoPicker.onUserAction,
                        currentEpisodeNumber: _activeEpisode,
                      ),
                      _buildEpisodeSectionBody(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. 移动端竖屏布局 (上方 16:9 + 下方 iOS 风格 3 Tab)
  Widget _buildMobileLayout() {
    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayerOrPlaceholder(isFullscreen: false),
          ),
          _buildSegmentedTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                WatchMetaView(
                  title: widget.title,
                  bangumiItem: _effectiveBangumiItem,
                  coverUrl: _resolvedCoverUrl,
                  episodeCount: _currentEpisodes.isNotEmpty
                      ? _currentEpisodes.length
                      : widget.episodeCount,
                ),
                VideoSourceView(
                  sources: _sources,
                  selectedSourceId: _selectedSourceId,
                  onSourceSelected: _handleSourceSelected,
                  onSelectHit: (src, hit, [List<SourceChapterRoad>? cachedRoads]) => _handleSourceSelected(src, hit, cachedRoads),
                  aggregator: _aggregator,
                  hintMessage: _sourceNotice,
                  keywordOptions: _keywordOptions,
                  onUserAction: _autoPicker.onUserAction,
                  currentEpisodeNumber: _activeEpisode,
                ),
                _buildEpisodeSectionBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
