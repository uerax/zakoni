/// 带有效期的轻量内存缓存容器
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
