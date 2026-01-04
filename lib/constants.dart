import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    String? envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return 'https://chatbot-bc.onrender.com';
    } else {
      return 'https://chatbot-bc.onrender.com';
    }
  }

  static String get loginUrl => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get avatarsUrl => '$baseUrl/avatars/my';
  static String get baseAvatarsUrl => '$baseUrl/avatars';
  static String get setActiveAvatarUrl => '$baseUrl/avatars/set-active';
  static String get activeAvatarUrl => '$baseUrl/avatars/active';
  static String get chatMessageUrl => '$baseUrl/chat/message';
  static String get conversationsUrl => '$baseUrl/chat/conversations';
  static String get messagesUrl => '$baseUrl/chat/messages';
  static String get profileUrl => '$baseUrl/auth/profile';
  static String get doctorsUrl => '$baseUrl/doctors';
  static String get nearbyDoctorsUrl => '$baseUrl/doctors/nearby';
  static String get remindersUrl => '$baseUrl/reminders';
  static String get analysisUrl => '$baseUrl/analysis/emotions';
  static String get voiceSettingsUrl => '$baseUrl/voice/settings';
  static String get settingsUrl => '$baseUrl/settings';
  static String get feedbackUrl => '$baseUrl/support/feedback';
}
