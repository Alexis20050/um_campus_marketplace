import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/message_provider.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Cache the stream so it isn't recreated on every rebuild —
  // recreating it causes Supabase Realtime to resubscribe and
  // re-emit the message history, producing a double-render flicker.
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  bool _sending = false;
  String _otherEmail = '';
  Product? _product;

  @override
  void initState() {
    super.initState();
    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );
    _messagesStream = messageProvider.messagesStream(widget.conversationId);

    _loadConversationData();
    Future.microtask(() {
      messageProvider.markConversationAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationData() async {
    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );
    final supabase = messageProvider.client;
    final currentUserId = supabase.auth.currentUser?.id;

    try {
      final convo = await supabase
          .from('conversations')
          .select('''
            buyer_id,
            seller_id,
            buyer:profiles!fk_conversations_buyer_profile(email),
            seller:profiles!fk_conversations_seller_profile(email),
            product:products(*)
          ''')
          .eq('id', widget.conversationId)
          .single();

      final buyerEmail = convo['buyer']?['email'] ?? 'Unknown';
      final sellerEmail = convo['seller']?['email'] ?? 'Unknown';
      final isBuyer = convo['buyer_id'] == currentUserId;
      final otherEmail = isBuyer ? sellerEmail : buyerEmail;

      Product? product;
      if (convo['product'] != null) {
        product = Product.fromMap(convo['product'] as Map<String, dynamic>);
      }

      if (mounted) {
        setState(() {
          _otherEmail = otherEmail;
          _product = product;
        });
      }
    } catch (e) {
      debugPrint('loadConversationData failed: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString);
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = Provider.of<MessageProvider>(context);
    final currentUserId = messageProvider.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(
          _otherEmail.isEmpty ? 'Chat' : _otherEmail,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ══════════════════════════════════════════════════
          // Product context card
          // ══════════════════════════════════════════════════
          if (_product != null)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: _product!),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowOf(context),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: _product!.imageUrls.isNotEmpty
                            ? Image.network(
                                _product!.imageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.surfaceAltOf(context),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: AppColors.textTertiaryOf(context),
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceAltOf(context),
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.textTertiaryOf(context),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _product!.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${_product!.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.brandOf(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Category: ${_product!.category}',
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiaryOf(context),
                    ),
                  ],
                ),
              ),
            ),

          // ══════════════════════════════════════════════════
          // Messages list
          // ══════════════════════════════════════════════════
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load messages.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Dedupe by message id — Supabase Realtime can
                // occasionally re-emit rows on reconnect.
                final raw = snapshot.data ?? [];
                final seen = <String>{};
                final messages = <Map<String, dynamic>>[];
                for (final m in raw) {
                  final id = m['id']?.toString() ?? '';
                  if (id.isNotEmpty && seen.add(id)) {
                    messages.add(m);
                  } else if (id.isEmpty) {
                    messages.add(m);
                  }
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 56,
                          color: AppColors.textTertiaryOf(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hello to start the conversation.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMe = msg['sender_id'] == currentUserId;
                    final timestamp = msg['created_at'] != null
                        ? _formatTime(msg['created_at'].toString())
                        : '';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.brandOf(context)
                              : AppColors.surfaceAltOf(context),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msg['content'],
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : AppColors.textPrimaryOf(context),
                                fontSize: 15,
                              ),
                            ),
                            if (timestamp.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                timestamp,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppColors.textTertiaryOf(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ══════════════════════════════════════════════════
          // Input row
          // ══════════════════════════════════════════════════
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 6,
                    color: AppColors.shadowOf(context),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.surfaceAltOf(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.brandOf(context),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: () async {
                              final content = _messageController.text.trim();
                              if (content.isEmpty || _sending) return;
                              setState(() => _sending = true);
                              try {
                                await messageProvider.sendMessage(
                                  conversationId: widget.conversationId,
                                  content: content,
                                );
                                _messageController.clear();
                                _scrollToBottom();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to send: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _sending = false);
                                }
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
