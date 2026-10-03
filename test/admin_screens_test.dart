import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:um_campus_marketplace/providers/admin_provider.dart';
import 'package:um_campus_marketplace/providers/rating_provider.dart';
import 'package:um_campus_marketplace/providers/auth_service.dart';
import 'package:um_campus_marketplace/screens/admin_main_screen.dart';
import 'package:um_campus_marketplace/screens/admin_listing_detail_screen.dart';
import 'package:um_campus_marketplace/screens/admin_reports_screen.dart';
import 'package:um_campus_marketplace/screens/admin_users_screen.dart';
import 'package:um_campus_marketplace/screens/admin_user_detail_screen.dart';
import 'package:um_campus_marketplace/screens/admin_listings_screen.dart';
import 'package:um_campus_marketplace/screens/admin_dashboard_screen.dart';
import 'package:um_campus_marketplace/screens/admin_search_screen.dart';
import 'package:um_campus_marketplace/theme/app_theme.dart';
import 'package:um_campus_marketplace/widgets/admin_widgets.dart';

class _Ratings extends RatingProvider {
  _Ratings(SupabaseClient client) : super(client: client);
  final updates = StreamController<List<Map<String, dynamic>>>.broadcast();
  List<Map<String, dynamic>> rows = [
    {'rating': 4, 'review': 'Existing buyer review'},
  ];
  final requestedSellers = <String>[];

  @override
  Stream<List<Map<String, dynamic>>> sellerRatingsStream(
    String sellerId,
  ) async* {
    requestedSellers.add(sellerId);
    yield rows;
    yield* updates.stream;
  }

  @override
  void dispose() {
    updates.close();
    super.dispose();
  }
}

class _Admin extends AdminProvider {
  _Admin(SupabaseClient client) : super(client: client);
  bool allowed = true;
  int changes = 0;
  int listingLoads = 0;
  int userLoads = 0;
  int dashboardLoads = 0;
  String accountStatus = 'active';
  String? lastListingStatus;
  String? lastListingSearch;
  final userRows = <Map<String, dynamic>>[];
  final listingRows = <Map<String, dynamic>>[];
  Object? usersError;
  @override
  Future<Map<String, dynamic>> fetchUserDetail(String userId) async => {
    'id': userId,
    'name': 'Alexis Palicte',
    'email': 'alexis@umindanao.edu.ph',
    'role': 'user',
    'account_status': accountStatus,
    'active_listings': 4,
    'reserved_listings': 1,
    'sold_listings': 12,
    'archived_listings': 2,
    'hidden_listings': 0,
    'completed_sales': 12,
    'purchases': 5,
    'reports_received': 2,
    'reports_submitted': 1,
    'average_rating': 4.8,
    'rating_count': 12,
    'created_at': '2026-09-15',
  };
  @override
  Future<List<Map<String, dynamic>>> fetchUserListings(String userId) async =>
      listingRows;
  @override
  Future<void> setUserStatus({
    required String userId,
    required String status,
  }) async {
    accountStatus = status;
    changes++;
    notifyListeners();
  }

  String visibility = 'active';
  List<String> listingImages = [];
  String? resolvedNote;
  String? resolvedAction;
  String? scopedUser;
  bool immediateUsers = false;
  @override
  String? get staffRole => 'moderator';
  final searches = <String?, Completer<List<Map<String, dynamic>>>>{};
  @override
  int get revision => changes;
  @override
  Future<bool> isStaff({bool refresh = false}) async => allowed;
  @override
  Future<List<Map<String, dynamic>>> fetchUsers({String? search}) {
    userLoads++;
    if (usersError != null) return Future.error(usersError!);
    return immediateUsers
        ? Future.value(userRows)
        : (searches[search] = Completer<List<Map<String, dynamic>>>()).future;
  }

