import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/avatar_view.dart';
import '../services/reminder_service.dart';
import '../constants.dart';

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
      // Use the simpler endpoint that uses the token to identify the user
      final response = await http.get(
        Uri.parse(ApiConstants.activeAvatarUrl),
        headers: {'x-auth-token': token ?? ''},
      );
      
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

      await _reminderService.speak("This is your reminder: ${widget.title}. ${widget.description ?? ''}");
      // Wait a bit before repeating. flutter_tts speak is async but returns when speaking starts (usually) or finishes depending on platform.
      // We'll add a safe delay.
      await Future.delayed(const Duration(seconds: 8)); 
    }
  }

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
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Reminder',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.description!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
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
                                side: const BorderSide(color: Color(0xFF6A11CB)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Snooze',
                                style: TextStyle(
                                  color: Color(0xFF6A11CB),
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
                              child: const Text(
                                'Stop',
                                style: TextStyle(
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
      ),
    );
  }

  void _showSnoozeOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('5 minutes'),
            onTap: () {
              Navigator.pop(context);
              _snooze(5);
            },
          ),
          ListTile(
            title: const Text('10 minutes'),
            onTap: () {
              Navigator.pop(context);
              _snooze(10);
            },
          ),
          ListTile(
            title: const Text('15 minutes'),
            onTap: () {
              Navigator.pop(context);
              _snooze(15);
            },
          ),
        ],
      ),
    );
  }
}
