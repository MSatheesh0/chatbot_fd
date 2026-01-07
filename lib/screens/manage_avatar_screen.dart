import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class ManageAvatarScreen extends StatefulWidget {
  const ManageAvatarScreen({super.key});

  @override
  State<ManageAvatarScreen> createState() => _ManageAvatarScreenState();
}

class _ManageAvatarScreenState extends State<ManageAvatarScreen> {
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
        _fetchAvatars();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('avatar_set_active'))),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('avatar_deleted'))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder(
      valueListenable: SettingsService().locale,
      builder: (context, locale, _) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFE0E7FF),
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              l10n.translate('avatars'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [

                // Avatar Grid
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: isDark ? Colors.blueAccent : const Color(0xFF1565C0),
                          ),
                        )
                      : _avatars.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined,
                                      size: 60, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.translate('no_avatars_found'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: _avatars.length,
                              itemBuilder: (context, index) {
                                final avatar = _avatars[index];
                                final bool isActive = avatar['isActive'] ?? false;

                                return GestureDetector(
                                  onTap: () => _setActiveAvatar(avatar['_id']),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isActive
                                            ? (isDark ? Colors.blueAccent : const Color(0xFF6366F1))
                                            : (isDark ? Colors.grey[800]! : Colors.grey.withOpacity(0.2)),
                                        width: isActive ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Main Content
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // Avatar Image
                                              Container(
                                                width: 90,
                                                height: 90,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                                                ),
                                                child: ClipOval(
                                                  child: Image.network(
                                                    _getThumbnailUrl(avatar['url']),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        Icon(Icons.person,
                                                            size: 50, color: Colors.grey[400]),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              // Avatar Name
                                              Text(
                                                avatar['name'],
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : const Color(0xFF6366F1),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              
                                              // Active Indicator Badge (Text)
                                              if (isActive)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(Icons.check_circle,
                                                          size: 14, color: Colors.green),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        l10n.translate('active'),
                                                        style: const TextStyle(
                                                          color: Colors.green,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Delete Icon (Top Right)
                                        if (!isActive)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => _showDeleteConfirmation(avatar['_id']),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          
                                        // Active Checkmark Badge (Top Right)
                                        if (isActive)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // Bottom Action Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        shadowColor: const Color(0xFFEF5350).withOpacity(0.4),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: Text(
                        l10n.translate('exit'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
      },
    );
  }

  void _showDeleteConfirmation(String avatarId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.translate('delete_avatar'),
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937)),
        ),
        content: Text(
          l10n.translate('delete_avatar_confirm'),
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.translate('cancel'),
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAvatar(avatarId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }
}
