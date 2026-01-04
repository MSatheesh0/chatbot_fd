import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final _storage = const FlutterSecureStorage();
  
  // State
  List<Map<String, String>> _voices = [];
  Map<String, String>? _currentVoice;
  bool _ttsEnabledForChatbot = false;
  bool _isSpeaking = false;

  // Getters
  List<Map<String, String>> get voices => _voices;
  Map<String, String>? get currentVoice => _currentVoice;
  bool get ttsEnabledForChatbot => _ttsEnabledForChatbot;
  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    await _initTts();
    await _loadSettings();
  }

  Future<void> _initTts() async {
    if (Platform.isIOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
          ],
          IosTextToSpeechAudioMode.voicePrompt
      );
    }

    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setPitch(1.0);

    await _flutterTts.awaitSpeakCompletion(true);
    
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      debugPrint("TTS Started");
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      debugPrint("TTS Completed");
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      debugPrint("TTS Cancelled");
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint("TTS Error: $msg");
    });

    await _loadVoices();
  }

  Future<void> _loadVoices() async {
    try {
      var voices = await _flutterTts.getVoices;
      if (voices != null) {
        _voices = [];
        for (var voice in voices) {
          // voice is typically a Map with 'name' and 'locale'
          String name = voice['name'].toString();
          String locale = voice['locale'].toString();
          
          // Basic filtering for English voices (can be expanded)
          if (locale.startsWith('en')) {
             _voices.add({
              'name': name,
              'locale': locale,
              'id': name, // Use name as ID for system TTS
              'gender': _guessGender(name),
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading voices: $e");
    }
  }

  String _guessGender(String name) {
    String lowerName = name.toLowerCase();
    if (lowerName.contains('female') || lowerName.contains('girl') || lowerName.contains('samantha') || lowerName.contains('karen') || lowerName.contains('tessa')) {
      return 'female';
    }
    if (lowerName.contains('male') || lowerName.contains('boy') || lowerName.contains('daniel') || lowerName.contains('rishi') || lowerName.contains('fred')) {
      return 'male';
    }
    return 'unknown'; // Fallback
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load local preferences first
      String? savedVoiceId = prefs.getString('tts_voice_id');
      String? savedVoiceName = prefs.getString('tts_voice_name');
      String? savedVoiceGender = prefs.getString('tts_voice_gender');
      _ttsEnabledForChatbot = prefs.getBool('tts_enabled_chatbot') ?? false;

      if (savedVoiceId != null && savedVoiceName != null) {
        _currentVoice = {
          'id': savedVoiceId,
          'name': savedVoiceName,
          'gender': savedVoiceGender ?? 'unknown',
        };
      } else {
        // Set default if not found
        if (_voices.isNotEmpty) {
          _currentVoice = _voices.first;
          await updateSettings(
            voiceId: _currentVoice!['id'],
            voiceName: _currentVoice!['name'],
            gender: _currentVoice!['gender'],
          );
        }
      }

      // Sync with backend (optional, but good for persistence)
      // We don't block on this
      _syncWithBackend();

    } catch (e) {
      debugPrint("Error loading TTS settings: $e");
    }
  }

  Future<void> _syncWithBackend() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConstants.voiceSettingsUrl),
        headers: {'x-auth-token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // If backend has settings, we could override local, or vice versa. 
        // For now, let's assume local is truth if set, otherwise backend.
        if (_currentVoice == null && data['voiceId'] != null) {
           // Find voice by ID (name)
           var found = _voices.firstWhere((v) => v['id'] == data['voiceId'], orElse: () => {});
           if (found.isNotEmpty) {
             _currentVoice = found;
             // Save locally
             final prefs = await SharedPreferences.getInstance();
             await prefs.setString('tts_voice_id', found['id']!);
             await prefs.setString('tts_voice_name', found['name']!);
             await prefs.setString('tts_voice_gender', found['gender']!);
             await prefs.setBool('tts_enabled_chatbot', data['ttsEnabledForChatbot'] ?? false);
             _ttsEnabledForChatbot = data['ttsEnabledForChatbot'] ?? false;
           }
        }
      }
    } catch (e) {
      debugPrint("Error syncing TTS settings: $e");
    }
  }

  Future<void> updateSettings({
    String? voiceId,
    String? voiceName,
    String? gender,
    bool? ttsEnabledForChatbot,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (voiceId != null) {
      await prefs.setString('tts_voice_id', voiceId);
      // Update in memory
      if (_currentVoice == null) _currentVoice = {};
      _currentVoice!['id'] = voiceId;
    }
    if (voiceName != null) {
      await prefs.setString('tts_voice_name', voiceName);
      if (_currentVoice == null) _currentVoice = {};
      _currentVoice!['name'] = voiceName;
    }
    if (gender != null) {
      await prefs.setString('tts_voice_gender', gender);
      if (_currentVoice == null) _currentVoice = {};
      _currentVoice!['gender'] = gender;
    }
    if (ttsEnabledForChatbot != null) {
      await prefs.setBool('tts_enabled_chatbot', ttsEnabledForChatbot);
      _ttsEnabledForChatbot = ttsEnabledForChatbot;
    }

    // Sync to backend
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        await http.put(
          Uri.parse(ApiConstants.voiceSettingsUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-auth-token': token
          },
          body: jsonEncode({
            'voiceId': _currentVoice?['id'],
            'voiceName': _currentVoice?['name'],
            'gender': _currentVoice?['gender'],
            'ttsEnabledForChatbot': _ttsEnabledForChatbot
          }),
        );
      }
    } catch (e) {
      debugPrint("Error updating backend settings: $e");
    }
  }

  Future<void> speak(String text, {Map<String, String>? voice}) async {
    Map<String, String>? targetVoice = voice ?? _currentVoice;
    
    if (targetVoice != null) {
      // Set voice
      // flutter_tts setVoice takes a map {"name": "...", "locale": "..."}
      // We stored these in _voices
      var voiceData = _voices.firstWhere(
          (v) => v['id'] == targetVoice!['id'], 
          orElse: () => _voices.isNotEmpty ? _voices.first : {}
      );
      
      if (voiceData.isNotEmpty) {
        await _flutterTts.setVoice({
          "name": voiceData['name']!,
          "locale": voiceData['locale']!
        });
      }
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
