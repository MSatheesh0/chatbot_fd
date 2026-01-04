import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import 'avatar_companion_home_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String _selectedMode = 'Funny';
  final List<String> _modes = ['Funny', 'Search', 'Mental Health', 'Study'];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.conversationsUrl}?mode=$_selectedMode'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _conversations = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load conversations');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching conversations: $e');
    }
  }

  Future<void> _deleteConversation(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConstants.conversationsUrl}/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        _fetchConversations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation deleted')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  Future<void> _downloadChat(String id, String title) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.messagesUrl}/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final messages = jsonDecode(response.body);
        String chatContent = "Chat History: $title\n\n";
        for (var msg in messages) {
          final sender = msg['sender'] == 'user' ? 'You' : 'AI';
          chatContent += "[$sender]: ${msg['message']}\n";
        }

        // In a real app, you'd save this to a file. For now, we'll show it in a dialog.
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Chat Downloaded (Preview)'),
              content: SingleChildScrollView(child: Text(chatContent)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error downloading chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  // Mode Selector
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _modes.length,
                      itemBuilder: (context, index) {
                        final mode = _modes[index];
                        final isSelected = _selectedMode == mode;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMode = mode;
                              _fetchConversations();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Center(
                              child: Text(
                                mode,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF6A11CB) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _conversations.isEmpty
                        ? const Center(
                            child: Text(
                              'No chat history found.',
                              style: TextStyle(color: Colors.white70, fontSize: 18),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final date = DateTime.parse(conv['updatedAt']);
                      final formattedDate = DateFormat('MMM d, yyyy • HH:mm').format(date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.chat_bubble_outline, color: Colors.white),
                          ),
                          title: Text(
                            conv['title'] ?? 'Untitled Chat',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          onTap: () {
                            // Navigate back to home and open this chat
                            // For now, we just go back to home
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const AvatarCompanionHomeScreen()),
                              (route) => false,
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download_outlined, color: Colors.blueAccent),
                                onPressed: () => _downloadChat(conv['_id'], conv['title'] ?? 'Chat'),
                                tooltip: 'Download',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _showDeleteConfirmation(conv['_id']),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConversation(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
