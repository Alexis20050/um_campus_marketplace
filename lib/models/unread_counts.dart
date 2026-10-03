/// Shared counts for conversation rows and the navigation badge.
/// Each new subscription invalidates events from the previous subscription.
class UnreadCounts {
  final Map<String, int> _counts = {};
  int _generation = 0;

  int get total => _counts.values.fold(0, (sum, count) => sum + count);
  int forConversation(String id) => _counts[id] ?? 0;
  int nextGeneration() => ++_generation;
  bool isCurrent(int generation) => generation == _generation;

  void clear() => _counts.clear();
  void markRead(String id) => _counts[id] = 0;

  bool apply(List<Map<String, dynamic>> rows, String userId, int generation) {
    if (!isCurrent(generation)) return false;
    _counts.clear();
    for (final row in rows) {
      _counts[row['id'] as String] = countFor(row, userId);
    }
    return true;
  }

  static int countFor(Map<String, dynamic> row, String userId) {
    final field = row['buyer_id'] == userId
        ? 'buyer_unread'
        : row['seller_id'] == userId
        ? 'seller_unread'
        : null;
    if (field == null) return 0;
    final count = (row[field] as num?)?.toInt() ?? 0;
    return count < 0 ? 0 : count;
  }
}
