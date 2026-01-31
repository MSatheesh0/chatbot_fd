import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
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
  double _currentSpeed = 1.0;
  String _currentEyeState = 'normal';
  bool _isLoading = true;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isChatOpen = false;
  String _selectedMode = 'Mental Health';
  bool _isFirstLoad = true;
  bool _isTalking = false;
  Timer? _actionTimer;
  bool _showDoctorSuggestion = false;
  Map<String, dynamic>? _lastSafetyAlert;

  @override
  void initState() {
    super.initState();
    _fetchActiveAvatar();
    _initSpeech();
    _initTts();
    _setupTtsListener();
  }

  void _setupTtsListener() {
    _ttsService.isSpeakingNotifier.addListener(() {
      if (mounted) {
        setState(() {
          _isTalking = _ttsService.isSpeaking;
          
          if (_isTalking) {
            // Only override with 'talk' if we are currently idle or already talking
            if (_currentAction == 'idle' || _currentAction == 'talking') {
              _currentAction = 'talk';
            }
          } else {
            // Reset to idle when speaking finishes
            _currentAction = 'idle';
            _currentEmotion = 'neutral';
          }
        });
      }
    });
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
            // Trigger initial greeting animation
            _currentAction = 'wave';
            _currentEmotion = 'happy';
          });
          
          // Revert to idle after greeting
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _currentAction = 'idle';
                _currentEmotion = 'neutral';
              });
            }
          });
        }
      } else {
        debugPrint('Failed to fetch active avatar: ${response.statusCode}');
        if (mounted) {
          setState(() {
            // Fallback for debugging animations
            _avatarUrl = "https://models.readyplayer.me/638df693d72bffc6fa17d4f2.glb"; 
            _isLoading = false;
            _currentAction = 'wave';
            _currentEmotion = 'happy';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching avatar: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initSpeech() async {
    try {
      if (!kIsWeb) {
        var status = await Permission.microphone.status;
        if (!status.isGranted) {
          status = await Permission.microphone.request();
          if (!status.isGranted) {
            debugPrint('Microphone permission denied');
            setState(() => _speechEnabled = false);
            return;
          }
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
          debugPrint('Speech error: ${error.errorMsg} - ${error.permanent}');
          if (mounted) {
            setState(() {
              _isListening = false;
              _lastResponse = "Mic Error: ${error.errorMsg}";
            });
          }
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
          _lastResponse = "Mic Init Failed: $e";
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

    // Prevent rapid clicks
    if (_speechToText.isAvailable && (_isListening || _speechToText.isListening)) {
      await _speechToText.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    // Small delay to ensure previous session is fully closed
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      setState(() {
        _isListening = true;
        _lastResponse = "Listening..."; 
      });
    }
      
    bool wordsDetected = false;
    try {
      final langCode = SettingsService().locale.value.languageCode;
      final sttLocale = langCode == 'ta' ? 'ta-IN' : 
                       langCode == 'hi' ? 'hi-IN' : 
                       langCode == 'ar' ? 'ar-SA' :
                       langCode == 'zh' ? 'zh-CN' :
                       langCode == 'ja' ? 'ja-JP' :
                       langCode == 'ko' ? 'ko-KR' :
                       langCode == 'fr' ? 'fr-FR' :
                       langCode == 'de' ? 'de-DE' :
                       langCode == 'es' ? 'es-ES' : 'en-US';
      debugPrint('STT: Listening with locale: $sttLocale');

      await _speechToText.listen(
        onResult: (result) {
          debugPrint('Speech result: ${result.recognizedWords} (final: ${result.finalResult})');
          if (result.recognizedWords.isNotEmpty) {
            wordsDetected = true;
            if (mounted) {
              setState(() {
                _lastResponse = result.recognizedWords;
              });
            }
          }
          
          if (result.finalResult) {
            if (mounted) setState(() => _isListening = false);
            if (result.recognizedWords.trim().isNotEmpty) {
              _sendMessage(result.recognizedWords);
            } else if (wordsDetected) {
              _sendMessage(_lastResponse);
            } else {
              if (mounted) setState(() => _lastResponse = "I didn't catch that. Try again?");
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: sttLocale,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _lastResponse = "Mic failed to start: $e";
        });
      }
    }

    // Safety check - Stop listening if no words detected after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isListening && !wordsDetected && !_speechToText.isListening) {
        setState(() {
          _isListening = false;
          if (_lastResponse == "Listening...") {
            _lastResponse = "No sound detected. Please check your mic.";
          }
        });
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    if (mounted) {
      setState(() {
        _lastResponse = ""; 
      });
    }

    try {
      final token = await _storage.read(key: 'jwt_token');
      final request = http.Request('POST', Uri.parse(ApiConstants.chatMessageUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-auth-token': token ?? '',
      });
      request.body = jsonEncode({
        'message': text,
        'mode': _selectedMode,
      });

      final client = http.Client();
      final streamedResponse = await client.send(request);

      String fullResponse = "";
      String currentEmotion = "neutral";
      String currentAction = "idle";
      double currentSpeed = 1.0;
      String currentEyeState = "normal";

      streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        line = line.trim();
        if (line.startsWith('data:')) {
          String payload = line.replaceFirst(RegExp(r'^data:\s*'), '');
          if (payload.trim() == '[DONE]') return;

          final jsonStart = payload.indexOf('{');
          if (jsonStart == -1) return;

          final data = payload.substring(jsonStart).trim();
          try {
            if (data.isEmpty) return;
            final json = jsonDecode(data);

              if (json['type'] == 'metadata') {
                final metadata = json['payload'];
                final avatar = metadata['avatar'];
                final safety = metadata['safety'];
                
                if (safety != null && safety['detected'] == true) {
                  _handleSafetyAlert(safety);
                }
                
                currentEmotion = avatar['facialExpression'] ?? avatar['emotion'] ?? 'neutral';
                currentAction = avatar['animation'] ?? avatar['gesture'] ?? avatar['action'] ?? 'idle';
                currentSpeed = (avatar['speed'] as num?)?.toDouble() ?? 1.0;
                currentEyeState = avatar['eye_state'] ?? 'normal';

                if (mounted) {
                  _onMessageReceived(_lastResponse, currentAction, currentEmotion, currentSpeed, currentEyeState);
                }
              } else if (json['type'] == 'text' || json.containsKey('content')) {
              final content = json['content'] as String;
              fullResponse += content;
              if (mounted) {
                setState(() {
                  _lastResponse = fullResponse;
                });
              }
            }
          } catch (e) {
            debugPrint("JSON Parse Error: $e");
          }
        }
      }, onDone: () async {
        if (mounted) {
          _onMessageReceived(fullResponse, currentAction, currentEmotion, currentSpeed, currentEyeState);
          await _ttsService.speak(fullResponse);
        }
        client.close();
      }, onError: (e) {
        debugPrint('Stream error: $e');
        client.close();
      });

    } catch (e) {
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _onMessageReceived(String reply, String action, String emotion, double speed, String eyeState) {
    _actionTimer?.cancel();
    
    setState(() {
      if (reply.isNotEmpty && reply != _lastResponse) {
        _lastResponse = reply;
      }
      _currentAction = action;
      _currentEmotion = emotion;
      _currentSpeed = speed;
      _currentEyeState = eyeState;
    });

    // If it's a special action (not idle or talking), revert after 6 seconds
    if (action != 'idle' && action != 'talk' && action != 'talking') {
      _actionTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() {
            // Revert to talk if still speaking, otherwise idle
            _currentAction = _isTalking ? 'talk' : 'idle';
          });
        }
      });
    }
  }

  void _handleSafetyAlert(Map<String, dynamic> safety) {
    final risk = safety['riskLevel'];
    if (risk == 'Medium' || risk == 'High') {
      setState(() {
        _showDoctorSuggestion = true;
        _lastSafetyAlert = safety;
      });
    }
  }

  void _navigateToDoctorBooking() {
    setState(() => _showDoctorSuggestion = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FindDoctorsScreen()),
    );
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
                    ? AvatarView(
                        avatarUrl: _avatarUrl!,
                        action: _currentAction,
                        emotion: _currentEmotion,
                        speed: _currentSpeed,
                        eyeState: _currentEyeState,
                        isTalking: _isTalking,
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

              // Doctor Suggestion Overlay
              if (_showDoctorSuggestion)
                Positioned(
                  bottom: 180,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900]!.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.translate('doctor_suggestion_msg'),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _showDoctorSuggestion = false),
                              child: Text(l10n.translate('no_thanks')),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _navigateToDoctorBooking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(l10n.translate('book_now')),
                            ),
                          ],
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
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

                        const SizedBox(width: 4),

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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

                        const SizedBox(width: 4),
                        
                        // Action Buttons Group
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Debug Button
                            GestureDetector(
                              onTap: _showDebugPanel,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[900] : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.bug_report,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Voice Selection Button
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const VoiceSelectionScreen()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[900] : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.record_voice_over,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Chat/History Button
                            GestureDetector(
                              onTap: () => setState(() => _isChatOpen = true),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.forum_outlined,
                                  color: Colors.white,
                                  size: 18,
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

  void _showDebugPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Debug Animations", 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87
                )
              ),
              const SizedBox(height: 15),
              
              Text("Actions", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'idle', 'wave', 'walk', 'happy', 'angry', 'yell', 'talking', 'sad', 
                  'angry_point', 'excited', 'happy_walk', 'kneeling', 'laying', 
                  'rejected', 'sitting_angry', 'sitting_disbelief', 'sleeping', 'dance'
                ].map((action) => 
                  ActionChip(
                    label: Text(action),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      Navigator.pop(context);
                      _onMessageReceived("Debug: $action", action, _currentEmotion, 1.0, _currentEyeState);
                    },
                  )
                ).toList(),
              ),
              const SizedBox(height: 15),
              
              Text("Emotions", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['neutral', 'happy', 'sad', 'angry', 'surprised', 'excited'].map((emotion) => 
                  ActionChip(
                    label: Text(emotion),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      Navigator.pop(context);
                      _onMessageReceived("Debug: $emotion", _currentAction, emotion, 1.0, _currentEyeState);
                    },
                  )
                ).toList(),
              ),
              const SizedBox(height: 15),
              
              Text("Eye States", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['normal', 'focused', 'soft', 'blink'].map((state) => 
                  ActionChip(
                    label: Text(state),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      Navigator.pop(context);
                      _onMessageReceived("Debug: $state", _currentAction, _currentEmotion, 1.0, state);
                    },
                  )
                ).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
