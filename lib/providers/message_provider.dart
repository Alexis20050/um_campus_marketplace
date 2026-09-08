import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseClient get client => _supabase;

  // Get or create a conversation
  Future<String> getOrCreateConversation({
    required String productId,
    required String sellerId,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw 'You must be logged in.';

    final existing = await _supabase
        .from('conversations')
        .select('id')
        .eq('product_id', productId)
        .eq('buyer_id', currentUserId)
        .eq('seller_id', sellerId)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    final response = await _supabase
        .from('conversations')
        .insert({
          'product_id': productId,
          'buyer_id': currentUserId,
          'seller_id': sellerId,
          'unread_count': 0,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  // Fetch all conversations for the current user that have at least one message
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('conversations')
        .select('''
          *,
          product:products(title, image_urls),
          buyer:profiles!fk_conversations_buyer_profile(email),
          seller:profiles!fk_conversations_seller_profile(email),
          messages:messages(content, created_at, sender_id)
        ''')
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .order('created_at', ascending: false);

    final conversations = List<Map<String, dynamic>>.from(response);

    for (var convo in conversations) {
      final messages = convo['messages'] as List? ?? [];
      if (messages.isNotEmpty) {
        messages.sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
        convo['last_message'] = messages.first;
      } else {
        convo['last_message'] = null;
      }
      convo.remove('messages');
    }

    // 🔥 NEW: Keep only conversations that actually have messages
    conversations.removeWhere((convo) => convo['last_message'] == null);

    return conversations;
  }

  // Mark a conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase
        .from('conversations')
        .update({'unread_count': 0})
        .eq('id', conversationId)
        .or('buyer_id.eq.$userId,seller_id.eq.$userId');
  }

  // Stream messages
  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'You must be logged in.';
    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
    });
    notifyListeners();
  }
}
