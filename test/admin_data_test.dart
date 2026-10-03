import 'package:flutter_test/flutter_test.dart';
import 'package:um_campus_marketplace/utils/admin_data.dart';

void main() {
  test('hidden is independent of sold, archived and reserved states', () {
    for (final state in ['active', 'reserved', 'sold', 'archived']) {
      final row = <String, dynamic>{
        'is_sold': state == 'sold',
        'is_archived': state == 'archived',
        'reserved_by': state == 'reserved' ? 'buyer' : null,
        'moderation_status': 'hidden',
      };
      expect(adminMarketplaceStatus(row), state);
      expect(adminListingMatches(row, state), isTrue);
      expect(adminListingMatches(row, 'hidden'), isTrue);
      expect(adminListingMatches(row, 'all'), isTrue);
    }
  });
  test(
    'sold or archived listings with retained reservation are not reserved',
    () {
      expect(
        adminMarketplaceStatus({'is_sold': true, 'reserved_by': 'buyer'}),
        'sold',
      );
      expect(
        adminMarketplaceStatus({'is_archived': true, 'reserved_by': 'buyer'}),
        'archived',
      );
      expect(
        adminMarketplaceStatus({
          'listing_status': 'sold',
          'moderation_status': 'hidden',
        }),
        'sold',
      );
    },
  );
  test('missing values are distinguishable from real zero counts', () {
    expect(adminText({}, 'active_listings'), '—');
    expect(
      adminText({
        'active_listing_count': 0,
      }, 'active_listings|active_listing_count'),
      '0',
    );
    expect(adminMarketplaceStatus({}), 'unknown');
  });
}
