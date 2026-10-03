import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:um_campus_marketplace/providers/message_provider.dart';

class _Auth implements GoTrueClient {
  @override
  User get currentUser => User(
    id: 'buyer',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-09-30',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements SupabaseClient {
  final SupabaseClient delegate;
  _Client(this.delegate);
  @override
  GoTrueClient get auth => _Auth();
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
  late SupabaseClient client;
  late MessageProvider provider;
  late List<String> requests;
  dynamic blocked;

  setUp(() async {
    blocked = true;
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      requests.add('${request.method} $path');
      request.response.headers.contentType = ContentType.json;
      if (path.endsWith('/rpc/messaging_is_blocked')) {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['p_user_id'], 'seller');
        request.response.write(jsonEncode(blocked));
      } else if (path.endsWith('/conversations')) {
        request.response.write(
          jsonEncode({
            'id': 'conversation',
            'buyer_id': 'buyer',
            'seller_id': 'seller',
          }),
        );
      } else {
        request.response.write('null');
      }
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    provider = MessageProvider(client: _Client(client));
  });

  tearDown(() async {
    provider.dispose();
    await client.dispose();
    await server.close(force: true);
  });

  test('blocked pair cannot get or create a conversation', () async {
    await expectLater(
      provider.getOrCreateConversation(
        productId: 'product',
        sellerId: 'seller',
      ),
      throwsStateError,
    );
    expect(requests, ['POST /rest/v1/rpc/messaging_is_blocked']);
  });

  test('blocked pair cannot send in an existing conversation', () async {
    await expectLater(
      provider.sendMessage(conversationId: 'conversation', content: 'Hello'),
      throwsStateError,
    );
    expect(requests, [
      'GET /rest/v1/conversations',
      'POST /rest/v1/rpc/messaging_is_blocked',
    ]);
  });

  test('unblock allows sending again without recreating history', () async {
    blocked = false;
    await provider.sendMessage(
      conversationId: 'conversation',
      content: 'Hello',
    );
    expect(requests.last, 'POST /rest/v1/messages');
  });

  test('unexpected block response fails closed', () async {
    blocked = null;
    await expectLater(
      provider.getOrCreateConversation(
        productId: 'product',
        sellerId: 'seller',
      ),
      throwsStateError,
    );
    expect(requests, hasLength(1));
  });
}
