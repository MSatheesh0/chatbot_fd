import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (e) {
      debugPrint('Could not set local location: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Request Android 13+ permissions
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> scheduleAppointmentReminders({
    required int appointmentId, // Use hash or unique int
    required String doctorName,
    required DateTime appointmentTime,
  }) async {
    // 24 Hours Before
    final time24h = appointmentTime.subtract(const Duration(hours: 24));
    if (time24h.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: appointmentId + 1, // Unique ID
        title: 'Doctor Appointment Reminder',
        body: 'You have an appointment with Dr. $doctorName tomorrow at ${appointmentTime.hour}:${appointmentTime.minute.toString().padLeft(2, '0')}',
        scheduledTime: time24h,
      );
    }

    // 2 Hours Before
    final time2h = appointmentTime.subtract(const Duration(hours: 2));
    if (time2h.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: appointmentId + 2, // Unique ID
        title: 'Upcoming Appointment',
        body: 'You have an appointment with Dr. $doctorName in 2 hours!',
        scheduledTime: time2h,
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_channel',
          'Appointment Reminders',
          channelDescription: 'Reminders for upcoming doctor appointments',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('Scheduled notification for $scheduledTime');
  }

  Future<void> cancelAppointmentReminders(int appointmentId) async {
    await flutterLocalNotificationsPlugin.cancel(appointmentId + 1);
    await flutterLocalNotificationsPlugin.cancel(appointmentId + 2);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
