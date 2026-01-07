import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/avatar_view.dart';
import '../services/reminder_service.dart';
import '../constants.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class ReminderOverlayScreen extends StatefulWidget {
  final int reminderId;
  final String title;
  final String? description;
  final String? avatarUrl;

  const ReminderOverlayScreen({
    super.key,
    required this.reminderId,
    required this.title,
    this.description,
    this.avatarUrl,
  });

  @override
  State<ReminderOverlayScreen> createState() => _ReminderOverlayScreenState();
}

class _ReminderOverlayScreenState extends State<ReminderOverlayScreen> {
  final ReminderService _reminderService = ReminderService();
  final _storage = const FlutterSecureStorage();
  bool _isSpeaking = false;
  String _currentAvatarUrl = 'https://models.readyplayer.me/64b73e0e3c7943482d8c9735.glb'; // Default

  @override
  void initState() {
    super.initState();
    if (widget.avatarUrl != null) {
      _currentAvatarUrl = widget.avatarUrl!;
    } else {
      _fetchActiveAvatar();
    }
    _startSpeaking();
  }

  Future<void> _fetchActiveAvatar() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) {
        debugPrint('No token found, using default avatar');
        return;
      }

      // Use the simpler endpoint that uses the token to identify the user
      final response = await http.get(
        Uri.parse(ApiConstants.activeAvatarUrl),
        headers: {'x-auth-token': token},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final avatarData = jsonDecode(response.body);
        if (mounted && avatarData['url'] != null) {
          setState(() {
            _currentAvatarUrl = avatarData['url'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching avatar: $e');
      // Fallback already set in _currentAvatarUrl
    }
  }

  Future<void> _startSpeaking() async {
    if (_isSpeaking) return;
    setState(() => _isSpeaking = true);
    
    // Initial delay to let the UI build
    await Future.delayed(const Duration(seconds: 1));
    
    // Loop the message
    while (_isSpeaking && mounted) {
      // Check if the alarm was stopped externally (e.g. notification button)
      final isRinging = await _reminderService.isRinging(widget.reminderId);
      if (!isRinging) {
        _stop();
        return;
      }

      await _reminderService.speak("${l10n.translate('reminder_msg_prefix')}: ${widget.title}. ${widget.description ?? ''}");
      // Wait a bit before repeating. flutter_tts speak is async but returns when speaking starts (usually) or finishes depending on platform.
      // We'll add a safe delay.
      await Future.delayed(const Duration(seconds: 8)); 
    }
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  Future<void> _stop() async {
    setState(() => _isSpeaking = false);
    await _reminderService.stopSpeaking();
    // Aggressively stop the reminder
    await _reminderService.stopReminder(widget.reminderId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze(int minutes) async {
    setState(() => _isSpeaking = false);
    await _reminderService.stopSpeaking();
    await _reminderService.snoozeReminder(
      widget.reminderId,
      widget.title,
      Duration(minutes: minutes),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _isSpeaking = false;
    _reminderService.stopSpeaking();
    // Ensure alarm/vibration stops when screen is closed
    _reminderService.stopReminder(widget.reminderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.black87,
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return Stack(
            children: [
              // Avatar centered
              Center(
                child: SizedBox(
                  height: 400,
                  child: AvatarView(
                    avatarUrl: _currentAvatarUrl,
                    action: 'talking', 
                    emotion: 'happy',
                  ),
                ),
              ),
              // Overlay UI
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.translate('reminder'),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.description != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.description!,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _showSnoozeOptions(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: BorderSide(color: isDark ? Colors.deepPurpleAccent : const Color(0xFF6A11CB)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.translate('snooze'),
                                    style: TextStyle(
                                      color: isDark ? Colors.deepPurpleAccent : const Color(0xFF6A11CB),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _stop,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444), // Red for Stop
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: Text(
                                    l10n.translate('stop'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnoozeOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _snoozeTile(5),
          _snoozeTile(10),
          _snoozeTile(15),
        ],
      ),
    );
  }

  Widget _snoozeTile(int mins) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      title: Text(
        '$mins ${l10n.translate('minutes')}',
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      ),
      onTap: () {
        Navigator.pop(context);
        _snooze(mins);
      },
    );
  }
}
