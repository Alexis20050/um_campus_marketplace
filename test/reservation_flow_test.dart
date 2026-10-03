import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:um_campus_marketplace/models/product.dart';
import 'package:um_campus_marketplace/providers/auth_service.dart';
import 'package:um_campus_marketplace/providers/product_provider.dart';
import 'package:um_campus_marketplace/providers/rating_provider.dart';
import 'package:um_campus_marketplace/providers/message_provider.dart';
import 'package:um_campus_marketplace/providers/favorites_provider.dart';
import 'package:um_campus_marketplace/screens/my_listings_screen.dart';
import 'package:um_campus_marketplace/screens/product_detail_screen.dart';
import 'package:um_campus_marketplace/widgets/product_card.dart';
import 'package:um_campus_marketplace/theme/app_theme.dart';

const buyerA = SaleBuyerCandidate(
  conversationId: 'conversation-a',
  buyerId: 'buyer-a',
  buyerName: 'Juan Dela Cruz',
);
const buyerB = SaleBuyerCandidate(
  conversationId: 'conversation-b',
  buyerId: 'buyer-b',
  buyerName: 'Maria Santos',
);

Product item() => Product(
  id: 'listing',
  sellerId: 'seller',
  sellerName: 'Seller',
  title: 'Campus Textbook',
  description: 'A useful textbook.',
  price: 150,
  category: 'Books',
  itemCondition: 'Good',
  imageUrls: const [],
  createdAt: DateTime(2026, 9, 28),
);

