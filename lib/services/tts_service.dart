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
  bool _ttsEnabledForChatbot = true;
  bool _isInitialized = false;
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);

  // Getters
  List<Map<String, String>> get voices => _voices;
  Map<String, String>? get currentVoice => _currentVoice;
  bool get ttsEnabledForChatbot => _ttsEnabledForChatbot;
  bool get isSpeaking => isSpeakingNotifier.value;
  bool get isInitialized => _isInitialized;

  Future<void> init({bool forceRefresh = false}) async {
    if (_isInitialized && _voices.isNotEmpty && !forceRefresh) {
      debugPrint("TTS: Already initialized with voices, skipping...");
      return;
    }
    
    debugPrint("TTS: Initializing service...");
    await _initSystemTts();
    await _loadVoices();
    await _loadSettings();
    _isInitialized = true;
    debugPrint("TTS: Initialization complete.");
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
      isSpeakingNotifier.value = true;
      debugPrint("TTS Started");
    });

    _flutterTts.setCompletionHandler(() {
      isSpeakingNotifier.value = false;
      debugPrint("TTS Completed");
    });

    _flutterTts.setCancelHandler(() {
      isSpeakingNotifier.value = false;
      debugPrint("TTS Cancelled");
    });

    _flutterTts.setErrorHandler((msg) {
      isSpeakingNotifier.value = false;
      debugPrint("TTS Error: $msg");
    });
  }

  Future<void> _loadVoices() async {
    try {
      var voices = await _flutterTts.getVoices;
      if (voices != null) {
        _voices = [];
        for (var voice in voices) {
          try {
            // voice is typically a Map with 'name' and 'locale'
            String name = voice['name']?.toString() ?? 'Unknown';
            String locale = voice['locale']?.toString() ?? 'en-US';
            
            // Some platforms (like Android) might provide gender in the map
            String? systemGender = voice['gender']?.toString();
            
            _voices.add({
              'name': name,
              'locale': locale,
              'id': name,
              'gender': _guessGender(name, locale, systemGender),
              'quality': _detectQuality(name),
              'description': '$name ($locale)',
            });
          } catch (e) {
            debugPrint("Error processing voice: $e");
          }
        }
      }
      debugPrint("TTS: Loaded ${_voices.length} system voices.");
    } catch (e) {
      debugPrint("Error loading system voices: $e");
    }
  }

  String _guessGender(String name, String locale, [String? systemGender]) {
    // 1. Use system gender if available and valid
    if (systemGender != null) {
      String sg = systemGender.toLowerCase();
      if (sg.contains('female') || sg == 'f' || sg == '2') return 'female';
      if (sg.contains('male') || sg == 'm' || sg == '1') return 'male';
    }

    String lower = name.toLowerCase();
    
    // 2. Check for explicit Female keywords
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
        lower.contains('anitha') ||
        lower.contains('priya') ||
        lower.contains('lakshmi') ||
        lower.contains('kavitha') ||
        lower.contains('aarthi') ||
        lower.contains('divya') ||
        lower.contains('deepa') ||
        lower.contains('gayathri') ||
        lower.contains('janani') ||
        lower.contains('kala') ||
        lower.contains('meena') ||
        lower.contains('nandhini') ||
        lower.contains('pavithra') ||
        lower.contains('ramya') ||
        lower.contains('sandhya') ||
        lower.contains('uma') ||
        lower.contains('vidhya') ||
        lower.contains('google tts voice 1') || 
        lower.contains('google tts voice 3') ||
        lower.contains('google tts voice 5') ||
        lower.contains('google tts voice 7') ||
        lower.contains('en-us-x-sfg') || 
        lower.contains('en-us-x-tpd') ||
        lower.contains('en-gb-x-fis') ||
        lower.contains('ta-in-x-tap-network') || 
        lower.contains('hi-in-x-hie-local') ||
        lower.contains('-w-') || // Often stands for Woman/Female in some naming conventions
        lower.contains('female')
       ) {
      return 'female';
    }

    // 3. Check for explicit Male keywords
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
        lower.contains('kumar') ||
        lower.contains('raj') ||
        lower.contains('senthil') ||
        lower.contains('vijay') ||
        lower.contains('arun') ||
        lower.contains('babu') ||
        lower.contains('chandru') ||
        lower.contains('dinesh') ||
        lower.contains('ganesh') ||
        lower.contains('hari') ||
        lower.contains('jagan') ||
        lower.contains('karthik') ||
        lower.contains('lokesh') ||
        lower.contains('mani') ||
        lower.contains('naveen') ||
        lower.contains('prabhu') ||
        lower.contains('ramesh') ||
        lower.contains('suresh') ||
        lower.contains('vignesh') ||
        lower.contains('google tts voice 2') || 
        lower.contains('google tts voice 4') ||
        lower.contains('google tts voice 6') ||
        lower.contains('google tts voice 8') ||
        lower.contains('en-us-x-iol') || 
        lower.contains('en-gb-x-rjs') ||
        lower.contains('ta-in-x-tam-network') || 
        lower.contains('-m-') || // Often stands for Man/Male
        lower.contains('male')
       ) {
      return 'male';
    }
    
    // 4. Smart Fallback: 
    // If the name contains "Google" and it's an odd number, it's often female in many system distributions.
    // But to be safe, if we can't tell, we default to 'female' because the avatar is female.
    // This is better than putting a female voice in the male tab.
    return 'female'; 
  }

  String _detectQuality(String name) {
    String lower = name.toLowerCase();
    if (lower.contains('network') || 
        lower.contains('neural') || 
        lower.contains('enhanced') || 
        lower.contains('premium') ||
        lower.contains('wavenet') ||
        lower.contains('natural')) {
      return 'high';
    }
    return 'standard';
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load local preferences
      String? savedVoiceId = prefs.getString('tts_voice_id');
      String? savedVoiceName = prefs.getString('tts_voice_name');
      String? savedVoiceGender = prefs.getString('tts_voice_gender');
      _ttsEnabledForChatbot = prefs.getBool('tts_enabled_chatbot') ?? true;

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

  String _detectLanguageLocale(String text) {
    // Check for Tamil
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'ta-IN';
    // Check for Hindi / Devanagari
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi-IN';
    // Check for Arabic
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'ar-SA';
    // Check for Chinese (CJK Unified Ideographs)
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text)) return 'zh-CN';
    // Check for Japanese (Hiragana/Katakana)
    if (RegExp(r'[\u3040-\u30FF]').hasMatch(text)) return 'ja-JP';
    // Check for Korean (Hangul)
    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) return 'ko-KR';
    // Check for French
    if (RegExp(r'[àâäéèêëîïôûùüç]', caseSensitive: false).hasMatch(text)) return 'fr-FR';
    // Check for Spanish
    if (RegExp(r'[áéíóúüñ]', caseSensitive: false).hasMatch(text)) return 'es-ES';
    // Check for German
    if (RegExp(r'[äöüß]', caseSensitive: false).hasMatch(text)) return 'de-DE';
    
    // Default to English
    return 'en-US';
  }

  Future<void> speak(String text, {Map<String, String>? voice}) async {
    await stop();
    
    Map<String, String>? targetVoice = voice ?? _currentVoice;

    // Universal Language Detection
    String detectedLocale = _detectLanguageLocale(text);
    debugPrint("TTS: Detected language locale: $detectedLocale");

    // Try to find the best matching voice for the detected language
    var matchingVoices = _voices.where((v) => 
      (v['locale']?.toLowerCase().startsWith(detectedLocale.split('-')[0].toLowerCase()) ?? false)
    ).toList();

    if (matchingVoices.isNotEmpty) {
      // 1. Try to find a HIGH quality voice in the detected language
      final highQualityVoice = matchingVoices.firstWhere(
        (v) => v['quality'] == 'high',
        orElse: () => matchingVoices.first,
      );
      
      // 2. Only switch if the detected language is different from current or if current isn't high quality
      if (targetVoice == null || !targetVoice['locale']!.toLowerCase().startsWith(detectedLocale.split('-')[0].toLowerCase())) {
        targetVoice = Map<String, String>.from(highQualityVoice);
        debugPrint("TTS: Switched to ${targetVoice['name']} for $detectedLocale (Quality: ${targetVoice['quality']})");
      }
    } else {
      debugPrint("TTS: No matching voices found for $detectedLocale, using system default.");
    }
    
    if (targetVoice != null && targetVoice.isNotEmpty) {
      await _flutterTts.setVoice({
        "name": targetVoice['name']!,
        "locale": targetVoice['locale'] ?? "en-US"
      });
      
      // Fine-tune for realism
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setPitch(1.0);
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
