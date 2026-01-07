import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';
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
    return ValueListenableBuilder(
      valueListenable: _settings.locale,
      builder: (context, locale, _) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFFEF3C7),
          appBar: AppBar(
            title: Text(
              l10n.translate('settings'),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : const Color(0xFFD97706),
            elevation: 0,
            iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white),
          ),
          body: ValueListenableBuilder(
            valueListenable: _settings.timeZone,
            builder: (context, timeZone, _) {
              return ValueListenableBuilder(
                valueListenable: _settings.dateFormat,
                builder: (context, dateFormat, _) {
                  return ValueListenableBuilder(
                    valueListenable: _settings.themeMode,
                    builder: (context, theme, _) {
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildSectionHeader(l10n.translate('general')),
                          _buildDropdownTile(
                            title: l10n.translate('app_language'),
                            icon: Iconsax.language_square,
                            value: locale.languageCode == 'es' ? 'Spanish' : 
                                   locale.languageCode == 'fr' ? 'French' :
                                   locale.languageCode == 'hi' ? 'Hindi' :
                                   locale.languageCode == 'de' ? 'German' : 
                                   locale.languageCode == 'ta' ? 'Tamil' : 'English',
                            items: ['English', 'Spanish', 'French', 'Hindi', 'German', 'Tamil'],
                            onChanged: (val) => _settings.updateSetting('language', val),
                          ),
                          _buildDropdownTile(
                            title: l10n.translate('time_zone'),
                            icon: Iconsax.clock,
                            value: timeZone,
                            items: ['Auto (UTC+05:30)', 'UTC', 'EST', 'PST'],
                            onChanged: (val) => _settings.updateSetting('time_zone', val),
                          ),
                          _buildDropdownTile(
                            title: l10n.translate('date_format'),
                            icon: Iconsax.calendar_1,
                            value: dateFormat,
                            items: ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
                            onChanged: (val) => _settings.updateSetting('date_format', val),
                          ),

                          _buildSectionHeader(l10n.translate('appearance')),
                          _buildSwitchTile(
                            title: l10n.translate('dark_mode'),
                            icon: Iconsax.moon,
                            value: theme == ThemeMode.dark,
                            onChanged: (val) => _settings.updateSetting('is_dark_mode', val),
                          ),
                          _buildDropdownTile(
                            title: l10n.translate('font_size'),
                            icon: Iconsax.text_block,
                            value: _settings.textScale.value == 0.85 ? 'Small' : 
                                   _settings.textScale.value == 1.15 ? 'Large' : 'Medium',
                            items: ['Small', 'Medium', 'Large'],
                            onChanged: (val) => _settings.updateSetting('font_size', val),
                          ),

                          _buildSectionHeader(l10n.translate('audio_ai')),
                          _buildSwitchTile(
                            title: l10n.translate('voice_response'),
                            icon: Iconsax.voice_square,
                            value: _settings.isVoiceEnabled,
                            onChanged: (val) => setState(() {
                              _settings.updateSetting('voice_enabled', val);
                            }),
                          ),
                          _buildDropdownTile(
                            title: l10n.translate('default_ai_mode'),
                            icon: Iconsax.cpu,
                            value: _settings.defaultMode,
                            items: ['Chat', 'Mental Health', 'Funny', 'Study'],
                            onChanged: (val) => setState(() {
                              _settings.updateSetting('default_mode', val);
                            }),
                          ),

                          _buildSectionHeader(l10n.translate('safety')),
                          _buildActionTile(
                            title: l10n.translate('emergency_contact'),
                            icon: Iconsax.call,
                            subtitle: _settings.emergencyContact['name']!.isEmpty 
                                ? l10n.translate('not_set') 
                                : '${_settings.emergencyContact['name']} (${_settings.emergencyContact['phone']})',
                            onTap: _showEmergencyContactDialog,
                          ),

                          _buildSectionHeader(l10n.translate('support')),
                          _buildActionTile(
                            title: l10n.translate('faq'),
                            icon: Iconsax.message_question,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen())),
                          ),
                          _buildActionTile(
                            title: l10n.translate('contact_support'),
                            icon: Iconsax.support,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
                          ),
                          _buildActionTile(
                            title: l10n.translate('feedback'),
                            icon: Iconsax.message_edit,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                          ),

                          _buildSectionHeader(l10n.translate('privacy_data')),
                          _buildActionTile(
                            title: l10n.translate('consent_data'),
                            icon: Iconsax.shield_tick,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataUsageScreen())),
                          ),
                          _buildActionTile(
                            title: l10n.translate('delete_account'),
                            icon: Iconsax.trash,
                            color: Colors.red,
                            onTap: _showDeleteAccountDialog,
                          ),
                          _buildActionTile(
                            title: 'Logout',
                            icon: Iconsax.logout,
                            color: Colors.red,
                            onTap: () async {
                              final storage = const FlutterSecureStorage();
                              await storage.deleteAll();
                              if (mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
                          ),

                          _buildSectionHeader(l10n.translate('about')),
                          _buildActionTile(
                            title: l10n.translate('terms'),
                            icon: Iconsax.document_text,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                          ),
                          _buildActionTile(
                            title: l10n.translate('privacy_policy'),
                            icon: Iconsax.lock,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                          ),
                          _buildActionTile(
                            title: l10n.translate('licenses'),
                            icon: Iconsax.copyright,
                            onTap: () => showLicensePage(context: context),
                          ),
                          
                          const SizedBox(height: 30),
                          Center(
                            child: Text(
                              '${l10n.translate('app_version')} 1.0.0',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFD97706),
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
        leading: Icon(icon, color: const Color(0xFFD97706)),
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
        secondary: Icon(icon, color: const Color(0xFFD97706)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        value: value,
        activeColor: const Color(0xFFD97706),
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
        leading: Icon(icon, color: color == Colors.red ? Colors.red : const Color(0xFFD97706)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showEmergencyContactDialog() {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: _settings.emergencyContact['name']);
    final phoneController = TextEditingController(text: _settings.emergencyContact['phone']);
    final relationController = TextEditingController(text: _settings.emergencyContact['relationship']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('emergency_contact')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.translate('name'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: l10n.translate('phone_number'), border: const OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                decoration: InputDecoration(labelText: l10n.translate('relationship'), border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.translate('cancel'))),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_account'), style: const TextStyle(color: Colors.red)),
        content: Text(l10n.translate('delete_account_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.translate('cancel'))),
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
                       SnackBar(content: Text(l10n.translate('account_deleted'))),
                     );
                   }
                } else {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text(l10n.translate('failed_delete_account'))),
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
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }
}
