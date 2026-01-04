import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';
import 'settings/faq_screen.dart';
import 'settings/contact_support_screen.dart';
import 'settings/feedback_screen.dart';
import 'settings/terms_screen.dart';
import 'settings/privacy_policy_screen.dart';
import 'settings/data_usage_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
      ),
      body: ValueListenableBuilder(
        valueListenable: _settings.themeMode, // Rebuild on theme change
        builder: (context, theme, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader('General'),
              _buildDropdownTile(
                title: 'App Language',
                icon: Iconsax.language_square,
                value: _settings.locale.value.languageCode == 'es' ? 'Spanish' : 
                       _settings.locale.value.languageCode == 'fr' ? 'French' :
                       _settings.locale.value.languageCode == 'hi' ? 'Hindi' :
                       _settings.locale.value.languageCode == 'de' ? 'German' : 
                       _settings.locale.value.languageCode == 'ta' ? 'Tamil' : 'English',
                items: ['English', 'Spanish', 'French', 'Hindi', 'German', 'Tamil'],
                onChanged: (val) => _settings.updateSetting('language', val),
              ),
              _buildDropdownTile(
                title: 'Time Zone',
                icon: Iconsax.clock,
                value: _settings.timeZone,
                items: ['Auto (UTC+05:30)', 'UTC', 'EST', 'PST'],
                onChanged: (val) => setState(() {
                   _settings.updateSetting('time_zone', val);
                }),
              ),
              _buildDropdownTile(
                title: 'Date Format',
                icon: Iconsax.calendar_1,
                value: _settings.dateFormat,
                items: ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
                onChanged: (val) => setState(() {
                  _settings.updateSetting('date_format', val);
                }),
              ),

              _buildSectionHeader('Appearance'),
              _buildSwitchTile(
                title: 'Dark Mode',
                icon: Iconsax.moon,
                value: _settings.themeMode.value == ThemeMode.dark,
                onChanged: (val) => _settings.updateSetting('is_dark_mode', val),
              ),
              _buildDropdownTile(
                title: 'Font Size',
                icon: Iconsax.text_block,
                value: _settings.textScale.value == 0.85 ? 'Small' : 
                       _settings.textScale.value == 1.15 ? 'Large' : 'Medium',
                items: ['Small', 'Medium', 'Large'],
                onChanged: (val) => _settings.updateSetting('font_size', val),
              ),

              _buildSectionHeader('Audio & AI'),
              _buildSwitchTile(
                title: 'Voice Response',
                icon: Iconsax.voice_square,
                value: _settings.isVoiceEnabled,
                onChanged: (val) => setState(() {
                  _settings.updateSetting('voice_enabled', val);
                }),
              ),
              _buildDropdownTile(
                title: 'Default AI Mode',
                icon: Iconsax.cpu,
                value: _settings.defaultMode,
                items: ['Chat', 'Mental Health', 'Funny', 'Study'],
                onChanged: (val) => setState(() {
                  _settings.updateSetting('default_mode', val);
                }),
              ),

              _buildSectionHeader('Safety'),
              _buildActionTile(
                title: 'Emergency Contact',
                icon: Iconsax.call,
                subtitle: _settings.emergencyContact['name']!.isEmpty 
                    ? 'Not set' 
                    : '${_settings.emergencyContact['name']} (${_settings.emergencyContact['phone']})',
                onTap: _showEmergencyContactDialog,
              ),

              _buildSectionHeader('Support'),
              _buildActionTile(
                title: 'FAQ',
                icon: Iconsax.message_question,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen())),
              ),
              _buildActionTile(
                title: 'Contact Support',
                icon: Iconsax.support,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
              ),
              _buildActionTile(
                title: 'Feedback / Report Problem',
                icon: Iconsax.message_edit,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),

              _buildSectionHeader('Privacy & Data'),
              _buildActionTile(
                title: 'Consent & Data Usage',
                icon: Iconsax.shield_tick,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataUsageScreen())),
              ),
              _buildActionTile(
                title: 'Delete Account',
                icon: Iconsax.trash,
                color: Colors.red,
                onTap: _showDeleteAccountDialog,
              ),

              _buildSectionHeader('About'),
              _buildActionTile(
                title: 'Terms & Conditions',
                icon: Iconsax.document_text,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
              ),
              _buildActionTile(
                title: 'Privacy Policy',
                icon: Iconsax.lock,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
              ),
              _buildActionTile(
                title: 'Licenses',
                icon: Iconsax.copyright,
                onTap: () => showLicensePage(context: context),
              ),
              
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  'App Version 1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 50),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6A11CB),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6A11CB)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFF6A11CB)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        value: value,
        activeColor: const Color(0xFF6A11CB),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    String? subtitle,
    Color color = Colors.black87,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color == Colors.red ? Colors.red : const Color(0xFF6A11CB)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showEmergencyContactDialog() {
    final nameController = TextEditingController(text: _settings.emergencyContact['name']);
    final phoneController = TextEditingController(text: _settings.emergencyContact['phone']);
    final relationController = TextEditingController(text: _settings.emergencyContact['relationship']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                decoration: const InputDecoration(labelText: 'Relationship', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _settings.updateSetting('emergency_contact', {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'relationship': relationController.text,
                });
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be lost.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              try {
                final storage = const FlutterSecureStorage();
                final token = await storage.read(key: 'jwt_token');
                
                final response = await http.delete(
                  Uri.parse(ApiConstants.profileUrl), 
                  headers: {'x-auth-token': token ?? ''},
                );

                if (response.statusCode == 200) {
                   await storage.deleteAll();
                   if (mounted) {
                     Navigator.of(context).pushAndRemoveUntil(
                       MaterialPageRoute(builder: (context) => const LoginScreen()),
                       (route) => false,
                     );
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Account deleted successfully.')),
                     );
                   }
                } else {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Failed to delete account.')),
                     );
                   }
                }
              } catch (e) {
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Error: $e')),
                   );
                 }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
