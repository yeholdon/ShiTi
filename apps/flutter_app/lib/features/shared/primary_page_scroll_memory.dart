class PrimaryPageScrollMemory {
  static final Map<String, double> _offsets = <String, double>{};
  static final Set<String> _pendingTopResets = <String>{};

  static double offsetFor(String pageKey) => _offsets[pageKey] ?? 0;

  static void update(String pageKey, double offset) {
    _offsets[pageKey] = offset;
  }

  static void requestTopReset(String pageKey) {
    _offsets[pageKey] = 0;
    _pendingTopResets.add(pageKey);
  }

  static bool consumePendingTopReset(String pageKey) {
    return _pendingTopResets.remove(pageKey);
  }

  static void clear() {
    _offsets.clear();
    _pendingTopResets.clear();
  }
}
