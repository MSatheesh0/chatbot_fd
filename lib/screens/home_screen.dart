import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import '../constants.dart';
import 'login_screen.dart';
import 'avatar_companion_home_screen.dart';
import 'user_profile_screen.dart';
import 'my_reminders_screen.dart';
import 'create_avatar_screen.dart';
import 'find_doctors_screen.dart';
import 'chat_history_screen.dart';
import 'manage_avatar_screen.dart';
import 'settings_screen.dart';
import 'ai_chat_screen.dart';
import 'notifications_screen.dart';
import 'analysis_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = const FlutterSecureStorage();
  String _userName = 'User';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse(ApiConstants.profileUrl),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userName = data['username'] ?? 'User';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'userId');

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFF), // Very light background
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)))
          : Column(
              children: [
                // Green Header
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 30,
                    left: 24,
                    right: 24,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF43A047), // Calming Green
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Iconsax.notification, color: Colors.white),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Iconsax.logout, color: Colors.white),
                              onPressed: () => _handleLogout(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: Column(
                      children: [
                        // Grid of Cards
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.85,
                          children: [
                            _buildExactCard(
                              context,
                              'Create Avatar',
                              Iconsax.user_add,
                              const Color(0xFFE8D5FF), // Vibrant Purple
                              const Color(0xFF8B5CF6),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const CreateAvatarScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'Avatar Companion',
                              Iconsax.user_octagon,
                              const Color(0xFFFFD6E8), // Pink
                              const Color(0xFFEC4899),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const AvatarCompanionHomeScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'Profile',
                              Iconsax.user,
                              const Color(0xFFD1FAE5), // Mint Green
                              const Color(0xFF10B981),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'AI Chat',
                              Iconsax.message_text,
                              const Color(0xFFDCEEFF), // Sky Blue
                              const Color(0xFF3B82F6),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const AiChatScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'Manage Avatar',
                              Iconsax.setting_2,
                              const Color(0xFFE0E7FF), // Indigo
                              const Color(0xFF6366F1),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const ManageAvatarScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'Reminder / Alert',
                              Iconsax.notification,
                              const Color(0xFFFFE4E6), // Coral
                              const Color(0xFFEF4444),
                              hasBadge: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const MyRemindersScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'Find Doctor',
                              Iconsax.hospital,
                              const Color(0xFFCFFAFE), // Cyan
                              const Color(0xFF06B6D4),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const FindDoctorsScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'Analysis',
                              Iconsax.chart_2,
                              const Color(0xFFF3E5F5), // Light Purple
                              const Color(0xFF9C27B0),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => AnalysisDashboardScreen()),
                              ),
                            ),
                            _buildExactCard(
                              context,
                              'Settings',
                              Iconsax.setting,
                              const Color(0xFFFEF3C7), // Amber
                              const Color(0xFFD97706),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildExactCard(
    BuildContext context,
    String title,
    IconData icon,
    Color bgColor,
    Color iconColor, {
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(35), // Very rounded corners
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4), // Semi-transparent white circle
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 36,
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF7043),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF455A64), // Dark blue-grey text
              ),
            ),
          ],
        ),
      ),
    );
  }
}



