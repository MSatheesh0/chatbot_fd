import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import 'home_screen.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

// Conditional Import
import 'rpm_view_stub.dart'
    if (dart.library.io) 'rpm_view_mobile.dart'
    if (dart.library.html) 'rpm_view_web.dart';

class CreateAvatarScreen extends StatefulWidget {
  const CreateAvatarScreen({super.key});

  @override
  State<CreateAvatarScreen> createState() => _CreateAvatarScreenState();
}

class _CreateAvatarScreenState extends State<CreateAvatarScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isSaving = false;

  Future<void> _saveAvatar(String imageUrl) async {
    setState(() => _isSaving = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse(ApiConstants.baseAvatarsUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? '',
        },
        body: jsonEncode({
          'name': AppLocalizations.of(context).translate('my_new_avatar'),
          'url': imageUrl,
          'config': {'source': 'readyplayerme'}
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          // Navigate immediately without confirmation
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        throw Exception('Failed to save avatar');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('error_saving_avatar')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('create_your_avatar'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.white, 
            fontWeight: FontWeight.bold
          ),
        ),
        backgroundColor: isDark ? Colors.black : const Color(0xFF8B5CF6),
        foregroundColor: isDark ? Colors.white : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.white),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            tooltip: l10n.translate('close_and_go_home'),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return Stack(
            children: [
              // Background color container
              Container(color: isDark ? Colors.black : const Color(0xFFE8D5FF)),
              // Use the conditionally imported RpmView
              RpmView(onAvatarExported: _saveAvatar),
              
              if (_isSaving)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

