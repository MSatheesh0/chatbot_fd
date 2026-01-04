import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import 'home_screen.dart';

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
          'name': 'My New Avatar',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving avatar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Your Avatar',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE8D5FF), // Vibrant Purple background
        foregroundColor: Colors.black, // Dark black text/icons
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF8B5CF6)), // Deep Purple Icon
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            tooltip: 'Close and go to Home',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Use the conditionally imported RpmView
          RpmView(onAvatarExported: _saveAvatar),
          
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6), // Deep Purple
                ),
              ),
            ),
        ],
      ),
    );
  }
}

