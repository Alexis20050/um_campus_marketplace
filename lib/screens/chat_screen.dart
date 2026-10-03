import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/message_provider.dart';
import '../theme/app_theme.dart';
import '../utils/student_name.dart';

import 'product_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  late final MessageProvider _messageProvider;

  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  bool _sending = false;

  bool _markingRead = false;

  bool _readQueued = false;

  bool _foreground = true;

  String? _lastReadMessageId;

  String? _visibleMessageId;

  String? _readError;

  String? _conversationError;

  String _otherName = '';

  Product? _product;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    _messageProvider = Provider.of<MessageProvider>(context, listen: false);

    _messagesStream = _messageProvider.messagesStream(widget.conversationId);

    _loadConversationData();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _messageController.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;

    if (_foreground && mounted) {
      setState(() {
        _lastReadMessageId = null;
      });
    }
  }

  // ============================================================
  // LOAD CONVERSATION INFO
  // ============================================================

  Future<void> _loadConversationData() async {
    final currentUserId = _messageProvider.client.auth.currentUser?.id;

    try {
      final conversation = await _messageProvider.fetchConversation(
        widget.conversationId,
      );

      final isBuyer = conversation['buyer_id'] == currentUserId;

      final otherProfile = isBuyer
          ? conversation['seller']
          : conversation['buyer'];

      final otherName = studentName(otherProfile?['name']) ?? 'UM Student';

      Product? product;

      final rawProduct = conversation['product'];

      if (rawProduct is Map) {
        product = Product.fromMap(Map<String, dynamic>.from(rawProduct));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _otherName = otherName;

        _product = product;

        _conversationError = null;
      });
    } catch (e) {
      debugPrint('loadConversationData failed: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _conversationError = e.toString();
      });
    }
  }

  // ============================================================
  // MARK READ
  // ============================================================

  Future<void> _markVisibleMessagesRead() async {
    if (!mounted ||
        !_foreground ||
        ModalRoute.of(context)?.isCurrent != true ||
        _visibleMessageId == null) {
      return;
    }

    if (_markingRead) {
      _readQueued = true;

      return;
    }

    if (_visibleMessageId == _lastReadMessageId) {
      return;
    }

    _markingRead = true;

    try {
      do {
        _readQueued = false;

        final messageId = _visibleMessageId;

        await _messageProvider.markConversationAsRead(widget.conversationId);

        if (!mounted) {
          return;
        }

        _lastReadMessageId = messageId;

        if (_readError != null) {
          setState(() {
            _readError = null;
          });
        }
      } while (_readQueued &&
          mounted &&
          _foreground &&
          ModalRoute.of(context)?.isCurrent == true &&
          _visibleMessageId != _lastReadMessageId);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _readError = 'Could not update read status.';
      });
    } finally {
      _markingRead = false;
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString).toLocal();

    var hour = dateTime.hour;

    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }

  // ============================================================
  // SEND
  // ============================================================

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _messageProvider.sendMessage(
        conversationId: widget.conversationId,
        content: content,
      );

      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentUserId = _messageProvider.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),

      appBar: AppBar(
        title: Text(
          _otherName.isEmpty ? 'Chat' : _otherName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: AppColors.maroon,

        foregroundColor: Colors.white,
      ),

      body: Column(
        children: [
          // ====================================================
          // CONVERSATION LOAD ERROR
          // ====================================================
          if (_conversationError != null)
            MaterialBanner(
              content: Text(
                'Could not load conversation details.\n$_conversationError',
              ),
              actions: [
                TextButton(
                  onPressed: _loadConversationData,
                  child: const Text('Retry'),
                ),
              ],
            ),

          // ====================================================
          // PRODUCT HEADER
          // ====================================================
          if (_product != null)
            InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: _product!),
                  ),
                );

                if (!mounted) {
                  return;
                }

                setState(() {
                  _lastReadMessageId = null;
                });
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

          // ====================================================
          // READ ERROR
          // ====================================================
          if (_readError != null)
            MaterialBanner(
              content: Text(_readError!),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _readError = null;
                    });

                    _markVisibleMessagesRead();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),

          // ====================================================
          // MESSAGES
          // ====================================================
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

                final messages = MessageProvider.dedupe(snapshot.data ?? []);

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

                final latestMessageId = messages.last['id']?.toString();

                final changed = latestMessageId != _visibleMessageId;

                _visibleMessageId = latestMessageId;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted ||
                      !_foreground ||
                      ModalRoute.of(context)?.isCurrent != true) {
                    return;
                  }

                  if (changed) {
                    _scrollToBottom();
                  }

                  if (_readError == null) {
                    _markVisibleMessagesRead();
                  }
                });

                return ListView.builder(
                  controller: _scrollController,

                  padding: const EdgeInsets.all(12),

                  itemCount: messages.length,

                  itemBuilder: (context, index) {
                    final message = messages[index];

                    final isMe = message['sender_id'] == currentUserId;

                    final timestamp = message['created_at'] != null
                        ? _formatTime(message['created_at'].toString())
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
                              message['content']?.toString() ?? '',
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

          // ====================================================
          // MESSAGE INPUT
          // ====================================================
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8),

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

                      onSubmitted: (_) {
                        if (!_sending) {
                          _sendMessage();
                        }
                      },

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
                            tooltip: 'Send message',
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
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
