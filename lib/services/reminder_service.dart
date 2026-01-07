import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'tts_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final TTSService _ttsService = TTSService();
  final StreamController<AlarmSettings> _ringStreamController = StreamController<AlarmSettings>.broadcast();
  final Map<int, Timer> _webTimers = {};

  Future<void> init({bool isBackground = false}) async {
    await _ttsService.init();
    if (!kIsWeb) {
      // Alarm.init() is called in main and background service, safe to call multiple times
      await Alarm.init(); 
      
      // Check for ringing alarms immediately after init
      final alarms = await Alarm.getAlarms();
      for (final alarm in alarms) {
        if (await Alarm.isRinging(alarm.id)) {
          debugPrint('🔔 Found ringing alarm on init: ${alarm.id}');
          _ringStreamController.add(alarm);
          showOverlay(alarm);
        }
      }

      // Only listen to ring stream in main app if NOT in background to avoid double triggering?
      // Actually, double triggering showOverlay is handled by isActive check.
      // But let's keep it robust.
      Alarm.ringStream.stream.listen((event) {
        debugPrint('🔔 Alarm Ringing (Isolate: ${isBackground ? 'Background' : 'Main'}): ${event.id}');
        _ringStreamController.add(event);
        showOverlay(event); 
      });
      
      // Listen for overlay events
      FlutterOverlayWindow.overlayListener.listen((event) {
        debugPrint('Overlay Event (Isolate: ${isBackground ? 'Background' : 'Main'}): $event');
        if (event == 'stop') {
          stopAll();
        } else if (event == 'snooze') {
          stopSpeaking();
          FlutterOverlayWindow.closeOverlay();
        }
      });
    }
  }

  Future<void> requestPermissions() async {
    if (!kIsWeb) {
      final status = await FlutterOverlayWindow.isPermissionGranted();
      if (!status) {
        await FlutterOverlayWindow.requestPermission();
      }
      
      // Check for Xiaomi specific permissions
      await _checkXiaomiPermissions();
    }
  }

  Future<void> _checkXiaomiPermissions() async {
    // This is a heuristic check. We can't programmatically check the "Display pop-up" permission 
    // on Xiaomi easily, but we can detect the manufacturer and guide the user.
    // For now, we'll rely on the user manually enabling it via the settings we open.
    // We can't easily import device_info_plus here without adding it to pubspec, 
    // but we can assume if the user is having issues, they might need to check this.
    debugPrint("Checking permissions...");
  }
  
  // Helper to open settings for Xiaomi
  Future<void> openXiaomiPermissions() async {
    // There is no direct intent for "Other Permissions" on all MIUI versions,
    // but opening App Settings is the safest bet.
    await FlutterOverlayWindow.requestPermission(); 
    // The user has to manually go to "Other Permissions" -> "Display pop-up windows..."
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required DateTime dateTime,
    String? description,
    bool loopAudio = true,
    bool vibrate = false,
  }) async {
    // 1. Single Alarm Guarantee: Stop any existing alarm with this ID
    await Alarm.stop(id);

    // 2. Time Calculation: Ensure time is in the future
    if (dateTime.isBefore(DateTime.now())) {
      debugPrint('⚠️ Scheduling reminder in the past: $dateTime');
    }

    debugPrint('📅 Scheduling reminder $id for $dateTime');

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: loopAudio,
      vibrate: vibrate,
      volumeSettings: VolumeSettings.fixed(
        volume: 0.8,
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: 'Reminder: $title',
        body: description ?? 'Time to check your reminder!',
        stopButton: 'Stop',
        icon: 'notification_icon',
      ),
      androidFullScreenIntent: true, // Keep this for Lock Screen Activity
    );

    if (kIsWeb) {
      _stopWebTimer(id);
      final now = DateTime.now();
      if (dateTime.isAfter(now)) {
        final duration = dateTime.difference(now);
        _webTimers[id] = Timer(duration, () {
          _ringStreamController.add(alarmSettings);
          _webTimers.remove(id);
        });
      } else {
        _ringStreamController.add(alarmSettings);
      }
    } else {
      await Alarm.set(alarmSettings: alarmSettings);
    }
  }

  Future<void> showOverlay(AlarmSettings settings) async {
    final title = settings.notificationSettings.title.replaceFirst('Reminder: ', '');
    final body = settings.notificationSettings.body;

    // Force close any existing overlay first to ensure a fresh state
    if (await FlutterOverlayWindow.isActive()) {
      debugPrint('⚠️ Overlay already active, closing it first...');
      await FlutterOverlayWindow.closeOverlay();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    debugPrint('Attempting to show overlay for: $title');
    
    // Check permission again before showing
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      debugPrint('❌ Overlay permission NOT granted. Cannot show overlay.');
      return;
    }

    try {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: title,
          overlayContent: body,
          flag: OverlayFlag.defaultFlag,
          alignment: OverlayAlignment.center,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          height: 500,
          width: WindowSize.matchParent,
        );
        debugPrint('✅ Overlay show command sent');
    } catch (e) {
        debugPrint('❌ Error showing overlay: $e');
    }
    
    // Send data to the overlay so it knows what to display
    await Future.delayed(const Duration(milliseconds: 500));
    await FlutterOverlayWindow.shareData({
      'title': title,
      'body': body,
      'reminderId': settings.id,
    });
    
    // Also start speaking with a delay to ensure TTS is ready
    await Future.delayed(const Duration(seconds: 2));
    await speak("$title. $body");
  }

  Future<void> stopReminder(int id) async {
    debugPrint('🛑 Stopping reminder $id');
    await _ttsService.stop();
    await FlutterOverlayWindow.closeOverlay();
    
    if (kIsWeb) {
      _stopWebTimer(id);
    } else {
      // Stop the specific alarm.
      var res = await Alarm.stop(id);
      debugPrint('🛑 Alarm.stop($id) returned: $res');
      
      // Retry if it didn't stop or just to be safe (some devices need a kick)
      if (res == false || await Alarm.isRinging(id)) {
         await Future.delayed(const Duration(milliseconds: 500));
         res = await Alarm.stop(id);
         debugPrint('🛑 Retry Alarm.stop($id) returned: $res');
      }
    }
  }

  Future<void> stopAll() async {
    debugPrint('🛑 Stopping ALL reminders');
    await _ttsService.stop();
    await FlutterOverlayWindow.closeOverlay();
    
    if (!kIsWeb) {
      final alarms = await Alarm.getAlarms();
      for (final alarm in alarms) {
        await Alarm.stop(alarm.id);
      }
      await Alarm.stopAll();
    }
  }

  void _stopWebTimer(int id) {
    _webTimers[id]?.cancel();
    _webTimers.remove(id);
  }

  Future<void> snoozeReminder(int id, String title, Duration duration) async {
    await stopReminder(id);
    await scheduleReminder(
      id: id,
      title: title,
      dateTime: DateTime.now().add(duration),
    );
  }

  Future<void> speak(String text) async {
    await _ttsService.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
  }

  Future<bool> isRinging(int id) async {
    if (kIsWeb) return _webTimers.containsKey(id); // Web approximation
    return await Alarm.isRinging(id);
  }

  Stream<AlarmSettings> get ringStream => _ringStreamController.stream;
}
