/// 插件熔断器状态 (1:1 严格对齐 animaku PluginCircuitBreaker)
class PluginBreakerState {
  int failureCount;
  int lastFailureTime;
  int trippedUntil;
  bool halfOpenProbing;

  PluginBreakerState({
    this.failureCount = 0,
    this.lastFailureTime = 0,
    this.trippedUntil = 0,
    this.halfOpenProbing = false,
  });
}

/// 视频源故障单飞半开熔断器 (1:1 对齐 animaku plugin-circuit-breaker.ts)
/// 核心保障：
/// 1. 软超时 (504/timeout): 30s 内连续 2 次触发 90s 冷却；
/// 2. 网络硬故障 (网络不可达/SocketException/ConnectionRefused): 单次直接触发 90s 冷却；
/// 3. 单飞半开 (Single-Flight Half-Open): 冷却期满后仅放行单个真实请求试探，其余并发快速失败；
/// 4. 杜绝"源站宕机时每次点开均卡顿 5 秒"以及"集中超时爆发"。
class PluginCircuitBreaker {
  PluginCircuitBreaker._();
  static final PluginCircuitBreaker instance = PluginCircuitBreaker._();

  static const int failureWindowMs = 30000;
  static const int cooldownMs = 90000;
  static const int softFailureThreshold = 2;

  final Map<String, PluginBreakerState> _states = {};

  String _normalizeKey(String pluginName) => pluginName.trim().toLowerCase();

  static final RegExp _hardErrorRegex = RegExp(
    r'ECONNREFUSED|ENOTFOUND|SocketException|Failed host lookup|Connection refused|网络不可达|Network is unreachable',
    caseSensitive: false,
  );

  static final RegExp _timeoutErrorRegex = RegExp(
    r'504|timeout|超时|ETIMEDOUT|timed out|Receive timed out|Connect timed out|Send timed out',
    caseSensitive: false,
  );

  /// 检查指定源当前是否被允许执行搜索/探测请求
  /// 若处于熔断冷却中，或半开态已有单飞请求，则立即快速失败并返回冷却倒计时
  ({bool allowed, String? reason}) checkBeforeRequest(String pluginName) {
    final key = _normalizeKey(pluginName);
    final state = _states[key];
    if (state == null) {
      return (allowed: true, reason: null);
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. 仍在完全冷却期内
    if (now < state.trippedUntil) {
      final remainingSec = mathMax(1, ((state.trippedUntil - now) / 1000).ceil());
      return (
        allowed: false,
        reason: '源站响应异常，熔断冷却中 (剩余 ${remainingSec}s)',
      );
    }

    // 2. 冷却期已过，进入半开测试期 (Half-Open)
    if (state.trippedUntil > 0) {
      if (state.halfOpenProbing) {
        // 单飞互斥保护：已有正在发起的探活请求，后续并发请求继续沿用熔断短路
        return (
          allowed: false,
          reason: '源站响应异常，半开探活测试中',
        );
      }
      // 成功抢占唯一的半开探活名额
      state.halfOpenProbing = true;
      return (allowed: true, reason: null);
    }

    return (allowed: true, reason: null);
  }

  /// 记录一次成功响应，彻底清空该源的熔断状态
  void recordSuccess(String pluginName) {
    final key = _normalizeKey(pluginName);
    _states.delete(key);
  }

  /// 记录一次源站异常
  void recordFailure(String pluginName, dynamic error) {
    final key = _normalizeKey(pluginName);
    final errorMsg = error.toString();

    final isHard = _hardErrorRegex.hasMatch(errorMsg);
    final isTimeout = _timeoutErrorRegex.hasMatch(errorMsg);

    // 仅对真正的网络中断或超时执行熔断（业务错误不计入整站熔断）
    if (!isHard && !isTimeout) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final state = _states[key] ?? PluginBreakerState();

    // 若当前正是半开试探请求失败，直接重新冷却 90 秒
    if (state.trippedUntil > 0 && state.halfOpenProbing) {
      state.trippedUntil = now + cooldownMs;
      state.halfOpenProbing = false;
      state.lastFailureTime = now;
      state.failureCount++;
      _states[key] = state;
      return;
    }

    // 统计滑动窗口内的连续失败次数
    if (now - state.lastFailureTime <= failureWindowMs) {
      state.failureCount++;
    } else {
      state.failureCount = 1;
    }
    state.lastFailureTime = now;

    // 判定是否达到熔断阈值
    final shouldTrip = isHard || state.failureCount >= softFailureThreshold;
    if (shouldTrip) {
      state.trippedUntil = now + cooldownMs;
      state.halfOpenProbing = false;
    }

    _states[key] = state;
  }

  void reset([String? pluginName]) {
    if (pluginName != null) {
      _states.remove(_normalizeKey(pluginName));
    } else {
      _states.clear();
    }
  }

  int mathMax(int a, int b) => a > b ? a : b;
}

extension on Map<String, PluginBreakerState> {
  void delete(String key) => remove(key);
}
