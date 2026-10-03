import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:um_campus_marketplace/providers/message_provider.dart';
import 'package:um_campus_marketplace/screens/chat_screen.dart';

class _FakeAuth implements GoTrueClient {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClient implements SupabaseClient {
  @override
  GoTrueClient get auth => _FakeAuth();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMessages extends MessageProvider {
  FakeMessages() : super(client: _FakeClient());
  late void Function(List<Map<String, dynamic>>) publish;
  late final Stream<List<Map<String, dynamic>>> messages = Stream.multi((
    controller,
  ) {
    publish = controller.addSync;
  });
  int reads = 0;
  bool fail = false;
  @override
  Stream<List<Map<String, dynamic>>> messagesStream(String id) => messages;
  @override
  Future<Map<String, dynamic>> fetchConversation(String id) async => {
    'buyer_id': 'buyer',
    'seller_id': 'seller',
    'buyer': {'name': 'Maria'},
  };
  @override
  Future<void> markConversationAsRead(String id) async {
    reads++;
    if (fail) throw StateError('Offline');
  }

  void emit(String id) => publish([
    {'id': id, 'sender_id': 'other', 'content': 'Hello'},
  ]);
}

void main() {
  testWidgets('clears messages on display and on foreground return', (
    tester,
  ) async {
    final provider = FakeMessages();
    await tester.pumpWidget(
      ChangeNotifierProvider<MessageProvider>.value(
        value: provider,
        child: const MaterialApp(home: ChatScreen(conversationId: 'a')),
      ),
    );
    await tester.pump();
    expect(
      provider.reads,
      0,
    ); // Loading a route alone is not reading a message.
    provider.emit('first');
    await tester.pumpAndSettle();
    expect(provider.reads, 1);
    provider.emit('second');
    await tester.pumpAndSettle();
    expect(provider.reads, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    provider.emit('third');
    await tester.pumpAndSettle();
    expect(provider.reads, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(provider.reads, 3);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('failed read update shows retry and can recover', (tester) async {
    final provider = FakeMessages()..fail = true;
    await tester.pumpWidget(
      ChangeNotifierProvider<MessageProvider>.value(
        value: provider,
        child: const MaterialApp(home: ChatScreen(conversationId: 'a')),
      ),
    );
    provider.emit('first');
    await tester.pumpAndSettle();
    expect(find.text('Could not update read status.'), findsOneWidget);
    provider.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not update read status.'), findsNothing);
    expect(provider.reads, 2);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
