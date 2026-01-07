import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'reminder_service.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  // Initialize Alarm
  await Alarm.init();
  
  // Initialize ReminderService (for TTS and Overlay logic)
  final reminderService = ReminderService();
  await reminderService.init(isBackground: true);

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Listen to Alarm Rings in Background
  Alarm.ringStream.stream.listen((alarmSettings) async {
    debugPrint("Background Service: Alarm Ringing - ${alarmSettings.id}");
    
    // Trigger Overlay
    await reminderService.showOverlay(alarmSettings);
  });
  
  // Listen to Overlay Events (Stop/Snooze)
  FlutterOverlayWindow.overlayListener.listen((event) async {
      debugPrint("Background Service: Overlay Event - $event");
      if (event == 'stop') {
          await reminderService.stopAll();
      } else if (event == 'snooze') {
          await reminderService.stopSpeaking();
          await FlutterOverlayWindow.closeOverlay();
      }
  });
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.shortService],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  
  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