class _Products extends ChangeNotifier implements ProductProvider {
  Product value = item();
  final updates = StreamController<List<Product>>.broadcast();
  int streamStarts = 0;
  int refreshes = 0;
  int reserves = 0;
  int cancels = 0;
  bool failReserve = false;
  Completer<void>? reserveGate;
  @override
  String? get currentUserId => 'seller';
  @override
  List<Product> get products => [value];
  @override
  Stream<List<Product>> sellerAllProductsStream(String sellerId) {
    streamStarts++;
    return Stream.multi((controller) {
      controller.add([value]);
      final subscription = updates.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<List<Product>> fetchSellerProducts(String sellerId) async {
    refreshes++;
    return [value];
  }

  @override
  Future<Product?> fetchProductById(String productId) async => value;
  @override
  Future<void> reserveProduct({required String conversationId}) async {
    reserves++;
    await reserveGate?.future;
    if (failReserve) throw Exception('RPC failed');
    final buyer = conversationId == buyerA.conversationId ? buyerA : buyerB;
    value = value.copyWith(
      reservedBy: buyer.buyerId,
      reservedConversationId: conversationId,
      reservedAt: DateTime(2026, 10, 1),
    );
    // Deliberately do not emit realtime: the successful action must refresh itself.
  }

  @override
  Future<void> cancelReservation(String productId) async {
    cancels++;
    value = value.copyWith(clearReservation: true);
  }

  @override
  Future<void> archiveProduct(String productId) async {
    value = value.copyWith(isArchived: true);
  }

  @override
  Future<void> restoreProduct(String productId) async {
    value = value.copyWith(isArchived: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ratings extends ChangeNotifier implements RatingProvider {
  final _Products products;
  _Ratings(this.products);
  List<SaleBuyerCandidate> candidates = [buyerA, buyerB];
  Completer<List<SaleBuyerCandidate>>? candidateGate;
  int loads = 0;
  String? completedConversation;
  @override
  Future<List<SaleBuyerCandidate>> fetchBuyersForProduct(
    String productId,
  ) async {
    loads++;
    return candidateGate?.future ?? candidates;
  }

  @override
  Future<String> completeSale({required String conversationId}) async {
    completedConversation = conversationId;
    products.value = products.value.copyWith(
      isSold: true,
      clearReservation: true,
    );
    return 'verified-transaction';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthService {
  String id = 'seller';
  @override
  User? get user => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-09-01',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messages extends ChangeNotifier implements MessageProvider {
  int calls = 0;
  @override
  Future<String> getOrCreateConversation({
    required String productId,
    required String sellerId,
  }) async {
    calls++;
    throw StateError(
      'Messaging is unavailable because a user has blocked the other.',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Favorites extends ChangeNotifier implements FavoritesProvider {
  @override
  bool isFavorite(String productId) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> settle(WidgetTester tester) async {
  // The listing remains busy while a modal is open; its progress animation is intentional.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Finder reserveButton() => find.ancestor(
  of: find.text('Reserve Item'),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

void main() {
  late _Products products;
  late _Ratings ratings;
  late _Auth auth;
  late _Messages messages;
  late _Favorites favorites;
  setUp(() {
    products = _Products();
    ratings = _Ratings(products);
    auth = _Auth();
    messages = _Messages();
    favorites = _Favorites();
  });
  tearDown(() async {
    await products.updates.close();
    products.dispose();
    ratings.dispose();
    auth.dispose();
    messages.dispose();
    favorites.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    Widget? screen,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductProvider>.value(value: products),
          ChangeNotifierProvider<RatingProvider>.value(value: ratings),
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<MessageProvider>.value(value: messages),
          ChangeNotifierProvider<FavoritesProvider>.value(value: favorites),
        ],
        child: MaterialApp(
          theme: dark ? darkTheme : lightTheme,
          home: screen ?? const MyListingsScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> select(
    WidgetTester tester,
    String action,
    SaleBuyerCandidate buyer,
  ) async {
    await tester.tap(find.text(action));
    await settle(tester);
    await tester.tap(find.text(buyer.buyerName));
    await settle(tester);
  }

  Future<void> confirm(WidgetTester tester, String action) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(action),
      ),
    );
    await settle(tester);
  }

  void reserved() {
    products.value = products.value.copyWith(
      reservedBy: buyerA.buyerId,
      reservedConversationId: buyerA.conversationId,
      reservedAt: DateTime(2026, 10, 1),
    );
  }

  test(
    'reservation fields and eligibility distinguish reserved, hidden, sold and archived',
    () {
      final parsed = Product.fromMap({
        'id': 'p',
        'seller_id': 'seller',
        'price': 10,
        'created_at': '2026-09-28',
        'reserved_by': 'buyer-a',
        'reserved_conversation_id': 'conversation-a',
        'reserved_at': '2026-10-01T00:00:00Z',
        'moderation_status': 'hidden',
      });
      expect(parsed.reservedBy, 'buyer-a');
      expect(parsed.reservedConversationId, 'conversation-a');
      expect(parsed.reservedAt, DateTime.utc(2026, 10, 1));
      expect(parsed.canReserve, isFalse);
      expect(parsed.canCancelReservation, isTrue);
      expect(parsed.copyWith(isSold: true).isReserved, isFalse);
      expect(parsed.copyWith(isArchived: true).canCancelReservation, isFalse);
      expect(item().canReserve, isTrue);
      expect(item().copyWith(reservedBy: ' ').isReserved, isFalse);
      final cleared = parsed.copyWith(
        clearReservation: true,
        moderationStatus: 'active',
      );
      expect(cleared.reservedBy, isNull);
      expect(cleared.reservedConversationId, isNull);
      expect(cleared.reservedAt, isNull);
      expect(cleared.canReserve, isTrue);
    },
  );

  testWidgets(
    'active actions are visible without opening an overflow menu or fetching buyers',
    (tester) async {
      await show(tester);
      for (final label in [
        'Edit',
        'Reserve Item',
        'Complete Sale',
        'Archive',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Mark Sold'), findsNothing);
      expect(find.text('Mark Available'), findsNothing);
      expect(ratings.loads, 0);
    },
  );

  testWidgets(
    'no buyers explains eligibility and keeps Reserve Item available',
    (tester) async {
      ratings.candidates = [];
      await show(tester);
      await tester.tap(find.text('Reserve Item'));
      await settle(tester);
      expect(
        find.text('No buyers have messaged you about this listing yet.'),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(reserveButton(), findsOneWidget);
      expect(products.reserves, 0);
      expect(products.streamStarts, 1);
    },
  );

  testWidgets(
    'reserve then cancel refreshes the visible listing without realtime or new subscriptions',
    (tester) async {
      await show(tester);
      await select(tester, 'Reserve Item', buyerA);
      expect(
        find.text('Reserve this item for Juan Dela Cruz?'),
        findsOneWidget,
      );
      expect(products.reserves, 0);
      await confirm(tester, 'Reserve Item');
      expect(products.value.reservedBy, buyerA.buyerId);
      expect(products.value.reservedConversationId, buyerA.conversationId);
      expect(find.text('RESERVED'), findsOneWidget);
      expect(find.text('Reserved on Oct 1, 2026'), findsOneWidget);
      for (final label in ['Edit', 'Complete Sale', 'Cancel Reservation']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Reserve Item'), findsNothing);
      expect(find.text('Archive'), findsNothing);
      await tester.tap(find.text('Cancel Reservation'));
      await settle(tester);
      expect(products.cancels, 0);
      await confirm(tester, 'Cancel Reservation');
      expect(products.value.reservedBy, isNull);
      expect(products.value.reservedConversationId, isNull);
      expect(products.value.reservedAt, isNull);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Reserve Item'), findsOneWidget);
      expect(find.text('Reservation cancelled.'), findsOneWidget);
      expect(products.refreshes, 2);
      expect(products.streamStarts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissed picker and confirmation do not reserve or refresh', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('Reserve Item'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await select(tester, 'Reserve Item', buyerA);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(products.reserves, 0);
    expect(products.refreshes, 0);
  });

  testWidgets(
    'reserved sale only offers the exact reserved buyer and conversation',
    (tester) async {
      reserved();
      ratings.candidates.add(
        const SaleBuyerCandidate(
          conversationId: 'another-conversation',
          buyerId: 'buyer-a',
          buyerName: 'Wrong conversation',
        ),
      );
      await show(tester);
      await tester.tap(find.text('Complete Sale'));
      await settle(tester);
      expect(find.text(buyerA.buyerName), findsOneWidget);
      expect(find.text(buyerB.buyerName), findsNothing);
      expect(find.text('Wrong conversation'), findsNothing);
      await tester.tap(find.text(buyerA.buyerName));
      await settle(tester);
      await confirm(tester, 'Complete Sale');
      expect(ratings.completedConversation, buyerA.conversationId);
      expect(products.value.isSold, isTrue);
      await tester.tap(find.text('Sold 1'));
      await settle(tester);
      expect(find.text('SOLD'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Reserve Item'), findsNothing);
    },
  );

  testWidgets(
    'reservation changed during confirmation blocks a sale to the wrong buyer',
    (tester) async {
      await show(tester);
      await select(tester, 'Complete Sale', buyerB);
      reserved();
      await confirm(tester, 'Complete Sale');
      expect(ratings.completedConversation, isNull);
      expect(
        find.text('Cancel the reservation before choosing another buyer.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ineligible or missing reserved buyer never falls back to another candidate',
    (tester) async {
      reserved();
      ratings.candidates = [buyerB];
      await show(tester);
      await tester.tap(find.text('Complete Sale'));
      await settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(ratings.completedConversation, isNull);
      expect(
        find.textContaining('The reserved buyer is unavailable.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('candidate loading and reserve requests cannot be repeated', (
    tester,
  ) async {
    ratings.candidateGate = Completer<List<SaleBuyerCandidate>>();
    products.reserveGate = Completer<void>();
    await show(tester);
    await tester.tap(find.text('Reserve Item'));
    await tester.pump();
    expect(tester.widget<FilledButton>(reserveButton()).onPressed, isNull);
    expect(ratings.loads, 1);
    ratings.candidateGate!.complete([buyerA]);
    await settle(tester);
    await tester.tap(find.text(buyerA.buyerName));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Reserve Item'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(products.reserves, 1);
    expect(tester.widget<FilledButton>(reserveButton()).onPressed, isNull);
    products.reserveGate!.complete();
    await settle(tester);
    expect(find.text('RESERVED'), findsOneWidget);
  });

  testWidgets('failed reservation keeps active state and permits retry', (
    tester,
  ) async {
    products.failReserve = true;
    await show(tester);
    await select(tester, 'Reserve Item', buyerA);
    await confirm(tester, 'Reserve Item');
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('RESERVED'), findsNothing);
    expect(tester.widget<FilledButton>(reserveButton()).onPressed, isNotNull);
    products.failReserve = false;
    await select(tester, 'Reserve Item', buyerA);
    await confirm(tester, 'Reserve Item');
    expect(find.text('RESERVED'), findsOneWidget);
  });

  testWidgets('sold, archived and hidden listings never offer reservation', (
    tester,
  ) async {
    products.value = item().copyWith(moderationStatus: 'hidden');
    await show(tester);
    expect(find.text('Reserve Item'), findsNothing);
    expect(find.text('Complete Sale'), findsNothing);
    expect(find.text('HIDDEN'), findsOneWidget);
    products.value = item().copyWith(isSold: true);
    products.updates.add([products.value]);
    await settle(tester);
    await tester.tap(find.text('Sold 1'));
    await settle(tester);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    products.value = item().copyWith(isArchived: true);
    products.updates.add([products.value]);
    await settle(tester);
    await tester.tap(find.text('Archived 1'));
    await settle(tester);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Reserve Item'), findsNothing);
  });

  testWidgets(
    'reserved public card and detail keep messaging through existing block checks',
    (tester) async {
      reserved();
      auth.id = 'buyer-b';
      await show(
        tester,
        screen: Scaffold(body: ProductCard(product: products.value)),
      );
      expect(find.text('RESERVED'), findsOneWidget);
      expect(find.text('SOLD'), findsNothing);
      await tester.tap(find.text('Campus Textbook'));
      await settle(tester);
      expect(find.text('RESERVED'), findsOneWidget);
      expect(
        find.text(
          'Reserved for another buyer. You can still message the seller.',
        ),
        findsOneWidget,
      );
      expect(find.text('Complete Sale'), findsNothing);
      await tester.tap(find.text('Message Seller'));
      await settle(tester);
      expect(messages.calls, 1);
      expect(find.textContaining('Messaging is unavailable'), findsOneWidget);
    },
  );

  testWidgets('reserved buyer sees their reservation in product detail', (
    tester,
  ) async {
    reserved();
    auth.id = 'buyer-a';
    await show(tester, screen: ProductDetailScreen(product: products.value));
    expect(find.text('This item is reserved for you.'), findsOneWidget);
    expect(find.text('Message Seller'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'seller actions and picker fit a narrow ${dark ? 'dark' : 'light'} screen',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await show(tester, dark: dark);
        expect(tester.takeException(), isNull);
        await select(tester, 'Reserve Item', buyerA);
        expect(tester.takeException(), isNull);
        await confirm(tester, 'Reserve Item');
        expect(tester.takeException(), isNull);
        expect(find.text('RESERVED'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'active sale still allows choosing an actual conversation buyer',
    (tester) async {
      await show(tester);
      await select(tester, 'Complete Sale', buyerB);
      await confirm(tester, 'Complete Sale');
      expect(ratings.completedConversation, buyerB.conversationId);
      expect(products.value.isSold, isTrue);
      expect(products.streamStarts, 1);
    },
  );

  testWidgets('declining cancellation leaves the reservation intact', (
    tester,
  ) async {
    reserved();
    await show(tester);
    await tester.tap(find.text('Cancel Reservation'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await settle(tester);
    expect(products.cancels, 0);
    expect(find.text('RESERVED'), findsOneWidget);
  });

  testWidgets('late buyer response is ignored after leaving the screen', (
    tester,
  ) async {
    ratings.candidateGate = Completer<List<SaleBuyerCandidate>>();
    await show(tester);
    await tester.tap(find.text('Reserve Item'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    ratings.candidateGate!.complete([buyerA]);
    await settle(tester);
    expect(products.reserves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'open detail follows reservation and cancellation using the existing provider',
    (tester) async {
      auth.id = 'buyer-a';
      await show(tester, screen: ProductDetailScreen(product: products.value));
      expect(find.text('RESERVED'), findsNothing);
      reserved();
      products.notifyListeners();
      await settle(tester);
      expect(find.text('RESERVED'), findsOneWidget);
      expect(find.text('This item is reserved for you.'), findsOneWidget);
      products.value = products.value.copyWith(clearReservation: true);
      products.notifyListeners();
      await settle(tester);
      expect(find.text('RESERVED'), findsNothing);
      expect(find.text('This item is reserved for you.'), findsNothing);
    },
  );
}
