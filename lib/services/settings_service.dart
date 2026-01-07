import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _storage = const FlutterSecureStorage();

  // ValueNotifiers for reactive UI updates
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  final ValueNotifier<double> textScale = ValueNotifier(1.0);
  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));
  final ValueNotifier<String> timeZone = ValueNotifier('Auto (UTC+05:30)');
  final ValueNotifier<String> dateFormat = ValueNotifier('DD/MM/YYYY');
  
  // Other settings
  bool isVoiceEnabled = true;
  String defaultMode = 'Chat';
  Map<String, String> emergencyContact = {'name': '', 'phone': '', 'relationship': ''};

  Future<void> init() async {
    await _loadLocalSettings();
    _syncWithBackend(); // Fire and forget
  }

  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Theme
    bool isDark = prefs.getBool('is_dark_mode') ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;

    // Font Size
    String fontSize = prefs.getString('font_size') ?? 'Medium';
    _updateTextScale(fontSize);

    // Language
    String lang = prefs.getString('language') ?? 'English';
    _updateLocale(lang);

    // Others
    timeZone.value = prefs.getString('time_zone') ?? 'Auto (UTC+05:30)';
    dateFormat.value = prefs.getString('date_format') ?? 'DD/MM/YYYY';
    isVoiceEnabled = prefs.getBool('voice_enabled') ?? true;
    defaultMode = prefs.getString('default_mode') ?? 'Chat';
    
    String? ecJson = prefs.getString('emergency_contact');
    if (ecJson != null && ecJson.isNotEmpty) {
      try {
        emergencyContact = Map<String, String>.from(jsonDecode(ecJson));
      } catch (e) {
        emergencyContact = {'name': '', 'phone': '', 'relationship': ''};
      }
    }
  }

  Future<void> _syncWithBackend() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConstants.settingsUrl),
        headers: {'x-auth-token': token},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) return;

        final prefs = await SharedPreferences.getInstance();

        if (data['language'] != null) {
          await prefs.setString('language', data['language']);
          _updateLocale(data['language']);
        }
        if (data['isDarkMode'] != null) {
          await prefs.setBool('is_dark_mode', data['isDarkMode']);
          themeMode.value = data['isDarkMode'] ? ThemeMode.dark : ThemeMode.light;
        }
        if (data['fontSize'] != null) {
          await prefs.setString('font_size', data['fontSize']);
          _updateTextScale(data['fontSize']);
        }
        
        if (data['timeZone'] != null) {
           timeZone.value = data['timeZone'];
           await prefs.setString('time_zone', timeZone.value);
        }
        if (data['dateFormat'] != null) {
           dateFormat.value = data['dateFormat'];
           await prefs.setString('date_format', dateFormat.value);
        }
        if (data['isVoiceEnabled'] != null) {
           isVoiceEnabled = data['isVoiceEnabled'];
           await prefs.setBool('voice_enabled', isVoiceEnabled);
        }
        if (data['defaultMode'] != null) {
           defaultMode = data['defaultMode'];
           await prefs.setString('default_mode', defaultMode);
        }
        if (data['emergencyContact'] != null) {
           // Backend returns object, we save as JSON string locally
           final ec = data['emergencyContact'];
           emergencyContact = {
             'name': ec['name'] ?? '',
             'phone': ec['phone'] ?? '',
             'relationship': ec['relationship'] ?? ''
           };
           await prefs.setString('emergency_contact', jsonEncode(emergencyContact));
        }
      }
    } catch (e) {
      debugPrint('Error syncing settings: $e');
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save locally
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is Map) await prefs.setString(key, jsonEncode(value));

    // Update state
    if (key == 'is_dark_mode') themeMode.value = (value as bool) ? ThemeMode.dark : ThemeMode.light;
    if (key == 'font_size') _updateTextScale(value as String);
    if (key == 'language') _updateLocale(value as String);
    if (key == 'time_zone') timeZone.value = value as String;
    if (key == 'date_format') dateFormat.value = value as String;
    if (key == 'voice_enabled') isVoiceEnabled = value as bool;
    if (key == 'default_mode') defaultMode = value as String;
    if (key == 'emergency_contact') emergencyContact = Map<String, String>.from(value as Map);

    // Sync to backend
    _pushToBackend();
  }

  Future<void> _pushToBackend() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Get EC from prefs or state
      String? ecJson = prefs.getString('emergency_contact');
      Map<String, dynamic> ecObj = ecJson != null ? jsonDecode(ecJson) : {};

      final body = {
        'language': prefs.getString('language'),
        'timeZone': prefs.getString('time_zone'),
        'dateFormat': prefs.getString('date_format'),
        'isDarkMode': prefs.getBool('is_dark_mode'),
        'fontSize': prefs.getString('font_size'),
        'isVoiceEnabled': prefs.getBool('voice_enabled'),
        'defaultMode': prefs.getString('default_mode'),
        'emergencyContact': ecObj,
      };

      await http.put(
        Uri.parse(ApiConstants.settingsUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('Error pushing settings: $e');
    }
  }

  // --- Support & Feedback ---

  Future<bool> submitSupportTicket(String subject, String message, String category, Map<String, String> metadata) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/support/ticket'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token ?? ''},
        body: jsonEncode({
          'subject': subject,
          'message': message,
          'category': category,
          'metadata': metadata
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error submitting ticket: $e');
      return false;
    }
  }

  Future<bool> submitFeedback(String message, String type) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/support/feedback'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token ?? ''},
        body: jsonEncode({
          'message': message,
          'type': type,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      return false;
    }
  }

  Future<void> logConsent(String type, String version, String status) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/consent/log'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token ?? ''},
        body: jsonEncode({
          'consentType': type,
          'version': version,
          'status': status
        }),
      );
    } catch (e) {
      debugPrint('Error logging consent: $e');
    }
  }

  void _updateTextScale(String size) {
    switch (size) {
      case 'Small':
        textScale.value = 0.85;
        break;
      case 'Large':
        textScale.value = 1.15;
        break;
      case 'Medium':
      default:
        textScale.value = 1.0;
        break;
    }
  }

  void _updateLocale(String lang) {
    switch (lang) {
      case 'Spanish':
        locale.value = const Locale('es');
        break;
      case 'French':
        locale.value = const Locale('fr');
        break;
      case 'Hindi':
        locale.value = const Locale('hi');
        break;
      case 'German':
        locale.value = const Locale('de');
        break;
      case 'Tamil':
        locale.value = const Locale('ta');
        break;
      case 'English':
      default:
        locale.value = const Locale('en');
        break;
    }
  }

  // --- Formatting Helpers ---

  String formatDate(DateTime date) {
    String format = dateFormat.value;
    if (format == 'DD/MM/YYYY') return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    if (format == 'MM/DD/YYYY') return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    if (format == 'YYYY-MM-DD') return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return date.toString().split(' ')[0];
  }

  String formatTime(DateTime time) {
    // For now, we'll just use the local time but we could apply offset here if needed
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
