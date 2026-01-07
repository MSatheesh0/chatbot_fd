import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import 'create_avatar_screen.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class SelectAvatarScreen extends StatefulWidget {
  const SelectAvatarScreen({super.key});

  @override
  State<SelectAvatarScreen> createState() => _SelectAvatarScreenState();
}

class _SelectAvatarScreenState extends State<SelectAvatarScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _avatars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvatars();
  }

  Future<void> _fetchAvatars() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse(ApiConstants.avatarsUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? '',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _avatars = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load avatars');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('error_fetching_avatars')}: $e')),
        );
      }
    }
  }

  Future<void> _setActiveAvatar(String avatarId) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse(ApiConstants.setActiveAvatarUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? '',
        },
        body: jsonEncode({'avatarId': avatarId}),
      );

      if (response.statusCode == 200) {
        _fetchAvatars(); // Refresh list to show active status
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('avatar_set_active'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('error_setting_active_avatar')}: $e')),
        );
      }
    }
  }

  Future<void> _deleteAvatar(String avatarId) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseAvatarsUrl}/$avatarId'),
        headers: {
          'x-auth-token': token ?? '',
        },
      );

      if (response.statusCode == 200) {
        _fetchAvatars();
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('avatar_deleted'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('error_deleting_avatar')}: $e')),
        );
      }
    }
  }

  String _getThumbnailUrl(String url) {
    if (url.contains('.glb')) {
      return url.replaceAll('.glb', '.png');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('select_avatar')),
        backgroundColor: isDark ? Colors.black : const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : const Color(0xFFE0E7FF),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : Column(
                    children: [
                      Expanded(
                        child: _avatars.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.translate('no_avatars_found'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey, fontSize: 18),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.8,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: _avatars.length,
                                itemBuilder: (context, index) {
                                  final avatar = _avatars[index];
                                  final bool isActive = avatar['isActive'] ?? false;

                                  return Card(
                                    elevation: 8,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: isActive
                                          ? const BorderSide(color: Colors.greenAccent, width: 3)
                                          : BorderSide.none,
                                    ),
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                            child: Image.network(
                                              _getThumbnailUrl(avatar['url']),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.person, size: 80, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            children: [
                                              Text(
                                                avatar['name'],
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      isActive ? Icons.check_circle : Icons.circle_outlined,
                                                      color: isActive ? Colors.greenAccent : Colors.grey,
                                                    ),
                                                    onPressed: () => _setActiveAvatar(avatar['_id']),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                    onPressed: () => _showDeleteConfirmation(avatar['_id']),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const CreateAvatarScreen()),
                              ).then((_) => _fetchAvatars());
                            },
                            icon: const Icon(Icons.add),
                            label: Text(l10n.translate('create_new_avatar'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String avatarId) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_avatar')),
        content: Text(l10n.translate('delete_avatar_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.translate('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAvatar(avatarId);
            },
            child: Text(l10n.translate('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
