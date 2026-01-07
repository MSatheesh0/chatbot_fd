import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import 'avatar_companion_home_screen.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

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
        // Update list locally instead of reloading entire page
        setState(() {
          _conversations.removeWhere((conv) => conv['_id'] == id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('conversation_deleted'))),
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
        final l10n = AppLocalizations.of(context);
        String chatContent = "${l10n.translate('chat_history')}: $title\n\n";
        for (var msg in messages) {
          final sender = msg['sender'] == 'user' ? l10n.translate('you') : l10n.translate('ai');
          chatContent += "[$sender]: ${msg['message']}\n";
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : Colors.white,
              title: Text(
                l10n.translate('chat_downloaded_preview'),
                style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
              ),
              content: SingleChildScrollView(
                child: Text(
                  chatContent,
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.translate('close')),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: SettingsService().locale,
          builder: (context, locale, _) {
            return Text(AppLocalizations.of(context).translate('chat_history'));
          },
        ),
        backgroundColor: isDark ? Colors.black : const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          final l10n = AppLocalizations.of(context);
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : const Color(0xFFDCEEFF),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
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
                            
                            // Safe mode translation with fallback
                            String displayMode = mode;
                            try {
                              final modeKey = mode.toLowerCase().replaceAll(' ', '_');
                              displayMode = l10n.translate(modeKey);
                            } catch (e) {
                              debugPrint('Translation error for mode: $mode, using default');
                              displayMode = mode;
                            }
                            
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
                                    displayMode,
                                    style: TextStyle(
                                      color: isSelected ? (isDark ? Colors.black : const Color(0xFF3B82F6)) : Colors.black54,
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
                            ? Center(
                                child: Text(
                                  l10n.translate('no_chat_history'),
                                  style: const TextStyle(color: Colors.grey, fontSize: 18),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _conversations.length,
                                itemBuilder: (context, index) {
                                  try {
                                    // Safely check if index is valid
                                    if (index < 0 || index >= _conversations.length) {
                                      return const SizedBox.shrink();
                                    }
                                    
                                    final conv = _conversations[index];
                                    final date = DateTime.parse(conv['updatedAt']);
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFF3B82F6),
                                          child: Icon(Icons.chat_bubble_outline, color: Colors.white),
                                        ),
                                        title: Text(
                                          conv['title'] ?? l10n.translate('untitled_chat'),
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: ValueListenableBuilder(
                                          valueListenable: SettingsService().dateFormat,
                                          builder: (context, dateFormat, _) {
                                            return ValueListenableBuilder(
                                              valueListenable: SettingsService().timeZone,
                                              builder: (context, timeZone, _) {
                                                return Text(
                                                  '${SettingsService().formatDate(date)} • ${SettingsService().formatTime(date)}',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                        onTap: () {
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
                                              tooltip: l10n.translate('download_chat'),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                              onPressed: () => _showDeleteConfirmation(conv['_id']),
                                              tooltip: l10n.translate('delete'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint('Error rendering conversation at index $index: $e');
                                    // Return an error card instead of crashing
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.redAccent),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Error loading conversation',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String id) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.translate('delete_chat'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          l10n.translate('delete_chat_confirm'),
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConversation(id);
            },
            child: Text(
              l10n.translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
