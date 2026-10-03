import 'package:flutter_test/flutter_test.dart';
import 'package:um_campus_marketplace/models/unread_counts.dart';

Map<String, dynamic> conversation(String id, int buyer, int seller) => {
  'id': id,
  'buyer_id': 'buyer',
  'seller_id': 'seller',
  'buyer_unread': buyer,
  'seller_unread': seller,
};

void main() {
  test('each student sees their own unread counter', () {
    final row = conversation('a', 3, 7);
    expect(UnreadCounts.countFor(row, 'buyer'), 3);
    expect(UnreadCounts.countFor(row, 'seller'), 7);
    expect(UnreadCounts.countFor(row, 'outsider'), 0);
  });

  test('viewing one conversation preserves other unread conversations', () {
    final counts = UnreadCounts();
    counts.apply(
      [conversation('a', 3, 0), conversation('b', 2, 0)],
      'buyer',
      counts.nextGeneration(),
    );
    counts.markRead('a');
    expect(counts.forConversation('a'), 0);
    expect(counts.forConversation('b'), 2);
    expect(counts.total, 2);
    counts.markRead('a');
    expect(counts.total, 2); // Repeated reads must not subtract again.
  });

  test('old realtime events cannot restore a cleared badge', () {
    final counts = UnreadCounts();
    final oldGeneration = counts.nextGeneration();
    counts.apply([conversation('a', 4, 0)], 'buyer', oldGeneration);
    counts.markRead('a');
    final currentGeneration = counts.nextGeneration();
    expect(
      counts.apply([conversation('a', 4, 0)], 'buyer', oldGeneration),
      false,
    );
    expect(counts.total, 0);
    counts.apply([conversation('a', 1, 0)], 'buyer', currentGeneration);
    expect(counts.total, 1); // A genuinely new message still adds a badge.
  });

  test('sign-out invalidates callbacks and clears counts', () {
    final counts = UnreadCounts();
    final generation = counts.nextGeneration();
    counts.apply([conversation('a', 3, 0)], 'buyer', generation);
    counts.nextGeneration();
    counts.clear();
    counts.apply([conversation('a', 3, 0)], 'buyer', generation);
    expect(counts.total, 0);
  });

  test(
    'server snapshot removes deleted conversations and clamps bad counts',
    () {
      final counts = UnreadCounts();
      final generation = counts.nextGeneration();
      counts.apply([conversation('a', 2, 0)], 'buyer', generation);
      counts.apply([conversation('b', -1, 0)], 'buyer', generation);
      expect(counts.total, 0);
      expect(counts.forConversation('a'), 0);
    },
  );
}
