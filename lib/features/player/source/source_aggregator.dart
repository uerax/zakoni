import 'package:flutter/foundation.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import 'models/source_models.dart';
import 'source_bundle_manager.dart';
import 'source_keyword_matcher.dart';

enum SourceProbeStatus {
  idle,
  probing,
  ready,
  empty,
  error,
}

class AggregatedSourceState {
  final SourceMeta meta;
  final SourceProbeStatus status;
  final SourceSearchResult? matchedHit;
  final String? errorMsg;

  const AggregatedSourceState({
    required this.meta,
    this.status = SourceProbeStatus.idle,
    this.matchedHit,
    this.errorMsg,
  });

  AggregatedSourceState copyWith({
    SourceProbeStatus? status,
    SourceSearchResult? matchedHit,
    String? errorMsg,
  }) {
    return AggregatedSourceState(
      meta: meta,
      status: status ?? this.status,
      matchedHit: matchedHit ?? this.matchedHit,
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }
}

/// 对应 animaku use-source-aggregator 的并发源探测器
class SourceAggregator extends ChangeNotifier {
  final Map<String, AggregatedSourceState> _states = {};
  bool _isProbing = false;

  bool get isProbing => _isProbing;
  List<AggregatedSourceState> get items => _states.values.toList();

  /// 对指定源发起并发探测 (最多 N 个源，默认 6 个，对齐 animaku AUTO_PROBE_LIMIT = 6)
  Future<void> probeSources({
    required String defaultTitle,
    BangumiItem? item,
    String? skipSourceId,
    int limit = 6,
  }) async {
    final allSources = SourceBundleManager.instance.sources;
    final candidates = allSources.where((s) => s.id != skipSourceId).take(limit).toList();
    if (candidates.isEmpty) return;

    _states.clear();
    for (final s in candidates) {
      _states[s.id] = AggregatedSourceState(meta: s, status: SourceProbeStatus.probing);
    }
    _isProbing = true;
    notifyListeners();

    final runtime = SourceBundleManager.instance.runtime;

    await Future.wait(
      candidates.map((source) async {
        final keywords = SourceKeywordMatcher.buildCandidates(
          defaultTitle: defaultTitle,
          item: item,
          sourceId: source.id,
        );

        try {
          SourceSearchResult? bestHit;

          // 依次尝试候选词，命中相似度 >= 0.55 即认定为有效资源
          for (final kw in keywords) {
            final hits = await runtime.search(source.id, kw);
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

          if (bestHit != null) {
            _states[source.id] = AggregatedSourceState(
              meta: source,
              status: SourceProbeStatus.ready,
              matchedHit: bestHit,
            );
          } else {
            _states[source.id] = AggregatedSourceState(
              meta: source,
              status: SourceProbeStatus.empty,
            );
          }
        } catch (e) {
          _states[source.id] = AggregatedSourceState(
            meta: source,
            status: SourceProbeStatus.error,
            errorMsg: e.toString().replaceFirst('Exception: ', ''),
          );
        }
        notifyListeners();
      }),
    );

    _isProbing = false;
    notifyListeners();
  }

  void clear() {
    _states.clear();
    _isProbing = false;
    notifyListeners();
  }
}
