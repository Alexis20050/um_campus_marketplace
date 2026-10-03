import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:um_campus_marketplace/providers/admin_provider.dart';

class _Auth implements GoTrueClient {
  @override
  User? currentUser = User(
    id: 'self',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-01',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements SupabaseClient {
  final SupabaseClient delegate;
  _Client(this.delegate);
  @override
  final _Auth auth = _Auth();
  @override
  SupabaseQueryBuilder from(String table) => delegate.from(table);
  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) => delegate.rpc<T>(fn, params: params, get: get);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late HttpServer server;
  late SupabaseClient transport;
  late _Client client;
  late AdminProvider provider;
  late List<(String, dynamic)> calls;
  dynamic response;
  var status = 200;
  var role = 'admin';
  var accountStatus = 'active';
  var staff = true;

  void expectCalls(List<(String, dynamic)> expected) {
    expect(calls.length, expected.length);
    for (var index = 0; index < calls.length; index++) {
      expect(calls[index].$1, expected[index].$1);
      expect(calls[index].$2, expected[index].$2);
    }
  }

  setUp(() async {
    calls = [];
    response = <String, dynamic>{'id': 'target'};
    status = 200;
    role = 'admin';
    accountStatus = 'active';
    staff = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      calls.add((
        request.uri.path.split('/').last,
        body.isEmpty ? null : jsonDecode(body),
      ));
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = status;
      if (request.uri.path.endsWith('/profiles')) {
        request.response.write(
          jsonEncode({'role': role, 'account_status': accountStatus}),
        );
      } else if (request.uri.path.endsWith('/current_user_is_staff')) {
        request.response.write(jsonEncode(staff));
      } else {
        request.response.write(jsonEncode(response));
      }
      await request.response.close();
    });
    transport = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    client = _Client(transport);
    provider = AdminProvider(client: client);
  });

  tearDown(() async {
    provider.dispose();
    await transport.dispose();
    await server.close(force: true);
  });

  test('user detail exposes nested profile and activity fields', () async {
    final profile = {
      'id': 'user',
      'name': 'Student Seller',
      'email': 'student@example.com',
      'role': 'user',
      'account_status': 'suspended',
      'created_at': '2026-09-15',
    };
    final stats = {
      'active_listings': 4,
      'reserved_listings': 1,
      'sold_listings': 12,
      'archived_listings': 2,
      'hidden_listings': 0,
      'reports_received': 3,
      'reports_submitted': 0,
      'completed_sales': 10,
      'purchases': 5,
      'rating_count': 2,
      'average_rating': 4.5,
    };
    response = {'profile': profile, 'stats': stats};
    final detail = await provider.fetchUserDetail('user');
    for (final entry in {...profile, ...stats}.entries) {
      expect(detail[entry.key], entry.value, reason: entry.key);
    }
    expectCalls([
      ('admin_user_detail', {'p_user_id': 'user'}),
    ]);
  });

  test(
    'user detail still accepts flat and table-returning responses',
    () async {
      final row = {'id': 'user', 'active_listings': 0, 'sold_listings': 7};
      response = row;
      expect(await provider.fetchUserDetail('user'), row);
      response = [row];
      expect(await provider.fetchUserDetail('user'), row);
    },
  );

  test(
    'invalid nested activity is reported instead of showing blank counts',
    () async {
      for (final invalid in [
        {'profile': null, 'stats': <String, dynamic>{}},
        {
          'profile': {'id': 'user'},
          'stats': null,
        },
        {
          'profile': {'id': 'user'},
          'stats': [],
        },
      ]) {
        response = invalid;
        await expectLater(provider.fetchUserDetail('user'), throwsStateError);
      }
    },
  );

  test(
    'listing detail exposes grouped photos, product, seller and stats',
    () async {
      final product = {
        'id': 'listing',
        'seller_id': 'seller',
        'title': 'Textbook',
        'description': 'A used textbook',
        'price': 250,
        'category': 'Books',
        'item_condition': 'Good',
        'image_urls': ['https://example.com/photo.jpg'],
        'created_at': '2026-10-01',
        'is_sold': false,
        'is_archived': false,
        'moderation_status': 'hidden',
        'reserved_by': 'buyer',
        'reserved_conversation_id': 'conversation',
        'reserved_at': '2026-10-02',
      };
      for (final key in ['product', 'listing']) {
        response = {
          key: product,
          'seller': {
            'id': 'seller',
            'name': 'Student Seller',
            'email': 'seller@example.com',
            'avatar_url': 'https://example.com/avatar.jpg',
            'role': 'user',
            'account_status': 'active',
            'created_at': '2025-01-01',
          },
          'reserved_buyer': {
            'id': 'buyer',
            'name': 'Buyer',
            'email': 'buyer@example.com',
          },
          'stats': {'report_count': 0},
        };
        final detail = await provider.fetchListingDetail('listing');
        for (final entry in product.entries) {
          expect(detail[entry.key], entry.value, reason: entry.key);
        }
        expect(detail['seller_name'], 'Student Seller');
        expect(detail['seller_email'], 'seller@example.com');
        expect(detail['seller_avatar_url'], 'https://example.com/avatar.jpg');
        expect(detail['seller_role'], 'user');
        expect(detail['seller_account_status'], 'active');
        expect(detail['reserved_buyer_name'], 'Buyer');
        expect(detail['reserved_buyer_email'], 'buyer@example.com');
        expect(detail['report_count'], 0);
      }
    },
  );

  test(
    'listing detail preserves flat data and optional missing accounts',
    () async {
      final product = {
        'id': 'listing',
        'image_urls': <String>[],
        'title': 'Book',
      };
      response = product;
      expect(await provider.fetchListingDetail('listing'), product);
      response = {'product': product, 'seller': null, 'reserved_buyer': null};
      expect((await provider.fetchListingDetail('listing'))['title'], 'Book');
      response = {'product': null};
      await expectLater(
        provider.fetchListingDetail('listing'),
        throwsStateError,
      );
    },
  );

  test('all admin reads use the installed RPCs and exact parameters', () async {
    await provider.fetchDashboardStats();
    await provider.fetchUserDetail('user');
    response = [
      {'id': 'listing'},
    ];
    expect((await provider.fetchListingDetail('listing'))['id'], 'listing');
    await provider.fetchUsers(search: '  student  ');
    await provider.fetchUserListings('user');
    await provider.fetchListings(status: 'hidden', search: 'book');
    await provider.fetchListings(status: 'all', search: '  ');
    await provider.fetchReportsForUser('user');
    await provider.fetchReportsForListing('listing');
    expectCalls([
      ('admin_dashboard_stats', null),
      ('admin_user_detail', {'p_user_id': 'user'}),
      ('admin_listing_detail', {'p_product_id': 'listing'}),
      ('admin_users', {'p_search': 'student'}),
      ('admin_user_listings', {'p_user_id': 'user'}),
      ('admin_all_listings', {'p_status': 'hidden', 'p_search': 'book'}),
      ('admin_all_listings', {'p_status': null, 'p_search': null}),
      ('admin_reports_for_user', {'p_user_id': 'user'}),
      ('admin_reports_for_listing', {'p_product_id': 'listing'}),
    ]);
  });

  test(
    'mutations invalidate views and dismiss reuses the existing resolver',
    () async {
      response = null;
      await provider.setUserStatus(userId: 'user', status: 'suspended');
      await provider.setUserStatus(userId: 'user', status: 'active');
      await provider.setListingVisibility(
        productId: 'listing',
        status: 'hidden',
      );
      await provider.setListingVisibility(
        productId: 'listing',
        status: 'active',
      );
      await provider.dismissReport(
        reportId: 'report',
        note: '  Duplicate report: reviewed  ',
      );
      expect(provider.revision, 5);
      expectCalls([
        (
          'admin_set_user_status',
          {'p_user_id': 'user', 'p_status': 'suspended'},
        ),
        ('admin_set_user_status', {'p_user_id': 'user', 'p_status': 'active'}),
        (
          'admin_set_listing_visibility',
          {'p_product_id': 'listing', 'p_status': 'hidden'},
        ),
        (
          'admin_set_listing_visibility',
          {'p_product_id': 'listing', 'p_status': 'active'},
        ),
        (
          'admin_resolve_report',
          {
            'p_report_id': 'report',
            'p_action': 'dismiss',
            'p_note': 'Duplicate report: reviewed',
          },
        ),
      ]);
    },
  );

  test('self changes and invalid statuses never reach the server', () async {
    await expectLater(
      provider.setUserStatus(userId: 'self', status: 'suspended'),
      throwsStateError,
    );
    await expectLater(
      provider.setUserStatus(userId: 'self', status: 'active'),
      throwsStateError,
    );
    await expectLater(
      provider.setUserStatus(userId: 'user', status: 'deleted'),
      throwsArgumentError,
    );
    await expectLater(
      provider.setListingVisibility(productId: 'listing', status: 'sold'),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });

  test(
    'authorization errors stay readable and do not invalidate data',
    () async {
      status = 403;
      response = {'message': 'Staff access required.', 'code': '42501'};
      try {
        await provider.setListingVisibility(
          productId: 'listing',
          status: 'hidden',
        );
        fail('Expected denial');
      } catch (e) {
        expect(AdminProvider.friendlyError(e), 'Staff access required.');
      }
      expect(provider.revision, 0);
    },
  );

  test('staff access requires active role and backend authorization', () async {
    expect(await provider.isStaff(), isTrue);
    role = 'user';
    expect(await provider.isStaff(refresh: true), isFalse);
    role = 'moderator';
    accountStatus = 'suspended';
    expect(await provider.isStaff(refresh: true), isFalse);
    accountStatus = 'active';
    staff = false;
    expect(await provider.isStaff(refresh: true), isFalse);
    staff = true;
    expect(await provider.isStaff(refresh: true), isTrue);
    expect(provider.userStatusRestriction('other', 'moderator'), isNotNull);
    expect(provider.userStatusRestriction('other', 'admin'), isNotNull);
    expect(provider.userStatusRestriction('other', 'user'), isNull);
    client.auth.currentUser = null;
    expect(await provider.isStaff(), isFalse);
    expect(provider.staffRole, isNull);
  });

  test(
    'missing records and malformed responses are not fake empty data',
    () async {
      response = [];
      await expectLater(provider.fetchUserDetail('missing'), throwsStateError);
      response = null;
      await expectLater(
        provider.fetchListingDetail('missing'),
        throwsStateError,
      );
      response = {'unexpected': true};
      await expectLater(provider.fetchUsers(), throwsStateError);
    },
  );
}
