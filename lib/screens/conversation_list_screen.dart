import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  _ConversationListScreenState createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  late Future<List<Map<String, dynamic>>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = Provider.of<MessageProvider>(
      context,
      listen: false,
    ).fetchConversations();
  }

  Future<void> _refresh() async {
    setState(() {
      _conversationsFuture = Provider.of<MessageProvider>(
        context,
        listen: false,
      ).fetchConversations();
    });
    await _conversationsFuture;
  }

  String _timeAgo(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString);
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF800000), // UM Maroon
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _conversationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              );
            }
            final conversations = snapshot.data ?? [];
            if (conversations.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  const Icon(
                    Icons.forum_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a conversation by tapping "Message Seller" on any product.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final convo = conversations[i];
                final product = convo['product'] as Map<String, dynamic>? ?? {};
                final productTitle = product['title'] ?? 'Product';
                final imageUrl =
                    (product['image_urls'] as List?)?.isNotEmpty == true
                    ? product['image_urls'][0]
                    : null;

                final currentUserId = Provider.of<MessageProvider>(
                  context,
                  listen: false,
                ).client.auth.currentUser?.id;
                final buyerEmail = convo['buyer']?['email'] ?? 'Unknown';
                final sellerEmail = convo['seller']?['email'] ?? 'Unknown';
                final isBuyer = convo['buyer_id'] == currentUserId;
                final otherEmail = isBuyer ? sellerEmail : buyerEmail;
                final roleLabel = isBuyer ? 'You are buyer' : 'You are seller';

                final lastMessage = convo['last_message'];
                final lastMessageContent = lastMessage != null
                    ? lastMessage['content'] ?? ''
                    : '';
                final unreadCount = convo['unread_count'] ?? 0;

                return InkWell(
                  onTap: () async {
                    await Provider.of<MessageProvider>(
                      context,
                      listen: false,
                    ).markConversationAsRead(convo['id'] as String);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(conversationId: convo['id'] as String),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 24,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFFD4AF37), // UM Gold
                                    child: const Icon(
                                      Icons.shopping_bag,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title, last message, role
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lastMessageContent.isEmpty
                                    ? productTitle
                                    : lastMessageContent,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unreadCount > 0
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                roleLabel,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Timestamp and unread badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _timeAgo(
                                convo['created_at'] as String? ??
                                    DateTime.now().toIso8601String(),
                              ),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF800000), // UM Maroon
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
