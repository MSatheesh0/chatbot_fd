import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/reminder_service.dart';
import 'services/settings_service.dart';
import 'screens/reminder_overlay_screen.dart';
import 'screens/reminder_overlay_widget.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Overlay Entry Point
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ReminderOverlayWidget(),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderService().init();
  await SettingsService().init(); // Init settings
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkActiveAlarms();
    ReminderService().ringStream.listen((alarmSettings) {
      _navigateToReminder(alarmSettings);
    });
  }

  // ... existing methods ...
  Future<void> _checkActiveAlarms() async {
    // Permissions are now handled in PermissionSetupScreen after login
    final alarms = await Alarm.getAlarms();
    for (final alarm in alarms) {
      if (await Alarm.isRinging(alarm.id)) {
        _navigateToReminder(alarm);
        break; // Handle one at a time or maybe all? Usually one.
      }
    }
  }

  void _navigateToReminder(AlarmSettings alarmSettings) {
      final title = alarmSettings.notificationSettings.title.replaceFirst('Reminder: ', '');
      final body = alarmSettings.notificationSettings.body;
      
      // Ensure we don't push if already there? 
      // For now, just push.
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ReminderOverlayScreen(
            reminderId: alarmSettings.id,
            title: title,
            description: body,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService().themeMode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsService().textScale,
          builder: (context, textScale, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'ChatBot AI',
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
                brightness: Brightness.light,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple, 
                  brightness: Brightness.dark,
                  surface: const Color(0xFF121212),
                  background: const Color(0xFF121212),
                ),
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF121212),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                ),
                cardColor: const Color(0xFF1E1E1E),
                textTheme: const TextTheme(
                  bodyLarge: TextStyle(color: Colors.white),
                  bodyMedium: TextStyle(color: Colors.white70),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaleFactor: textScale),
                  child: child!,
                );
              },
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
