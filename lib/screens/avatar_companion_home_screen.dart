import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../widgets/avatar_view.dart';
import '../widgets/chat_panel.dart';
import 'add_reminder_screen.dart';
import 'find_doctors_screen.dart';
import 'mode_selection_screen.dart';
import 'my_reminders_screen.dart';
import 'select_avatar_screen.dart';
import 'user_profile_screen.dart';
import 'create_avatar_screen.dart';

import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tts_service.dart';
import 'voice_selection_screen.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class AvatarCompanionHomeScreen extends StatefulWidget {
  const AvatarCompanionHomeScreen({super.key});

  @override
  State<AvatarCompanionHomeScreen> createState() => _AvatarCompanionHomeScreenState();
}

class _AvatarCompanionHomeScreenState extends State<AvatarCompanionHomeScreen> {
  final _storage = const FlutterSecureStorage();
  final SpeechToText _speechToText = SpeechToText();
  final TTSService _ttsService = TTSService();
  
  String? _avatarUrl;
  String _lastResponse = "";
  String _currentAction = 'idle';
  String _currentEmotion = 'neutral';
  bool _isLoading = true;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isChatOpen = false;
  String _selectedMode = 'Mental Health';
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _fetchActiveAvatar();
    _initSpeech();
    _initTts();
  }

  Future<void> _fetchActiveAvatar() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      final response = await http.get(
        Uri.parse(ApiConstants.activeAvatarUrl),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _avatarUrl = data['url'];
            _isLoading = false;
          });
        }
      } else {
        debugPrint('Failed to fetch active avatar: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching avatar: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _initTts() async {
    await _ttsService.init();
  }

  Future<void> _handleMicPress() async {
    if (!_speechEnabled) {
      _initSpeech();
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            setState(() => _isListening = false);
            _sendMessage(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: false,
        localeId: SettingsService().locale.value.languageCode == 'en' ? 'en_US' : 
                 SettingsService().locale.value.languageCode == 'es' ? 'es_ES' :
                 SettingsService().locale.value.languageCode == 'fr' ? 'fr_FR' :
                 SettingsService().locale.value.languageCode == 'hi' ? 'hi_IN' :
                 SettingsService().locale.value.languageCode == 'de' ? 'de_DE' :
                 SettingsService().locale.value.languageCode == 'ta' ? 'ta_IN' : 'en_US',
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

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
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'];
        final action = data['action'];
        final emotion = data['emotion'];

        _onMessageReceived(reply, action, emotion);
        await _ttsService.speak(reply);
      }
    } catch (e) {
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _onMessageReceived(String reply, String action, String emotion) {
    setState(() {
      _lastResponse = reply;
      _currentAction = action;
      _currentEmotion = emotion;
    });

    // Reset to idle after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentAction = 'idle';
          _currentEmotion = 'neutral';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFFFD6E8),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          final l10n = AppLocalizations.of(context);
          if (_isFirstLoad || _lastResponse.isEmpty) {
            _lastResponse = l10n.translate('default_avatar_msg');
            _isFirstLoad = false;
          }
          return Stack(
            children: [
              // 1. Full-screen Avatar
              Positioned.fill(
                child: _avatarUrl != null
                    ? IgnorePointer(
                        child: AvatarView(
                          avatarUrl: _avatarUrl!,
                          action: _currentAction,
                          emotion: _currentEmotion,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 120,
                              color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              l10n.translate('no_avatar_selected'),
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.grey.withOpacity(0.5),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const CreateAvatarScreen()),
                                ).then((_) => _fetchActiveAvatar());
                              },
                              icon: const Icon(Icons.add),
                              label: Text(l10n.translate('create_avatar')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // 2. Floating Header Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.7) : const Color(0xFFEC4899),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Chat Mode Selector
                        Flexible(
                          child: PopupMenuButton<String>(
                            onSelected: (String mode) {
                              setState(() => _selectedMode = mode);
                            },
                            itemBuilder: (BuildContext context) {
                              return ['chat', 'funny', 'mental_health', 'study'].map((String modeKey) {
                                return PopupMenuItem<String>(
                                  value: modeKey == 'chat' ? 'Chat' : 
                                         modeKey == 'funny' ? 'Funny' :
                                         modeKey == 'mental_health' ? 'Mental Health' : 'Study',
                                  child: Text(
                                    l10n.translate(modeKey),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            offset: const Offset(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: isDark ? Colors.grey[900] : Colors.white,
                            elevation: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF9A76).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      l10n.translate(_selectedMode.toLowerCase().replaceAll(' ', '_')),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Right Side Buttons Row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Voice Selection Button
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const VoiceSelectionScreen()),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[900] : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.record_voice_over,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            
                            // Chat/History Button
                            GestureDetector(
                              onTap: () => setState(() => _isChatOpen = true),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.forum_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. AI Response Bubble
              if (_lastResponse.isNotEmpty && !_isChatOpen)
                Positioned(
                  bottom: 160,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      _lastResponse,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

              // 4. Primary Microphone Button
              if (!_isChatOpen)
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _handleMicPress,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 85,
                        height: 85,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isListening
                                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                : [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF8B5CF6))
                                  .withOpacity(0.5),
                              blurRadius: _isListening ? 35 : 25,
                              spreadRadius: _isListening ? 10 : 5,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Chat Panel Overlay
              if (_isChatOpen)
                Positioned.fill(
                  child: ChatPanel(
                    onClose: () => setState(() => _isChatOpen = false),
                    onMessageSent: _onMessageReceived,
                    initialMode: _selectedMode,
                    headerColor: const Color(0xFFEC4899),
                    backgroundColor: const Color(0xFFFFD6E8),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
