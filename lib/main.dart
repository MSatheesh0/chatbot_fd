import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/reminder_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/settings_service.dart';
import 'screens/reminder_overlay_screen.dart';
import 'screens/reminder_overlay_widget.dart';
import 'screens/splash_screen.dart';
import 'services/localization_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
  await dotenv.load(fileName: ".env");
  
  // Initialize Stripe
  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  await ReminderService().init();
  await NotificationService().init();
  await initializeBackgroundService(); // Start background service
  await SettingsService().init(); // Init settings
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Set<int> _activeReminderIds = {};

  @override
  void initState() {
    super.initState();
  }

  // ... existing methods ...


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService().themeMode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsService().textScale,
          builder: (context, textScale, _) {
            return ValueListenableBuilder<Locale>(
              valueListenable: SettingsService().locale,
              builder: (context, locale, _) {
                return MaterialApp(
                  navigatorKey: navigatorKey,
                  title: 'ChatBot AI',
                  debugShowCheckedModeBanner: false,
                  themeMode: themeMode,
                  locale: locale,
                  localizationsDelegates: [
                    AppLocalizationsDelegate(locale),
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en'),
                    Locale('es'),
                    Locale('fr'),
                    Locale('hi'),
                    Locale('de'),
                    Locale('ta'),
                  ],
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
                      onSurface: Colors.white,
                      onBackground: Colors.white,
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
                      bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
                      bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
                      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      },
    );
  }
}
