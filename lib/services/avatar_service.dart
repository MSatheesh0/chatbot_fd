import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  final String baseUrl = 'http://10.97.126.65:5000';
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  // State
  String _currentLanguage = 'en';
  String _currentEmotion = 'neutral';
  String _currentAction = 'idle';
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isEmergencyMode = false;
  double _riskLevel = 0.0;
  
  // Controllers
  final ValueNotifier<String> currentText = ValueNotifier('');
  final ValueNotifier<String> currentAnimation = ValueNotifier('idle');
  final ValueNotifier<double> speakingProgress = ValueNotifier(0.0);
  
  // Getters
  String get currentLanguage => _currentLanguage;
  String get currentEmotion => _currentEmotion;
  String get currentAction => _currentAction;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isEmergencyMode => _isEmergencyMode;
  double get riskLevel => _riskLevel;

  // Initialize the service
  Future<void> initialize() async {
    await _initializeSpeech();
    await _initializeTTS();
    await _loadUserSettings();
  }

  // Initialize speech recognition
  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        _isListening = status == 'listening';
        notifyListeners();
      },
      onError: (error) => _handleSpeechError(error.errorMsg),
    );
    
    if (!available) {
      debugPrint('Speech recognition not available');
    }
  }

  // Initialize text-to-speech
  Future<void> _initializeTTS() async {
    _tts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS Error: $msg');
      notifyListeners();
    });
  }

  // Load user settings from shared preferences
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  // Start listening to user's voice
  Future<void> startListening() async {
    if (await Permission.microphone.request().isGranted) {
      await _speech.listen(
        onResult: _handleSpeechResult,
        localeId: _currentLanguage,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
      );
    }
  }

  // Stop listening to user's voice
  Future<void> stopListening() async {
    await _speech.stop();
  }

  // Handle speech recognition result
  void _handleSpeechResult(stt.SpeechRecognitionResult result) {
    currentText.value = result.recognizedWords;
    if (result.finalResult) {
      _processUserInput(result.recognizedWords);
    }
  }

  // Process user input and get AI response
  Future<void> _processUserInput(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/avatars/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'language': _currentLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentEmotion = data['emotion'] ?? 'neutral';
        _currentAction = data['action'] ?? 'no_action';
        _riskLevel = (data['riskLevel'] ?? 0.0).toDouble();
        
        // Handle high risk situations
        if (_riskLevel >= 90) {
          _handleHighRiskSituation();
        }
        
        // Generate and speak response
        await _generateAndSpeakResponse(text);
      }
    } catch (e) {
      debugPrint('Error processing user input: $e');
    }
  }

  // Generate and speak response
  Future<void> _generateAndSpeakResponse(String userInput) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/avatars/response'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': userInput,
          'emotion': _currentEmotion,
          'action': _currentAction,
          'language': _currentLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String responseText = data['text'];
        
        // Update UI with response
        currentText.value = responseText;
        
        // Speak the response
        await _tts.setLanguage(_currentLanguage);
        await _tts.speak(responseText);
        
        // Update animation based on emotion and action
        _updateAvatarAnimation();
      }
    } catch (e) {
      debugPrint('Error generating response: $e');
    }
  }

  // Handle high risk situations
  Future<void> _handleHighRiskSituation() async {
    _isEmergencyMode = true;
    notifyListeners();
    
    // Get emergency contact info
    final prefs = await SharedPreferences.getInstance();
    final emergencyContact = prefs.getString('emergency_contact') ?? '';
    
    if (emergencyContact.isNotEmpty) {
      // In a real app, you would handle the emergency call
      debugPrint('Emergency: Contacting $emergencyContact');
    }
  }

  // Update avatar animation based on current state
  void _updateAvatarAnimation() {
    String animation = 'idle';
    
    if (_isSpeaking) {
      animation = 'talking';
    } else if (_currentAction == 'breathing') {
      animation = 'breathing';
    } else if (_currentEmotion == 'happy') {
      animation = 'happy';
    } else if (_currentEmotion == 'sad') {
      animation = 'sad';
    } else if (_currentEmotion == 'angry') {
      animation = 'angry';
    } else if (_currentEmotion == 'surprised') {
      animation = 'surprised';
    }
    
    currentAnimation.value = animation;
  }

  // Handle speech recognition errors
  void _handleSpeechError(String errorMsg) {
    debugPrint('Speech recognition error: $errorMsg');
    // Implement error handling logic
  }

  // Clean up resources
  void dispose() {
    _speech.stop();
    _tts.stop();
    currentText.dispose();
    currentAnimation.dispose();
    speakingProgress.dispose();
  }
  
  // Notify listeners when state changes
  void notifyListeners() {
    // This would typically be handled by a state management solution
    // In a real app, you might use Provider, Riverpod, or similar
    debugPrint('State updated - Emotion: $_currentEmotion, Action: $_currentAction, Risk: $_riskLevel');
  }
}
