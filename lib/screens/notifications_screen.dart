import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import 'appointment_details_screen.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notifications'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _notifications = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      await http.put(
        Uri.parse('${ApiConstants.baseUrl}/notifications/$id/read'),
        headers: {'x-auth-token': token ?? ''},
      );
      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n['_id'] == id);
        if (index != -1) {
          _notifications[index]['readStatus'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    if (!notification['readStatus']) {
      _markAsRead(notification['_id']);
    }

    // Fetch appointment details
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/appointments/${notification['appointmentId']}'),
        headers: {'x-auth-token': token ?? ''},
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        final appointment = jsonDecode(response.body);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentDetailsScreen(appointment: appointment),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment details not found')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF3E5F5),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: isDark ? Colors.black : const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final isRead = notification['readStatus'] ?? false;
                    final date = DateTime.parse(notification['scheduledTime']);
                    final timeAgo = _getTimeAgo(date);

                    return Card(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isRead ? BorderSide.none : const BorderSide(color: Color(0xFF6A11CB), width: 1),
                      ),
                      child: ListTile(
                        onTap: () => _handleNotificationTap(notification),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6A11CB).withOpacity(0.1),
                          child: const Icon(Icons.calendar_today, color: Color(0xFF6A11CB)),
                        ),
                        title: Text(
                          notification['reminderType'] == '24h'
                              ? 'Appointment Tomorrow'
                              : 'Appointment Soon',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Dr. ${notification['doctorName']}',
                              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sent: $timeAgo',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        trailing: !isRead
                            ? const CircleAvatar(
                                radius: 5,
                                backgroundColor: Color(0xFF6A11CB),
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
