/// 带有效期的轻量内存缓存容器（单值）
class TimedCache<T> {
  final Duration maxAge;
  T? _value;
  DateTime? _timestamp;

  TimedCache({this.maxAge = const Duration(minutes: 30)});

  /// 获取未过期的有效缓存值，若已过期或未设置则返回 null
  T? get value {
    if (_value == null || _timestamp == null) return null;
    if (DateTime.now().difference(_timestamp!) < maxAge) {
      return _value;
    }
    return null;
  }

  /// 获取可能已过期的最后一份有效数据（用于容灾降级）
  T? get staleValue => _value;

  /// 更新缓存值与当前时间戳
  void set(T value) {
    _value = value;
    _timestamp = DateTime.now();
  }

  /// 清空缓存
  void clear() {
    _value = null;
    _timestamp = null;
  }
}

/// 支持多 Key、带 TTL 和 LRU 淘汰机制的内存缓存池
class TimedKeyedCache<K, V> {
  final Duration maxAge;
  final int maxEntries;
  final Map<K, ({V value, DateTime timestamp})> _store = {};

  TimedKeyedCache({
    this.maxAge = const Duration(hours: 2),
    this.maxEntries = 150,
  });

  /// 获取未过期的缓存值，命中时刷新 LRU 顺序；若已过期则移除并返回 null
  V? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) < maxAge) {
      // 刷新访问顺序（LinkedHashMap LRU 刷新）
      _store.remove(key);
      _store[key] = entry;
      return entry.value;
    }
    _store.remove(key);
    return null;
  }

  /// 快速查看未过期的缓存值（不刷新 LRU 顺序）
  V? peek(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) < maxAge) {
      return entry.value;
    }
    return null;
  }

  /// 获取可能已过期的陈旧值（用于网络异常或降级容灾）
  V? getStale(K key) => _store[key]?.value;

  /// 写入或更新缓存条目，超出上限时逐出最早的条目
  void set(K key, V value) {
    _store.remove(key);
    _store[key] = (value: value, timestamp: DateTime.now());
    while (_store.length > maxEntries) {
      _store.remove(_store.keys.first);
    }
  }

  /// 当前缓存的有效/总条目数
  int get length => _store.length;

  /// 获取当前缓存池中全部的值
  Iterable<V> get values => _store.values.map((e) => e.value);

  /// 移除指定 key
  void remove(K key) => _store.remove(key);

  /// 清空缓存
  void clear() => _store.clear();
}
