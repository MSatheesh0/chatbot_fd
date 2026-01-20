import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'permission_setup_screen.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Simulate a splash delay
    // await Future.delayed(const Duration(seconds: 1));

    final token = await _storage.read(key: 'jwt_token');

    if (!mounted) return;



    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [Colors.black, const Color(0xFF2D1B4E)] 
                  : [const Color(0xFF9C27B0), const Color(0xFFE040FB)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Avatars Group
                SizedBox(
                  height: 120,
                  width: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Left Avatar (Man)
                      Positioned(
                        left: 0,
                        top: 10,
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.blue[100],
                            backgroundImage: const NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Felix'), // Placeholder
                          ),
                        ),
                      ),
                      // Right Avatar (Blonde Woman)
                      Positioned(
                        right: 0,
                        top: 10,
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.pink[100],
                            backgroundImage: const NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Aneka'), // Placeholder
                          ),
                        ),
                      ),
                      // Center Avatar (Woman with black hair)
                      Positioned(
                        top: 0,
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.green[100],
                            backgroundImage: const NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Bella'), // Placeholder
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Title
                const Text(
                  'Bitmoji',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.0,
                    fontFamily: 'Roboto', // Ensure a clean font
                  ),
                ),
                const SizedBox(height: 12),
                
                // Subtitle
                const Text(
                  'Your Mental Health\nCompanion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                
                const Spacer(),
                
                // Loader
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }
}
