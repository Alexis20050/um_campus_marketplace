import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:um_campus_marketplace/providers/rating_provider.dart';
import 'package:um_campus_marketplace/widgets/seller_rating_section.dart';

// Each subscription returns a snapshot, with no realtime events afterward.
class _SnapshotRatingProvider extends RatingProvider {
  _SnapshotRatingProvider({required super.client});

  List<Map<String, dynamic>> rows = [];

  @override
  Stream<List<Map<String, dynamic>>> sellerRatingsStream(String sellerId) {
    return Stream.value(List.of(rows));
  }
}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late _SnapshotRatingProvider provider;
  late bool rejectSubmission;
  HttpOverrides? previousHttpOverrides;

  setUp(() async {
    // Allow the local test server instead of Flutter's default HTTP 400 stub.
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    rejectSubmission = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    provider = _SnapshotRatingProvider(client: client);
    server.listen((request) async {
      expect(request.uri.path, '/rest/v1/rpc/submit_seller_rating');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.headers.contentType = ContentType.json;
      if (rejectSubmission) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({'message': 'Rating rejected'}));
      } else {
        provider.rows = [
          {'rating': body['p_rating'], 'review': body['p_review']},
        ];
        request.response.write(jsonEncode('rating-id'));
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    provider.dispose();
    await client.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousHttpOverrides;
  });

  testWidgets('profile refreshes after submitting without realtime', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<RatingProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: SellerRatingSection(sellerId: 'seller')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No seller ratings yet'), findsOneWidget);

    await tester.runAsync(() async {
      await provider.submitSellerRating(
        transactionId: 'transaction',
        rating: 5,
        review: 'Helpful seller',
      );
    });
    await tester.pumpAndSettle();

    expect(provider.ratingsRevision, 1);
    expect(find.text('No seller ratings yet'), findsNothing);
    expect(find.text('5.0'), findsOneWidget);
    expect(find.text('1 rating'), findsOneWidget);
    expect(find.text('Helpful seller'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('failed submissions do not advance the ratings revision', () async {
    rejectSubmission = true;
    await expectLater(
      provider.submitSellerRating(transactionId: 'transaction', rating: 4),
      throwsA(isA<PostgrestException>()),
    );
    expect(provider.ratingsRevision, 0);
    expect(provider.isLoading, isFalse);
  });
}
