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

  Future<void> init() async {
    if (!kIsWeb) {
      await Alarm.init();
      Alarm.ringStream.stream.listen((event) {
        debugPrint('🔔 Alarm Ringing: ${event.id} at ${event.dateTime}');
        _ringStreamController.add(event);
        showOverlay(event); // Show overlay when alarm rings
      });
      
      // Request overlay permissions
      final status = await FlutterOverlayWindow.isPermissionGranted();
      if (!status) {
        await FlutterOverlayWindow.requestPermission();
      }
      
      // Listen for overlay events (Stop/Snooze from the overlay UI)
      FlutterOverlayWindow.overlayListener.listen((event) {
        debugPrint('Overlay Event: $event');
        if (event == 'stop') {
          stopAll();
        } else if (event == 'snooze') {
          stopSpeaking();
          FlutterOverlayWindow.closeOverlay();
          // Logic to reschedule would go here
        }
      });
    }
    await _ttsService.init();
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
    final title = settings.notificationSettings.title;
    final body = settings.notificationSettings.body;

    if (await FlutterOverlayWindow.isActive()) return;

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
    
    // Also start speaking
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
    if (!kIsWeb) {
      await Alarm.stopAll();
    }
    await _ttsService.stop();
    await FlutterOverlayWindow.closeOverlay();
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
