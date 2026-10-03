import 'dart:async';

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

enum MessageStatus { sending, sent, failed }

class MessageProvider extends ChangeNotifier {
  final SupabaseClient _supabase;

  MessageProvider({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  SupabaseClient get client => _supabase;

  Future<void> ensureMessagingAllowed(String otherUserId) async {
    final blocked = await _supabase.rpc(
      'messaging_is_blocked',
      params: {'p_user_id': otherUserId},
    );
    if (blocked != false) {
      throw StateError(
        'Messaging is unavailable because a user has blocked the other.',
      );
    }
  }

  // ============================================================

  // STATE

  // ============================================================

  final Map<String, MessageStatus> _outgoingStatus = {};

  final Map<String, int> _unreadByConversation = {};

  int _unreadTotal = 0;

  int get unreadTotal => _unreadTotal;

  StreamSubscription<List<Map<String, dynamic>>>? _unreadSub;

  Timer? _unreadDebounce;

  bool _listening = false;

  bool _disposed = false;

  String? _unreadUserId;

  int _unreadGeneration = 0;

  // ============================================================

  // OUTGOING STATUS

  // ============================================================

  MessageStatus? statusOf(String messageId) {
    return _outgoingStatus[messageId];
  }

  // ============================================================

  // UNREAD COUNT PER CONVERSATION

  // ============================================================

  int unreadFor(String conversationId) {
    return _unreadByConversation[conversationId] ?? 0;
  }

  // ============================================================

  // UNREAD LISTENER

  // ============================================================

  void startUnreadListener({bool restart = false}) {
    final userId = _supabase.auth.currentUser?.id;

    if (_disposed) {
      return;
    }

    if (_listening && !restart && _unreadUserId == userId) {
      return;
    }

    final generation = ++_unreadGeneration;

    _unreadSub?.cancel();

    _unreadSub = null;

    _unreadDebounce?.cancel();

    _unreadDebounce = null;

    _listening = false;

    if (_unreadUserId != userId) {
      _unreadByConversation.clear();

      _unreadTotal = 0;
    }

    _unreadUserId = userId;

    if (userId == null) {
      _unreadByConversation.clear();

      _unreadTotal = 0;

      notifyListeners();

      return;
    }

    _listening = true;

    _unreadSub = _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .listen(
          (rows) {
            if (_disposed ||
                generation != _unreadGeneration ||
                _supabase.auth.currentUser?.id != userId) {
              return;
            }

            final nextUnread = <String, int>{};

            var total = 0;

            for (final row in rows) {
              final conversationId = row['id']?.toString();

              if (conversationId == null || conversationId.isEmpty) {
                continue;
              }

              final isBuyer = row['buyer_id'] == userId;

              final isSeller = row['seller_id'] == userId;

              if (!isBuyer && !isSeller) {
                continue;
              }

              final count = isBuyer
                  ? (row['buyer_unread'] as num?)?.toInt() ?? 0
                  : (row['seller_unread'] as num?)?.toInt() ?? 0;

              nextUnread[conversationId] = count;

              total += count;
            }

            _unreadDebounce?.cancel();

            _unreadDebounce = Timer(const Duration(milliseconds: 200), () {
              if (_disposed ||
                  generation != _unreadGeneration ||
                  _supabase.auth.currentUser?.id != userId) {
                return;
              }

              _unreadByConversation
                ..clear()
                ..addAll(nextUnread);

              _unreadTotal = total;

              notifyListeners();
            });
          },

          onError: (Object error) {
            if (_disposed || generation != _unreadGeneration) {
              return;
            }

            _listening = false;

            debugPrint('Unread listener error: $error');
          },
        );
  }

  void stopUnreadListener() {
    ++_unreadGeneration;

    _unreadSub?.cancel();

    _unreadSub = null;

    _unreadDebounce?.cancel();

    _unreadDebounce = null;

    _listening = false;

    _unreadUserId = null;

    _unreadByConversation.clear();

    _unreadTotal = 0;
  }

  // ============================================================

  // GET / CREATE CONVERSATION

  // ============================================================

  Future<String> getOrCreateConversation({
    required String productId,

    required String sellerId,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;

    if (currentUserId == null) {
      throw StateError('You must be logged in.');
    }

    if (currentUserId == sellerId) {
      throw StateError('You cannot message yourself about your own listing.');
    }

    await ensureMessagingAllowed(sellerId);

    final existing = await _supabase
        .from('conversations')
        .select('id')
        .eq('product_id', productId)
        .eq('buyer_id', currentUserId)
        .eq('seller_id', sellerId)
        .maybeSingle();

    if (existing != null) {
      return existing['id'].toString();
    }

    final response = await _supabase
        .from('conversations')
        .insert({
          'product_id': productId,

          'buyer_id': currentUserId,

          'seller_id': sellerId,
        })
        .select('id')
        .single();

    return response['id'].toString();
  }

  // ============================================================

  // FETCH SINGLE CONVERSATION

  //

  // IMPORTANT:

  // products!product_id explicitly tells PostgREST to use:

  //

  // conversations.product_id -> products.id

  //

  // This is necessary because reservation support created another

  // conversations/products relationship.

  // ============================================================

  Future<Map<String, dynamic>> fetchConversation(String conversationId) async {
    final response = await _supabase
        .from('conversations')
        .select('''

          buyer_id,

          seller_id,

          buyer:profiles!fk_conversations_buyer_profile(

            id,

            name,

            email

          ),

          seller:profiles!fk_conversations_seller_profile(

            id,

            name,

            email

          ),

          product:products!product_id(*)

        ''')
        .eq('id', conversationId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  // ============================================================

  // FETCH CONVERSATION LIST

  //

  // The same products!product_id relationship fix is applied here.

  // ============================================================

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      return [];
    }

    final response = await _supabase
        .from('conversations')
        .select('''

          *,

          product:products!product_id(

            title,

            image_urls

          ),

          buyer:profiles!fk_conversations_buyer_profile(

            id,

            email,

            name

          ),

          seller:profiles!fk_conversations_seller_profile(

            id,

            email,

            name

          ),

          messages:messages(

            id,

            content,

            created_at,

            sender_id

          )

        ''')
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .order('created_at', referencedTable: 'messages', ascending: false)
        .limit(1, referencedTable: 'messages');

    final conversations = List<Map<String, dynamic>>.from(response);

    for (final conversation in conversations) {
      final messages = conversation['messages'] as List? ?? [];

      if (messages.isNotEmpty) {
        messages.sort((a, b) {
          final aTime = a['created_at']?.toString() ?? '';

          final bTime = b['created_at']?.toString() ?? '';

          return bTime.compareTo(aTime);
        });

        conversation['last_message'] = Map<String, dynamic>.from(
          messages.first as Map,
        );
      } else {
        conversation['last_message'] = null;
      }

      conversation.remove('messages');
    }

    // Keep only actual conversations with at least one message.

    conversations.removeWhere(
      (conversation) => conversation['last_message'] == null,
    );

    // Sort newest message first.

    conversations.sort((a, b) {
      final aTime = a['last_message']?['created_at']?.toString() ?? '';

      final bTime = b['last_message']?['created_at']?.toString() ?? '';

      return bTime.compareTo(aTime);
    });

    _recomputeUnreadFrom(conversations, userId);

    return conversations;
  }

  // ============================================================

  // RECOMPUTE UNREAD

  // ============================================================

  void _recomputeUnreadFrom(
    List<Map<String, dynamic>> conversations,

    String userId,
  ) {
    final nextUnread = <String, int>{};

    var total = 0;

    for (final conversation in conversations) {
      final id = conversation['id']?.toString();

      if (id == null || id.isEmpty) {
        continue;
      }

      final isBuyer = conversation['buyer_id'] == userId;

      final isSeller = conversation['seller_id'] == userId;

      if (!isBuyer && !isSeller) {
        continue;
      }

      final unread = isBuyer
          ? (conversation['buyer_unread'] as num?)?.toInt() ?? 0
          : (conversation['seller_unread'] as num?)?.toInt() ?? 0;

      nextUnread[id] = unread;

      total += unread;
    }

    _unreadByConversation
      ..clear()
      ..addAll(nextUnread);

    if (_unreadTotal != total) {
      _unreadTotal = total;

      notifyListeners();
    }
  }

  // ============================================================

  // MARK CONVERSATION READ

  // ============================================================

  Future<void> markConversationAsRead(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null || _disposed) {
      return;
    }

    final conversation = await _supabase
        .from('conversations')
        .select('''

          buyer_id,

          seller_id,

          buyer_unread,

          seller_unread

          ''')
        .eq('id', conversationId)
        .maybeSingle();

    if (conversation == null) {
      throw StateError('Conversation is unavailable.');
    }

    String? field;

    if (conversation['buyer_id'] == userId) {
      field = 'buyer_unread';
    } else if (conversation['seller_id'] == userId) {
      field = 'seller_unread';
    }

    if (field == null) {
      throw StateError('You are not part of this conversation.');
    }

    final currentUnread = (conversation[field] as num?)?.toInt() ?? 0;

    if (currentUnread <= 0) {
      _unreadByConversation[conversationId] = 0;

      return;
    }

    await _supabase
        .from('conversations')
        .update({field: 0})
        .eq('id', conversationId);

    if (_disposed || _supabase.auth.currentUser?.id != userId) {
      return;
    }

    _unreadByConversation[conversationId] = 0;

    _unreadTotal = max(0, _unreadTotal - currentUnread);

    notifyListeners();

    // Restart so a stale realtime snapshot cannot restore the old badge.

    startUnreadListener(restart: true);
  }

  // ============================================================

  // MARK ALL READ

  // ============================================================

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    try {
      await _supabase
          .from('conversations')
          .update({'buyer_unread': 0})
          .eq('buyer_id', userId);

      await _supabase
          .from('conversations')
          .update({'seller_unread': 0})
          .eq('seller_id', userId);

      if (_disposed || _supabase.auth.currentUser?.id != userId) {
        return;
      }

      _unreadByConversation.clear();

      _unreadTotal = 0;

      notifyListeners();

      startUnreadListener(restart: true);
    } catch (e) {
      debugPrint('markAllAsRead failed: $e');

      rethrow;
    }
  }

  // ============================================================

  // MESSAGE STREAM

  // ============================================================

  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  // ============================================================

  // SEND MESSAGE

  // ============================================================

  Future<void> sendMessage({
    required String conversationId,

    required String content,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('You must be logged in.');
    }

    final cleanedContent = content.trim();

    if (cleanedContent.isEmpty) {
      return;
    }

    final clientId = _generateUuid();

    _outgoingStatus[clientId] = MessageStatus.sending;

    notifyListeners();

    try {
      final conversation = await _supabase
          .from('conversations')
          .select('buyer_id,seller_id')
          .eq('id', conversationId)
          .single();
      if (conversation['buyer_id'] != userId &&
          conversation['seller_id'] != userId) {
        throw StateError('You are not part of this conversation.');
      }
      await ensureMessagingAllowed(
        (conversation['buyer_id'] == userId
                ? conversation['seller_id']
                : conversation['buyer_id'])
            .toString(),
      );
      await _supabase.from('messages').insert({
        'id': clientId,

        'conversation_id': conversationId,

        'sender_id': userId,

        'content': cleanedContent,
      });

      _outgoingStatus[clientId] = MessageStatus.sent;
    } catch (e) {
      _outgoingStatus[clientId] = MessageStatus.failed;

      rethrow;
    } finally {
      notifyListeners();
    }
  }

  // ============================================================

  // DELETE MESSAGE

  // ============================================================

  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').delete().eq('id', messageId);

    _outgoingStatus.remove(messageId);

    notifyListeners();
  }

  // ============================================================

  // DEDUPE

  // ============================================================

  static List<Map<String, dynamic>> dedupe(
    List<Map<String, dynamic>> messages,
  ) {
    final seen = <String>{};

    final output = <Map<String, dynamic>>[];

    for (final message in messages) {
      final id = message['id']?.toString() ?? '';

      if (id.isEmpty) {
        output.add(message);

        continue;
      }

      if (seen.add(id)) {
        output.add(message);
      }
    }

    return output;
  }

  // ============================================================

  // UUID

  // ============================================================

  String _generateUuid() {
    final random = Random.secure();

    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;

    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  // ============================================================

  // DISPOSE

  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    stopUnreadListener();

    super.dispose();
  }
}
