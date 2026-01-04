import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tts_service.dart';
import '../screens/voice_selection_screen.dart';
import '../screens/analysis_screen.dart';

// Conditional import for web-specific functionality
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_mobile.dart';

class ChatPanel extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String, String, String) onMessageSent;
  final String? initialMode;

  const ChatPanel({
    super.key,
    required this.onClose,
    required this.onMessageSent,
    this.initialMode,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _storage = const FlutterSecureStorage();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final TTSService _ttsService = TTSService();
  
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  String? _selectedConversationId;
  late String _selectedMode;
  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  bool _isHistoryView = false;
  
  // Speech to text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  // Voice Reply
  bool _isVoiceReplyEnabled = false;

  static const List<String> _modes = ['Funny', 'Search', 'Mental Health', 'Study'];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode ?? 'Mental Health';
    _fetchConversations();
    _initSpeech();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await _ttsService.init();
    setState(() {
      _isVoiceReplyEnabled = _ttsService.ttsEnabledForChatbot;
    });
  }

  Future<void> _toggleVoiceReply() async {
    setState(() => _isVoiceReplyEnabled = !_isVoiceReplyEnabled);
    await _ttsService.updateSettings(ttsEnabledForChatbot: _isVoiceReplyEnabled);
  }

  void _initSpeech() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('Microphone permission denied');
          setState(() => _speechEnabled = false);
          return;
        }
      }

      var hasSpeech = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          if (mounted) setState(() => _isListening = false);
        },
      );
      
      if (!hasSpeech) {
        debugPrint('Speech recognition not available');
      }
      
      if (mounted) {
        setState(() {
          _speechEnabled = hasSpeech;
        });
      }
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
      if (mounted) {
        setState(() {
          _speechEnabled = false;
        });
      }
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _initSpeech();
      return;
    }
    
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          _messageController.text = _lastWords;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      localeId: 'en_US',
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _fetchConversations({bool autoSelect = true}) async {
    setState(() => _isLoadingConversations = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.conversationsUrl}?mode=$_selectedMode'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _conversations = jsonDecode(response.body);
          _isLoadingConversations = false;
          // If we have conversations and none selected, select the first one
          if (autoSelect && _conversations.isNotEmpty && _selectedConversationId == null) {
            _selectConversation(_conversations[0]['_id']);
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      setState(() => _isLoadingConversations = false);
    }
  }

  Future<void> _selectConversation(String id) async {
    setState(() {
      _selectedConversationId = id;
      _isLoadingMessages = true;
      _messages = [];
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.messagesUrl}/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages = jsonDecode(response.body);
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messageController.clear();
      _messages.add({
        'sender': 'user',
        'message': text,
        'type': 'text',
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse(ApiConstants.chatMessageUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? '',
        },
        body: jsonEncode({
          'message': text,
          'mode': _selectedMode,
          'conversationId': _selectedConversationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add({
            'sender': 'ai',
            'message': data['reply'],
            'type': 'text',
            'createdAt': DateTime.now().toIso8601String(),
          });
          _isSending = false;
        });
        _scrollToBottom();
        
        widget.onMessageSent(data['reply'], data['action'], data['emotion']);

        if (_isVoiceReplyEnabled) {
          await _ttsService.speak(data['reply']);
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      setState(() => _isSending = false);
    }
  }

  Future<void> _createNewChat() async {
    setState(() {
      _selectedConversationId = null;
      _messages = [];
      _isHistoryView = false;
    });
  }

  void _downloadChat() {
    if (_messages.isEmpty) return;

    String chatContent = "Chat History - Mode: $_selectedMode\n";
    chatContent += "==========================================\n\n";

    for (var msg in _messages) {
      String sender = msg['sender'] == 'user' ? "User" : "AI";
      chatContent += "[$sender]: ${msg['message']}\n\n";
    }

    final filename = "chat_history_${DateTime.now().millisecondsSinceEpoch}.txt";
    downloadTextFile(chatContent, filename);
  }

  Future<void> _clearConversation() async {
    if (_selectedConversationId == null) return;

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConstants.conversationsUrl}/$_selectedConversationId'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _conversations.removeWhere((c) => c['_id'] == _selectedConversationId);
          _selectedConversationId = null;
          _messages = [];
        });
        if (_conversations.isNotEmpty) {
          _selectConversation(_conversations[0]['_id']);
        }
      }
    } catch (e) {
      debugPrint('Error clearing conversation: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildHistoryView() {
    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    if (_conversations.isEmpty) {
      return const Center(
        child: Text(
          'No history for this mode',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final isSelected = conv['_id'] == _selectedConversationId;

        return GestureDetector(
          onTap: () {
            setState(() {
              _isHistoryView = false;
              _selectConversation(conv['_id']);
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                width: isSelected ? 2 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBFDBFE).withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv['title'] ?? 'Untitled Chat',
                        style: const TextStyle(
                          color: Color(0xFF1F2937), // Dark text
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conv['updatedAt'] != null 
                            ? DateTime.parse(conv['updatedAt']).toLocal().toString().split('.')[0]
                            : '',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12), // Grey text
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    _deleteConversation(conv['_id']);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareChat() async {
    if (_messages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No messages to share')),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Chat As',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBFDBFE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.text_snippet_outlined, color: Color(0xFF2563EB)),
              ),
              title: const Text(
                'Text Format', 
                style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _shareAsText();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1), 
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
              ),
              title: const Text(
                'PDF Format', 
                style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _shareAsPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareAsText() {
    String chatContent = _messages.map((m) {
      String sender = m['sender'] == 'user' ? 'You' : 'AI';
      return "$sender: ${m['message']}";
    }).join('\n\n');
    
    Share.share(chatContent, subject: 'My AI Chat Conversation');
  }

  Future<void> _shareAsPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text("AI Chat Conversation")),
          ..._messages.map((m) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    m['sender'] == 'user' ? 'You:' : 'AI:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(m['message']),
                  pw.Divider(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'ai_chat_conversation.pdf');
  }

  Future<void> _deleteConversation(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConstants.conversationsUrl}/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _conversations.removeWhere((c) => c['_id'] == id);
          if (_selectedConversationId == id) {
            _selectedConversationId = null;
            _messages = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }


  void _showModeSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Chat Mode',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ..._modes.map((mode) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedMode == mode 
                      ? const Color(0xFF2563EB) // Royal Blue for selected
                      : const Color(0xFFBFDBFE), // Light Blue for others
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: _selectedMode == mode ? Colors.white : const Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              title: Text(
                mode,
                style: TextStyle(
                  color: const Color(0xFF1F2937),
                  fontWeight: _selectedMode == mode ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: _selectedMode == mode 
                  ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                  : null,
              onTap: () {
                setState(() {
                  _selectedMode = mode;
                  _selectedConversationId = null;
                  _messages = [];
                  _isHistoryView = false; // Force exit history view
                  _fetchConversations(autoSelect: false);
                });
                Navigator.pop(context);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFDCEEFF), // Light Sky Blue background
      ),
      child: Stack(
        children: [
          // Star particles effect (Darker for light bg)
          Positioned.fill(
            child: CustomPaint(
              painter: StarPainter(),
            ),
          ),
          Column(
            children: [
              // Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      // AI Avatar
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1),
                        ),
                        child: const CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Felix'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Title & Mode
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'AI Chat',
                              style: TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _selectedMode,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Voice Toggle
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: Icon(
                              _isVoiceReplyEnabled ? Icons.volume_up : Icons.volume_off,
                              color: _isVoiceReplyEnabled ? const Color(0xFF2563EB) : Colors.grey,
                              size: 20,
                            ),
                            onPressed: _toggleVoiceReply,
                            tooltip: 'Voice Reply',
                          ),
                          // Voice Selection (Only if enabled)
                          if (_isVoiceReplyEnabled)
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: const Icon(Icons.record_voice_over, color: Color(0xFF2563EB), size: 20),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const VoiceSelectionScreen()),
                              ),
                              tooltip: 'Select Voice',
                            ),
                          // New Chat
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB), size: 20),
                            onPressed: _createNewChat,
                            tooltip: 'New Chat',
                          ),
                          // History
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: Icon(
                              _isHistoryView ? Icons.chat_outlined : Icons.history,
                              color: const Color(0xFF2563EB),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isHistoryView = !_isHistoryView;
                                if (_isHistoryView) {
                                  _fetchConversations(autoSelect: false);
                                }
                              });
                            },
                            tooltip: _isHistoryView ? 'Back to Chat' : 'Chat History',
                          ),
                          // More Menu (Download & Share)
                          PopupMenuButton<String>(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.more_vert, color: Color(0xFF2563EB), size: 20),
                            onSelected: (value) {
                              if (value == 'download') _downloadChat();
                              if (value == 'share') _shareChat();
                              if (value == 'analysis') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const AnalysisScreen()),
                                );
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'analysis',
                                child: ListTile(
                                  leading: Icon(Icons.analytics_outlined, color: Color(0xFF2563EB)),
                                  title: Text('View Analysis'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'download',
                                child: ListTile(
                                  leading: Icon(Icons.download_outlined, color: Color(0xFF2563EB)),
                                  title: Text('Download Chat'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'share',
                                child: ListTile(
                                  leading: Icon(Icons.share_outlined, color: Color(0xFF2563EB)),
                                  title: Text('Share Chat'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      // Close Button
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(Icons.close, color: Color(0xFF2563EB), size: 20),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                ),
              ),

              // Messages Area or History View
              Expanded(
                child: _isHistoryView
                    ? _buildHistoryView()
                    : _isLoadingMessages
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isAi = msg['sender'] != 'user' && msg['sender'] != null;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isAi) ...[
                                      const CircleAvatar(
                                        radius: 18,
                                        backgroundImage: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Felix'),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: isAi 
                                              ? Colors.white // White for AI
                                              : const Color(0xFF2563EB), // Royal Blue for User
                                          borderRadius: BorderRadius.circular(22).copyWith(
                                            topLeft: isAi ? const Radius.circular(4) : const Radius.circular(22),
                                            topRight: !isAi ? const Radius.circular(4) : const Radius.circular(22),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 5,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                        child: Text(
                                          msg['message'],
                                          style: TextStyle(
                                            color: isAi ? const Color(0xFF1F2937) : Colors.white,
                                            fontSize: 16,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!isAi) const SizedBox(width: 10),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              // Input Area
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8), // Semi-transparent white
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Settings Icon (Now opens Mode Selection)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFBFDBFE), // Light Blue circle
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Color(0xFF2563EB)),
                        onPressed: _showModeSelection,
                        tooltip: 'Select Mode',
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Input Field
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFDBFE).withOpacity(0.5), // Light Blue Pill
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Color(0xFF1F2937)),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Color(0xFF6B7280)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Mic Button
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.redAccent.withOpacity(0.2) : const Color(0xFFBFDBFE),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.redAccent : const Color(0xFF2563EB),
                        ),
                        onPressed: _isListening ? _stopListening : _startListening,
                        tooltip: _isListening ? 'Stop Listening' : 'Start Listening',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send Button
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2563EB), // Royal Blue
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark grey stars for light background
    final paint = Paint()..color = const Color(0xFF64748B).withOpacity(0.4);
    
    final stars = [
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.1),
      Offset(size.width * 0.7, size.height * 0.15),
      Offset(size.width * 0.9, size.height * 0.3),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.8, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.8),
      Offset(size.width * 0.6, size.height * 0.9),
      Offset(size.width * 0.15, size.height * 0.75),
      Offset(size.width * 0.85, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.4),
    ];
    for (var star in stars) {
      canvas.drawCircle(star, 1.5, paint); // Slightly larger stars
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
