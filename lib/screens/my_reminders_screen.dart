import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/reminder_service.dart';
import 'add_reminder_screen.dart';

class MyRemindersScreen extends StatefulWidget {
  const MyRemindersScreen({super.key});

  @override
  State<MyRemindersScreen> createState() => _MyRemindersScreenState();
}

class _MyRemindersScreenState extends State<MyRemindersScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }

  Future<void> _fetchReminders() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      // We need the user ID. For now, let's assume the backend endpoint /reminders/:userId 
      // is what we have. But wait, we don't have the userId easily available here without 
      // decoding the token or fetching profile. 
      // Ideally, the backend should have a GET /reminders/my endpoint.
      // Since I didn't create that, I'll fetch the profile first to get the ID, 
      // OR I'll update the backend to allow GET /reminders/my (which is cleaner).
      // Let's stick to the existing plan: fetch profile first is safest without changing backend again right now.
      // Actually, I can just decode the token if I had a decoder, but fetching profile is robust.
      
      final profileResponse = await http.get(
        Uri.parse(ApiConstants.profileUrl),
        headers: {'x-auth-token': token ?? ''},
      );
      
      if (profileResponse.statusCode != 200) throw Exception('Failed to get user info');
      final userId = jsonDecode(profileResponse.body)['_id'];

      final response = await http.get(
        Uri.parse('${ApiConstants.remindersUrl}/$userId'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _reminders = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load reminders');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching reminders: $e');
    }
  }

  Future<void> _toggleReminder(String id, bool isActive) async {
    // Optimistic update
    final index = _reminders.indexWhere((r) => r['_id'] == id);
    if (index != -1) {
      setState(() {
        _reminders[index]['isActive'] = isActive;
      });
    }

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('${ApiConstants.remindersUrl}/$id'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? '',
        },
        body: jsonEncode({'isActive': isActive}),
      );

      if (response.statusCode == 200) {
        final reminder = _reminders[index];
        final int alarmId = id.hashCode;
        if (isActive) {
           // Reschedule
           // We need the time. It's in the reminder object.
           // But if the time is in the past, we might need to adjust if it's repeating.
           // For now, just schedule it at the original time (Alarm package handles past times by firing immediately or ignoring depending on config, usually fires immediately if not too old)
           // Actually, if it's in the past and not repeating, it shouldn't be scheduled.
           // But let's assume the user wants to re-enable it.
           final dt = DateTime.parse(reminder['time']);
           if (dt.isAfter(DateTime.now())) {
             await ReminderService().scheduleReminder(
               id: alarmId,
               title: reminder['message'],
               description: reminder['description'],
               dateTime: dt,
               vibrate: reminder['vibration'] ?? false,
             );
           }
        } else {
          await ReminderService().stopReminder(alarmId);
        }
      }

    } catch (e) {
      // Revert on error
      if (index != -1) {
        setState(() {
          _reminders[index]['isActive'] = !isActive;
        });
      }
      debugPrint('Error toggling reminder: $e');
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConstants.remindersUrl}/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _reminders.removeWhere((r) => r['_id'] == id);
        });
        
        await ReminderService().stopReminder(id.hashCode);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reminders', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFEF4444), // Red Header
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddReminderScreen()),
          );
          if (result == true) {
            _fetchReminders();
          }
        },
        backgroundColor: const Color(0xFFEF4444),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFFFFE4E6), // Light Coral / Pink Background
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _reminders.isEmpty
                ? const Center(
                    child: Text(
                      'No reminders set.',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      final date = DateTime.parse(reminder['time']);
                      final formattedTime = DateFormat('hh:mm a').format(date);
                      final formattedDate = DateFormat('MMM d, yyyy').format(date);
                      final bool isActive = reminder['isActive'] ?? true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formattedDate,
                                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                              ),
                            ],
                          ),
                          title: Text(
                            reminder['message'],
                            style: TextStyle(
                              color: isActive ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: isActive ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            'Repeat: ${reminder['repeat'] ?? 'None'}',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                activeColor: const Color(0xFFEF4444),
                                onChanged: (val) => _toggleReminder(reminder['_id'], val),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) {
                                          // Ensure ID is passed correctly
                                          final reminderData = Map<String, dynamic>.from(reminder);
                                          if (reminderData['id'] == null && reminderData['_id'] != null) {
                                            reminderData['id'] = reminderData['_id'];
                                          }
                                          return AddReminderScreen(reminderToEdit: reminderData);
                                        },
                                      ),
                                    );
                                    _fetchReminders();
                                  } else if (value == 'delete') {
                                    _deleteReminder(reminder['_id']);
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: Color(0xFF6B7280)),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Color(0xFFEF4444)),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
