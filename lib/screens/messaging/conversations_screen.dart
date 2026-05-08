import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import 'chat_screen.dart';
import 'new_conversation_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getConversations();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) _conversations = result['conversations'] as List;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NewConversationScreen()),
          );
          if (created == true) _loadData();
        },
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Aucune conversation', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Envoyez un premier message', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final participants = conv['participants'] as List;
                      final latestMessage = conv['latest_message'];
                      final unread = conv['unread_count'] ?? 0;

                      final displayName = participants.isNotEmpty
                          ? participants.map((p) => p['full_name']).join(', ')
                          : 'Conversation';
                      final photo = participants.isNotEmpty ? participants.first['photo'] : null;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1A237E).withAlpha(25),
                          backgroundImage: photo != null
                              ? NetworkImage('${ApiConstants.baseUrl.replaceAll('/api', '')}/storage/$photo')
                              : null,
                          child: photo == null
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (latestMessage != null)
                              Text(
                                latestMessage['created_at'] ?? '',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                        subtitle: latestMessage != null
                            ? Text(
                                latestMessage['body'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: unread > 0 ? Colors.black87 : Colors.grey[600],
                                  fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                                ),
                              )
                            : null,
                        trailing: unread > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A237E),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$unread',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: conv['id'],
                                title: displayName,
                              ),
                            ),
                          );
                          _loadData();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
