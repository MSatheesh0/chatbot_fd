import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    await _initSystemTts();
    await _loadVoices();
    await _loadSettings();
  }

  Future<void> _initSystemTts() async {
    if (!kIsWeb && Platform.isIOS) {
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
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    
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
          
          // Filter for English voices
          if (locale.toLowerCase().contains('en')) {
             _voices.add({
              'name': name,
              'locale': locale,
              'id': name, // Use name as ID for system TTS
              'gender': _guessGender(name, locale),
              'description': '$name ($locale)',
            });
          }
        }
      }
      debugPrint("TTS: Loaded ${_voices.length} system voices.");
    } catch (e) {
      debugPrint("Error loading system voices: $e");
    }
  }

  String _guessGender(String name, String locale) {
    String lower = name.toLowerCase();
    
    // Known Female Keywords
    if (lower.contains('female') || 
        lower.contains('woman') || 
        lower.contains('girl') ||
        lower.contains('samantha') || 
        lower.contains('karen') || 
        lower.contains('tessa') || 
        lower.contains('victoria') ||
        lower.contains('zira') ||
        lower.contains('ava') ||
        lower.contains('susan') ||
        lower.contains('fiona') ||
        lower.contains('veena') ||
        lower.contains('heera') ||
        lower.contains('rachel') ||
        lower.contains('juhi') ||
        lower.contains('lekh') ||
        lower.contains('google tts voice 1') || // Google often alternates, 1 is usually female
        lower.contains('google tts voice 3') ||
        lower.contains('google tts voice 5') ||
        lower.contains('en-us-x-sfg') || // Sfg = female
        lower.contains('en-us-x-tpd') ||
        lower.contains('en-gb-x-fis')
       ) {
      return 'female';
    }

    // Known Male Keywords
    if (lower.contains('male') || 
        lower.contains('man') || 
        lower.contains('boy') ||
        lower.contains('daniel') || 
        lower.contains('rishi') || 
        lower.contains('fred') || 
        lower.contains('alex') ||
        lower.contains('david') ||
        lower.contains('mark') ||
        lower.contains('ravi') ||
        lower.contains('neil') ||
        lower.contains('google tts voice 2') || // Google often alternates, 2 is usually male
        lower.contains('google tts voice 4') ||
        lower.contains('google tts voice 6') ||
        lower.contains('en-us-x-iol') || // Iol = male
        lower.contains('en-gb-x-rjs')
       ) {
      return 'male';
    }
    
    // Fallback: Assign based on hash to distribute them between tabs
    return name.length % 2 == 0 ? 'female' : 'male'; 
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load local preferences
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
    } catch (e) {
      debugPrint("Error loading TTS settings: $e");
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
  }

  Future<void> speak(String text, {Map<String, String>? voice}) async {
    await stop();
    
    Map<String, String>? targetVoice = voice ?? _currentVoice;
    
    if (targetVoice != null) {
      await _flutterTts.setVoice({
        "name": targetVoice['name']!,
        "locale": targetVoice['locale'] ?? "en-US"
      });
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
