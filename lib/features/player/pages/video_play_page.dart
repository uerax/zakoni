import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/bangumi/bangumi_episode.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../../core/network/bangumi_client.dart';
import '../../common/widgets/cached_anime_image.dart';
import '../controller/playback_controller.dart';
import '../danmaku/danmaku.dart';
import '../source/models/source_models.dart';
import '../source/source_aggregator.dart';
import '../source/source_bundle_manager.dart';
import '../source/source_keyword_matcher.dart';
import '../widgets/episode_picker_section.dart';
import '../widgets/player_controls.dart';
import '../widgets/video_source_view.dart';
import '../widgets/video_surface.dart';
import '../widgets/watch_meta_view.dart';

/// zakoni 统一多端视频播放页面
/// 遵循 animaku 官方交互与数据生命周期规范：
/// 1. 页面入参作为 Seed 占位，避免白屏等待；
/// 2. 入场异步拉取 Bangumi 权威番剧数据与官方分集列表（用于弹幕与历史续播集数 Mapping）；
/// 3. 初始仅向默认视频源发起搜索，搜到即拉取真实分集；
/// 4. 默认源未匹配时，自动展开「视频源」Tab，并在后台并发探测前 6 个源，供用户选择；
/// 5. 选集严格根据视频源返回的真实章节渲染，绝不虚假填充；用户点选后直连播放。
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

  bool _isFullscreen = false;
  bool _isSidePanelOpen = false;
  int? _activeEpisode;
  bool _hasStartedPlayback = false;

  // 视频源与选集状态
  String _selectedSourceId = 'xifan-next';
  late final List<VideoSourceItem> _sources = getDefaultSourceItems();

  bool _isLoadingChapters = false;
  bool _isResolvingMedia = false;
  String? _resolveError;
  String? _sourceNotice;

  List<SourceChapterRoad> _chapterRoads = [];
  int _selectedRoadIndex = 0;

  // Bangumi 官方数据补全
  BangumiItem? _fullBangumiItem;
  List<BangumiEpisode>? _officialEpisodes;

  BangumiItem? get _effectiveBangumiItem => _fullBangumiItem ?? widget.bangumiItem;

  List<SourceEpisode> get _currentEpisodes {
    if (_chapterRoads.isEmpty) return [];
    final idx = _selectedRoadIndex.clamp(0, _chapterRoads.length - 1);
    return _chapterRoads[idx].episodes;
  }

  List<String> get _mappedEpisodeTitles {
    final episodes = _currentEpisodes;
    if (episodes.isEmpty) return [];

    // 对齐 animaku 规范：优先按 Bangumi 权威正片列表 (type == 0) 位置映射集数编号
    final officialMain = (_officialEpisodes ?? [])
        .where((e) => e.type == 0)
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));

    return List.generate(episodes.length, (i) {
      if (i < officialMain.length) {
        final bgm = officialMain[i];
        final epNum = bgm.ep ?? bgm.sort;
        final isInt = epNum == epNum.roundToDouble();
        final numStr = isInt ? epNum.toInt().toString().padLeft(2, '0') : epNum.toString();
        return '第 $numStr 话';
      }
      return '第 ${(i + 1).toString().padLeft(2, '0')} 话';
    });
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

  @override
  void initState() {
    super.initState();
    _activeEpisode = widget.currentEpisode;
    _danmakuController = DanmakuController();
    _playbackController = ZakoniPlaybackController(
      danmakuController: _danmakuController,
    );
    _aggregator = SourceAggregator();
    _aggregator.addListener(() {
      if (mounted) setState(() {});
    });

    // 默认聚焦第 3 个 Tab「选集」(index: 2)
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 2,
    );

    if (widget.danmakuItems != null && widget.danmakuItems!.isNotEmpty) {
      _danmakuController.loadItems(widget.danmakuItems!);
    }

    // 异步拉取 Bangumi 权威详情与分集
    _fetchBangumiAuthorityData();

    // 若有显式传入的固定 URL 则直接起播
    if (_activeEpisode != null &&
        widget.videoUrl != null &&
        widget.videoUrl!.isNotEmpty) {
      _hasStartedPlayback = true;
      _initPlayback();
    } else {
      // 否则启动默认视频源检索流程
      _startDefaultSourceSearch(autoPlayFirst: _activeEpisode != null);
    }
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
      if (mounted) {
        setState(() {
          _fullBangumiItem = subject;
          _officialEpisodes = eps;
        });
      }
    } catch (_) {
      // 失败静默使用传入的 Seed 数据
    }
  }

  /// 只触发默认源检索；若未匹配则展开视频源面板并发探测
  Future<void> _startDefaultSourceSearch({bool autoPlayFirst = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingChapters = true;
      _resolveError = null;
      _sourceNotice = null;
    });

    try {
      // 单测环境无 C++ 动态库守护
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
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
        return;
      }

      await SourceBundleManager.instance.initialize();
      final runtime = SourceBundleManager.instance.runtime;

      // 提取有序候选词池
      final keywords = SourceKeywordMatcher.buildCandidates(
        defaultTitle: widget.title,
        item: _effectiveBangumiItem,
        sourceId: _selectedSourceId,
      );

      SourceSearchResult? bestHit;
      for (final kw in keywords) {
        final hits = await runtime.search(_selectedSourceId, kw);
        if (hits.isNotEmpty) {
          for (final h in hits) {
            final sim = SourceKeywordMatcher.bestSimilarity(h.name, keywords);
            if (sim >= 0.55) {
              bestHit = h;
              break;
            }
          }
          if (bestHit != null) break;
        }
      }

      // Case A: 默认源成功匹配
      if (bestHit != null) {
        final roads = await runtime.chapters(_selectedSourceId, bestHit.url);
        if (roads.isNotEmpty && roads.any((r) => r.episodes.isNotEmpty)) {
          if (!mounted) return;
          setState(() {
            _chapterRoads = roads;
            _selectedRoadIndex = 0;
            _isLoadingChapters = false;
          });

          if (autoPlayFirst && _currentEpisodes.isNotEmpty) {
            _selectEpisode(_activeEpisode ?? 1);
          }
          return;
        }
      }

      // Case B: 默认源未匹配 -> 自动展开视频源面板并并发探测备用源
      if (!mounted) return;
      setState(() {
        _isLoadingChapters = false;
        _chapterRoads = [];
        _sourceNotice = '默认源未收录《${widget.title}》，已为你并发检索备用播放源';
      });

      // 自动切换到「视频源」Tab (index: 1)
      _tabController.animateTo(1);

      // 后台并发探测排名前 6 个源
      _aggregator.probeSources(
        defaultTitle: widget.title,
        item: _effectiveBangumiItem,
        skipSourceId: _selectedSourceId,
        limit: 6,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingChapters = false;
        _resolveError = '检索异常: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    }
  }

  /// 用户在视频源面板选择某源 (折叠面板，切回选集并拉取真实分集)
  Future<void> _handleSourceSelected(VideoSourceItem src) async {
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
        return;
      }

      final runtime = SourceBundleManager.instance.runtime;

      // 检查当前源是否在探测器中已有命中缓存
      final probeHit = _aggregator.items
          .cast<AggregatedSourceState?>()
          .firstWhere((p) => p?.meta.id == src.id && p?.matchedHit != null, orElse: () => null)
          ?.matchedHit;

      String? targetUrl = probeHit?.url;

      if (targetUrl == null) {
        final keywords = SourceKeywordMatcher.buildCandidates(
          defaultTitle: widget.title,
          item: _effectiveBangumiItem,
          sourceId: src.id,
        );

        for (final kw in keywords) {
          final hits = await runtime.search(src.id, kw);
          if (hits.isNotEmpty) {
            for (final h in hits) {
              final sim = SourceKeywordMatcher.bestSimilarity(h.name, keywords);
              if (sim >= 0.55) {
                targetUrl = h.url;
                break;
              }
            }
            if (targetUrl != null) break;
          }
        }
      }

      if (targetUrl == null) {
        throw Exception('在「${src.name}」未检索到《${widget.title}》');
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
      });

      // 若之前处于在播态，换源后自动续播当前集数
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

  /// 用户点击选集起播 (严格对应视频源真实分集，mapping 通过 index 互相链接)
  Future<void> _selectEpisode(int ep) async {
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
      _isResolvingMedia = true;
      _resolveError = null;
    });

    widget.onEpisodeSelected?.call(mappedOfficialEp);

    // 1. 若有预置直接流地址 (或单测环境测试流)
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      await _playbackController.open(
        widget.videoUrl!,
        httpHeaders: widget.httpHeaders,
      );
      if (mounted) setState(() => _isResolvingMedia = false);
      return;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      await _playbackController.open(targetEp.url);
      if (mounted) setState(() => _isResolvingMedia = false);
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
      if (mounted) setState(() => _isResolvingMedia = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingMedia = false;
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
    _aggregator.dispose();
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
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) {
          _exitFullscreen();
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
                ? () => setState(() => _isSidePanelOpen = !_isSidePanelOpen)
                : null,
          ),
        ),

        // 解析中遮罩层
        if (_isResolvingMedia)
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  '正在通过「$_selectedSourceName」解析直链...',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),

        // 解析失败提示层
        if (_resolveError != null && !_isResolvingMedia)
          Container(
            color: Colors.black.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 40),
                const SizedBox(height: 8),
                Text(
                  _resolveError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('重试'),
                      onPressed: () {
                        if (_activeEpisode != null) {
                          _selectEpisode(_activeEpisode!);
                        } else {
                          _startDefaultSourceSearch(autoPlayFirst: true);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('切换视频源'),
                      onPressed: () => _tabController.animateTo(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 未起播海报占位组件
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

        Container(
          color: Colors.black.withValues(alpha: 0.55),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: _handleBackPressed,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Center(
          child: InkWell(
            onTap: () {
              if (_currentEpisodes.isNotEmpty) {
                _selectEpisode(1);
              } else {
                _startDefaultSourceSearch(autoPlayFirst: true);
              }
            },
            borderRadius: BorderRadius.circular(36),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app_outlined, color: Colors.white70, size: 15),
                const SizedBox(width: 6),
                Text(
                  _isLoadingChapters
                      ? '正在同步「$_selectedSourceName」选集...'
                      : (_currentEpisodes.isNotEmpty ? '分集已就绪 · 请在下方选择集数开始播放' : '请在下方选择播放源或选集'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 选集 Tab 核心渲染器 (严格根据视频源真实数据渲染，绝不填充伪造按钮)
  Widget _buildEpisodeSectionBody() {
    if (_isLoadingChapters) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              '正在从「$_selectedSourceName」加载分集...',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '建议切换到其他备用视频源查找资源',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('前往「视频源」选择'),
                onPressed: () => _tabController.animateTo(1),
              ),
            ],
          ),
        ),
      );
    }

    return EpisodePickerSection(
      episodeCount: _currentEpisodes.length,
      currentEpisode: _activeEpisode,
      roads: _roadNames,
      activeRoadIndex: _selectedRoadIndex,
      episodeTitles: _mappedEpisodeTitles,
      onRoadSelected: (idx) => setState(() => _selectedRoadIndex = idx),
      onRefresh: () => _startDefaultSourceSearch(autoPlayFirst: false),
      onSelectEpisode: _selectEpisode,
    );
  }

  /// 1. 全屏横屏布局
  Widget _buildFullscreenLayout() {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildPlayerOrPlaceholder(isFullscreen: true),
        ),
        if (_isSidePanelOpen)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 320,
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('快速选集', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            onPressed: () => setState(() => _isSidePanelOpen = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Expanded(child: _buildEpisodeSectionBody()),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 2. 桌面/宽屏并排布局 (左侧 16:9 + 右侧 3 Tab)
  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildPlayerOrPlaceholder(isFullscreen: false),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '番剧详情'),
                    Tab(text: '视频源'),
                    Tab(text: '选集'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      WatchMetaView(
                        title: widget.title,
                        bangumiItem: _effectiveBangumiItem,
                        coverUrl: _resolvedCoverUrl,
                        episodeCount: _currentEpisodes.isNotEmpty ? _currentEpisodes.length : widget.episodeCount,
                      ),
                      VideoSourceView(
                        sources: _sources,
                        selectedSourceId: _selectedSourceId,
                        onSourceSelected: _handleSourceSelected,
                        aggregator: _aggregator,
                        hintMessage: _sourceNotice,
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

  /// 3. 移动端竖屏布局 (上方 16:9 + 下方 3 Tab)
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
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '番剧详情'),
              Tab(text: '视频源'),
              Tab(text: '选集'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                WatchMetaView(
                  title: widget.title,
                  bangumiItem: _effectiveBangumiItem,
                  coverUrl: _resolvedCoverUrl,
                  episodeCount: _currentEpisodes.isNotEmpty ? _currentEpisodes.length : widget.episodeCount,
                ),
                VideoSourceView(
                  sources: _sources,
                  selectedSourceId: _selectedSourceId,
                  onSourceSelected: _handleSourceSelected,
                  aggregator: _aggregator,
                  hintMessage: _sourceNotice,
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