  @override
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    dashboardLoads++;
    return {
      'total_users': 128,
      'active_users': 121,
      'total_listings': 482,
      'active_listings': 315,
      'reserved_listings': 24,
      'sold_listings': 121,
      'archived_listings': 9,
      'hidden_listings': 22,
      'pending_reports': 6,
      'suspended_users': 7,
      'moderators': 2,
      'admins': 1,
      'completed_transactions': 121,
      'resolved_reports': 14,
      'dismissed_reports': 3,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchListings({
    String? status,
    String? search,
  }) async {
    lastListingStatus = status;
    lastListingSearch = search;
    return listingRows;
  }

  @override
  Future<Map<String, dynamic>> fetchListingDetail(String productId) async {
    listingLoads++;
    return {
      'id': productId,
      'title': 'Textbook',
      'price': 120,
      'is_sold': true,
      'is_archived': false,
      'moderation_status': visibility,
      'seller_name': 'Student',
      'seller_id': 'seller',
      'report_count': 2,
      'image_urls': listingImages,
    };
  }

  @override
  Future<void> setListingVisibility({
    required String productId,
    required String status,
  }) async {
    visibility = status;
    changes++;
    notifyListeners();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReports({
    String status = 'pending',
  }) async => [
    if (resolvedAction == null)
      {
        'report_id': 'report',
        'target_type': 'listing',
        'product_id': 'listing',
        'product_title': 'Textbook',
        'reason': 'Spam',
        'details': 'Repeated posts for the same item.',
        'reporter_name': 'Juan Dela Cruz',
        'reported_user_id': 'reported-student',
        'reported_user_name': 'Alexis Palicte',
        'reported_user_role': 'user',
        'created_at': '2026-09-28',
        'status': 'pending',
      },
  ];
  @override
  Future<List<Map<String, dynamic>>> fetchReportsForUser(String userId) async {
    scopedUser = userId;
    return fetchReports();
  }

  @override
  Future<void> resolveReport({
    required String reportId,
    required String action,
    String? note,
  }) async {
    resolvedAction = action;
    resolvedNote = note;
    changes++;
    notifyListeners();
  }
}

class _AuthService extends ChangeNotifier implements AuthService {
  int signOuts = 0;
  @override
  Future<void> signOut() async {
    signOuts++;
  }

  @override
  String? get profileName => 'Moderator';
  @override
  User? get user => User(
    id: 'staff',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-01',
    email: 'staff@umindanao.edu.ph',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fontDir = String.fromEnvironment('ADMIN_PREVIEW_FONT_DIR');
    if (const bool.fromEnvironment('ADMIN_CAPTURE') && fontDir.isNotEmpty) {
      for (final entry in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(
            File(
              '$fontDir/${entry.value}',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    }
  });
  late SupabaseClient client;
  late _Admin admin;
  late _Ratings ratings;
  setUp(() {
    client = SupabaseClient('http://localhost', 'test-key');
    admin = _Admin(client);
    ratings = _Ratings(client);
  });
  tearDown(() async {
    admin.dispose();
    ratings.dispose();
    await client.dispose();
  });

  Widget adminScope({required AdminProvider value, required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminProvider>.value(value: value),
        ChangeNotifierProvider<RatingProvider>.value(value: ratings),
      ],
      child: child,
    );
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      adminScope(
        value: admin,
        child: MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'five admin tabs use the root providers and show the actual role',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      admin.immediateUsers = true;
      final auth = _AuthService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: admin),
            ChangeNotifierProvider<RatingProvider>.value(value: ratings),
            ChangeNotifierProvider<AuthService>.value(value: auth),
          ],
          child: const MaterialApp(home: AdminMainScreen()),
        ),
      );
      await tester.pumpAndSettle();
      for (final title in [
        'Dashboard',
        'Reports',
        'Users',
        'Listings',
        'Account',
      ]) {
        final tab = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(title),
        );
        expect(tab, findsOneWidget);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('MODERATOR'), findsOneWidget);
      expect(find.text('Sell'), findsNothing);
      expect(find.text('Favorites'), findsNothing);
      expect(find.text('My Listings'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets('nonstaff cannot load an admin detail screen', (tester) async {
    admin.allowed = false;
    await show(tester, const AdminListingDetailScreen(productId: 'listing'));
    expect(find.text('Staff access required.'), findsOneWidget);
    expect(admin.listingLoads, 0);
    expect(find.text('Hide Listing'), findsNothing);
  });

  testWidgets('search debounces and ignores an older response', (tester) async {
    await tester.pumpWidget(
      adminScope(
        value: admin,
        child: const MaterialApp(home: AdminUsersScreen()),
      ),
    );
    await tester.pump();
    admin.searches['']!.complete([]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 100));
    expect(admin.searches.containsKey('new'), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    admin.searches['new']!.complete([
      {'id': 'new', 'name': 'New Student'},
    ]);
    await tester.pumpAndSettle();
    admin.searches['old']!.complete([
      {'id': 'old', 'name': 'Old Student'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('New Student'), findsOneWidget);
    expect(find.text('Old Student'), findsNothing);
  });

  testWidgets('global admin search uses existing queries and opens results', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    admin.immediateUsers = true;
    admin.userRows.add({
      'id': 'student',
      'name': 'Alexis Palicte',
      'email': 'alexis@umindanao.edu.ph',
      'account_status': 'active',
    });
    admin.listingRows.add({
      'id': 'listing',
      'title': 'MacBook Air',
      'seller_name': 'Alexis Palicte',
      'price': 32500,
      'moderation_status': 'active',
      'listing_status': 'active',
    });
    await show(tester, const AdminSearchScreen());
    expect(admin.userLoads, 0);
    await tester.enterText(find.byType(TextField), 'Alexis');
    await tester.pump(const Duration(milliseconds: 100));
    expect(admin.userLoads, 0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(admin.userLoads, 1);
    expect(admin.lastListingSearch, 'Alexis');
    expect(find.text('Alexis Palicte'), findsWidgets);
    await tester.ensureVisible(find.text('MacBook Air'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MacBook Air'));
    await tester.pumpAndSettle();
    expect(admin.listingLoads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'listing hide requires confirmation and refreshes without changing sold state',
    (tester) async {
      await show(tester, const AdminListingDetailScreen(productId: 'listing'));
      await tester.scrollUntilVisible(find.text('Hide Listing'), 450);
      await tester.ensureVisible(find.text('Hide Listing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide Listing'));
      await tester.pumpAndSettle();
      expect(admin.visibility, 'active');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(admin.visibility, 'active');
      await tester.tap(find.text('Hide Listing'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Hide Listing'),
        ),
      );
      await tester.pumpAndSettle();
      expect(admin.visibility, 'hidden');
      expect(admin.listingLoads, 2);
      await tester.scrollUntilVisible(find.text('SOLD'), -300);
      expect(find.text('SOLD'), findsOneWidget);
      expect(find.text('HIDDEN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('related reports reuse dismiss with preset and custom note', (
    tester,
  ) async {
    await show(tester, const AdminReportsScreen(userId: 'user'));
    expect(admin.scopedUser, 'user');
    expect(find.text('Dismiss'), findsNothing);
    await tester.tap(find.text('Review Report'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dismiss'), 250);
    await tester.ensureVisible(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate report').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Reviewed earlier');
    await tester.tap(find.widgetWithText(FilledButton, 'Dismiss'));
    await tester.pumpAndSettle();
    expect(admin.resolvedAction, 'dismiss');
    expect(admin.resolvedNote, 'Duplicate report: Reviewed earlier');
    expect(find.text('No reports found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful mutations refresh every mounted data view', (
    tester,
  ) async {
    var firstLoads = 0;
    var secondLoads = 0;
    await show(
      tester,
      Scaffold(
        body: Column(
          children: [
            Expanded(
              child: AdminDataView<int>(
                load: (_) async => ++firstLoads,
                builder: (_, count) =>
                    ListView(children: [Text('First $count')]),
              ),
            ),
            Expanded(
              child: AdminDataView<int>(
                load: (_) async => ++secondLoads,
                builder: (_, count) =>
                    ListView(children: [Text('Second $count')]),
              ),
            ),
          ],
        ),
      ),
    );
    await admin.setListingVisibility(productId: 'listing', status: 'hidden');
    await tester.pumpAndSettle();
    expect(find.text('First 2'), findsOneWidget);
    expect(find.text('Second 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'user filters are local and clearing search reloads the full query',
    (tester) async {
      admin.immediateUsers = true;
      admin.userRows.addAll([
        {
          'id': 'a',
          'name': 'Active Student',
          'role': 'user',
          'account_status': 'active',
        },
        {
          'id': 'b',
          'name': 'Suspended Student',
          'role': 'user',
          'account_status': 'suspended',
        },
        {
          'id': 'c',
          'name': 'Campus Moderator',
          'role': 'moderator',
          'account_status': 'active',
        },
        {
          'id': 'd',
          'name': 'Campus Admin',
          'role': 'admin',
          'account_status': 'active',
        },
      ]);
      await show(tester, const AdminUsersScreen());
      for (final entry in {
        'Suspended': 'Suspended Student',
        'Moderators': 'Campus Moderator',
        'Admins': 'Campus Admin',
      }.entries) {
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, entry.key));
        await tester.tap(find.widgetWithText(ChoiceChip, entry.key));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Active Student'), findsNothing);
      }
      expect(admin.userLoads, 1);
      await tester.enterText(find.byType(TextField), 'Alexis');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(admin.userLoads, 2);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(admin.userLoads, 3);
    },
  );

  testWidgets(
    'listing filters and debounced search preserve provider parameters',
    (tester) async {
      await show(tester, const AdminListingsScreen());
      for (final status in [
        'Active',
        'Reserved',
        'Sold',
        'Archived',
        'Hidden',
        'All',
      ]) {
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, status));
        await tester.tap(find.widgetWithText(ChoiceChip, status));
        await tester.pumpAndSettle();
        expect(admin.lastListingStatus, status.toLowerCase());
      }
      await tester.enterText(find.byType(TextField), '  textbook  ');
      await tester.pump(const Duration(milliseconds: 100));
      expect(admin.lastListingSearch, '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(admin.lastListingSearch, 'textbook');
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(admin.lastListingSearch, '');
    },
  );

  testWidgets('admin profile shows saved ratings and live updates', (
    tester,
  ) async {
    await show(tester, const AdminUserDetailScreen(userId: 'student'));
    await tester.scrollUntilVisible(find.text('Existing buyer review'), 200);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('1 rating'), findsOneWidget);
    expect(ratings.requestedSellers, contains('student'));

    ratings.rows = [
      {'rating': 2, 'review': 'New buyer review'},
      ...ratings.rows,
    ];
    ratings.updates.add(ratings.rows);
    await tester.pumpAndSettle();
    expect(find.text('3.0'), findsOneWidget);
    expect(find.text('2 ratings'), findsOneWidget);
    expect(find.text('New buyer review'), findsOneWidget);
    expect(find.textContaining('Seller rating: 4.8'), findsNothing);
  });

  testWidgets('admin user list reads saved seller ratings', (tester) async {
    admin.immediateUsers = true;
    admin.userRows.add({
      'id': 'student',
      'name': 'Rated seller',
      'average_rating': 1,
    });
    await show(tester, const AdminUsersScreen());
    expect(find.text('4.0 / 5 (1 rating)'), findsOneWidget);
    expect(ratings.requestedSellers, contains('student'));
  });

  testWidgets('admin listing reads saved seller ratings', (tester) async {
    await show(tester, const AdminListingDetailScreen(productId: 'listing'));
    await tester.scrollUntilVisible(find.text('4.0 / 5 (1 rating)'), 250);
    expect(find.text('4.0 / 5 (1 rating)'), findsOneWidget);
  });

  testWidgets('user suspend and restore require explicit confirmation', (
    tester,
  ) async {
    await show(tester, const AdminUserDetailScreen(userId: 'student'));
    await tester.scrollUntilVisible(find.text('Suspend User'), 400);
    await tester.tap(find.text('Suspend User'));
    await tester.pumpAndSettle();
    expect(find.text('Suspend Alexis Palicte?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(admin.accountStatus, 'active');
    for (final action in ['Suspend User', 'Restore User']) {
      await tester.scrollUntilVisible(find.text(action), 300);
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(action),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        admin.accountStatus,
        action == 'Suspend User' ? 'suspended' : 'active',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('listing restore keeps the sale state', (tester) async {
    admin.visibility = 'hidden';
    await show(tester, const AdminListingDetailScreen(productId: 'listing'));
    await tester.scrollUntilVisible(find.text('Restore Listing'), 400);
    await tester.ensureVisible(find.text('Restore Listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore Listing'));
    await tester.pumpAndSettle();
    expect(admin.visibility, 'hidden');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Restore Listing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(admin.visibility, 'active');
    await tester.scrollUntilVisible(find.text('SOLD'), -300);
    expect(find.text('VISIBLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh retains content and failed loads offer a working retry',
    (tester) async {
      await tester.pumpWidget(
        adminScope(
          value: admin,
          child: MaterialApp(theme: lightTheme, home: const AdminUsersScreen()),
        ),
      );
      await tester.pump();
      admin.searches['']!.complete([
        {'id': 'student', 'name': 'Existing Student'},
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh users'));
      await tester.pump();
      expect(find.text('Existing Student'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      admin.searches['']!.completeError(
        const FormatException('Internal server details'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load users'), findsOneWidget);
      expect(find.text('Existing Student'), findsOneWidget);
      expect(find.textContaining('Internal server details'), findsNothing);
      admin.immediateUsers = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('No users matched your search or filter.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'navigation resize preserves search, selected filter and data state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      admin.immediateUsers = true;
      final auth = _AuthService();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: admin),
            ChangeNotifierProvider<RatingProvider>.value(value: ratings),
            ChangeNotifierProvider<AuthService>.value(value: auth),
          ],
          child: MaterialApp(theme: lightTheme, home: const AdminMainScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Users'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alexis');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Suspended'));
      await tester.pumpAndSettle();
      final usersState = tester.state(find.byType(AdminUsersScreen));
      final loads = admin.userLoads;
      for (final width in [800.0, 1440.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(
          identical(tester.state(find.byType(AdminUsersScreen)), usersState),
          isTrue,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Alexis',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Suspended'))
              .selected,
          isTrue,
        );
        expect(admin.userLoads, loads);
        expect(admin.dashboardLoads, 1);
        expect(
          find.byType(width >= 800 ? NavigationRail : NavigationBar),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets('account sign out requires confirmation', (tester) async {
    admin.immediateUsers = true;
    final auth = _AuthService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminProvider>.value(value: admin),
          ChangeNotifierProvider<RatingProvider>.value(value: ratings),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: MaterialApp(theme: lightTheme, home: const AdminMainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Account'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign Out', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sign Out'),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  for (final dark in [false, true]) {
    for (final width in [360.0, 800.0, 1440.0]) {
      testWidgets('admin layouts at $width in ${dark ? 'dark' : 'light'} mode', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        admin.immediateUsers = true;
        admin.userRows.add({
          'id': 'student',
          'name': 'Alexis Palicte',
          'email': 'alexis@umindanao.edu.ph',
          'role': 'moderator',
          'account_status': 'suspended',
          'active_listings': 6,
          'reports_received': 4,
        });
        admin.listingRows.add({
          'id': 'listing',
          'title': 'MacBook Air M1 with charger and protective case',
          'price': 32500,
          'seller_name': 'Alexis Palicte',
          'listing_status': 'reserved',
          'moderation_status': 'hidden',
          'report_count': 2,
          'created_at': '2026-09-28',
        });
        final auth = _AuthService();
        final boundary = GlobalKey();
        final screens = <String, Widget>{
          'dashboard': const AdminMainScreen(),
          'users': const AdminUsersScreen(),
          'listings': const AdminListingsScreen(),
          'user-detail': const AdminUserDetailScreen(userId: 'student'),
          'listing-detail': const AdminListingDetailScreen(
            productId: 'listing',
          ),
          'reports': const AdminReportsScreen(),
          'search': const AdminSearchScreen(),
          'report-detail': const AdminReportsScreen(reportId: 'report'),
        };
        for (final entry in screens.entries) {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AdminProvider>.value(value: admin),
                ChangeNotifierProvider<RatingProvider>.value(value: ratings),
                ChangeNotifierProvider<AuthService>.value(value: auth),
              ],
              child: MaterialApp(
                theme: (dark ? darkTheme : lightTheme).copyWith(
                  textTheme: (dark ? darkTheme : lightTheme).textTheme.apply(
                    fontFamily: const bool.fromEnvironment('ADMIN_CAPTURE')
                        ? 'Roboto'
                        : null,
                  ),
                ),
                home: RepaintBoundary(key: boundary, child: entry.value),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: entry.key);
          if (const bool.fromEnvironment('ADMIN_CAPTURE')) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/admin_previews/${entry.key}-${width.toInt()}-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          // Exercise content below the fold as well as the initial viewport.
          final lists = find.byType(ListView);
          if (lists.evaluate().isNotEmpty) {
            await tester.drag(lists.first, const Offset(0, -1800));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} after scrolling',
            );
          }
          await tester.pumpWidget(const SizedBox());
        }
        auth.dispose();
      });
    }
  }

  testWidgets(
    'mobile details and dashboard support larger accessibility text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final screen in [
        const AdminDashboardScreen(),
        const AdminUserDetailScreen(userId: 'student'),
        const AdminListingDetailScreen(productId: 'listing'),
      ]) {
        await tester.pumpWidget(
          adminScope(
            value: admin,
            child: MaterialApp(
              theme: darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final action in {
    'Hide Listing': 'hide_listing',
    'Suspend User': 'suspend_user',
  }.entries) {
    testWidgets(
      'report ${action.key} requires confirmation and preserves the note',
      (tester) async {
        await show(tester, const AdminReportsScreen(reportId: 'report'));
        await tester.scrollUntilVisible(find.text(action.key), 250);
        await tester.ensureVisible(find.text(action.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(admin.resolvedAction, isNull);
        await tester.ensureVisible(find.text(action.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action.key));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Reviewed the report evidence',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(action.key),
          ),
        );
        await tester.pumpAndSettle();
        expect(admin.resolvedAction, action.value);
        expect(admin.resolvedNote, 'Reviewed the report evidence');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('gallery has accessible controls and survives missing images', (
    tester,
  ) async {
    admin.listingImages = [
      'https://example.invalid/first.jpg',
      'https://example.invalid/second.jpg',
    ];
    await show(tester, const AdminListingDetailScreen(productId: 'listing'));
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Next image'));
    await tester.tap(find.byTooltip('Next image'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous image'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
