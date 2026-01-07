import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../services/reminder_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import 'add_reminder_screen.dart';

class MyRemindersScreen extends StatefulWidget {
  const MyRemindersScreen({super.key});

  @override
  State<MyRemindersScreen> createState() => _MyRemindersScreenState();
}

class _MyRemindersScreenState extends State<MyRemindersScreen> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _reminders = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }

  Future<void> _fetchReminders() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      
      final profileResponse = await http.get(
        Uri.parse(ApiConstants.profileUrl),
        headers: {'x-auth-token': token ?? ''},
      );
      
      if (profileResponse.statusCode != 200) throw Exception('Failed to get user info');
      final userId = jsonDecode(profileResponse.body)['_id'];

      final response = await http.get(
        Uri.parse('${ApiConstants.remindersUrl}/$userId'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _reminders = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load reminders');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching reminders: $e');
    }
  }

  Future<void> _refreshSingleReminder(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.remindersUrl}/single/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final updatedReminder = jsonDecode(response.body);
        setState(() {
          final index = _reminders.indexWhere((r) => r['_id'] == id);
          if (index != -1) {
            _reminders[index] = updatedReminder;
          }
        });
      }
    } catch (e) {
      debugPrint('Error refreshing single reminder: $e');
      // Fallback to full refresh if single refresh fails
      _fetchReminders();
    }
  }

  Future<void> _toggleReminder(String id, bool isActive) async {
    final index = _reminders.indexWhere((r) => r['_id'] == id);
    if (index != -1) {
      setState(() {
        _reminders[index]['isActive'] = isActive;
      });
    }

    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('${ApiConstants.remindersUrl}/$id'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? '',
        },
        body: jsonEncode({'isActive': isActive}),
      );

      if (response.statusCode == 200) {
        final reminder = _reminders[index];
        final int alarmId = id.hashCode;
        if (isActive) {
            final dt = DateTime.parse(reminder['time']);
            if (dt.isAfter(DateTime.now())) {
              await ReminderService().scheduleReminder(
                id: alarmId,
                title: reminder['message'],
                description: reminder['description'],
                dateTime: dt,
                vibrate: reminder['vibration'] ?? false,
              );
            }
        } else {
          await ReminderService().stopReminder(alarmId);
        }
      }

    } catch (e) {
      if (index != -1) {
        setState(() {
          _reminders[index]['isActive'] = !isActive;
        });
      }
      debugPrint('Error toggling reminder: $e');
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConstants.remindersUrl}/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _reminders.removeWhere((r) => r['_id'] == id);
          _selectedIds.remove(id);
          if (_selectedIds.isEmpty) _isSelectionMode = false;
        });
        
        await ReminderService().stopReminder(id.hashCode);

        if (mounted && !_isSelectionMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('reminder_deleted'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  Future<void> _deleteSelectedReminders() async {
    final l10n = AppLocalizations.of(context);
    final count = _selectedIds.length;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_selected')),
        content: Text('${l10n.translate('delete_chat_confirm')} ($count items)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final idsToDelete = List<String>.from(_selectedIds);
      for (final id in idsToDelete) {
        await _deleteReminder(id);
      }
      setState(() {
        _isLoading = false;
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('reminder_deleted'))),
        );
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _reminders.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.clear();
        for (var r in _reminders) {
          _selectedIds.add(r['_id']);
        }
        _isSelectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              }),
            )
          : null,
        title: ValueListenableBuilder(
          valueListenable: SettingsService().locale,
          builder: (context, locale, _) {
            final l10n = AppLocalizations.of(context);
            return Text(
              _isSelectionMode 
                  ? '${_selectedIds.length} ${l10n.translate('items_selected')}'
                  : l10n.translate('reminders'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedIds.length == _reminders.length ? Icons.deselect : Icons.select_all,
                color: isDark ? Colors.white : Colors.white,
              ),
              onPressed: _selectAll,
              tooltip: _selectedIds.length == _reminders.length 
                  ? AppLocalizations.of(context).translate('deselect_all')
                  : AppLocalizations.of(context).translate('select_all'),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedReminders,
              tooltip: AppLocalizations.of(context).translate('delete_selected'),
            ),
          ]
        ],
        backgroundColor: isDark ? Colors.black : const Color(0xFFEF4444),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
        elevation: 0,
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddReminderScreen()),
          );
          // Only fetch reminders if a new one was added
          if (result == true) {
            _fetchReminders();
          }
        },
        backgroundColor: const Color(0xFFEF4444),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          final l10n = AppLocalizations.of(context);
          return Container(
            color: isDark ? const Color(0xFF111827) : const Color(0xFFFFE4E6),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: isDark ? Colors.redAccent : Colors.white))
                : _reminders.isEmpty
                    ? Center(
                        child: Text(
                          l10n.translate('no_reminders_set'),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : ValueListenableBuilder(
                        valueListenable: SettingsService().dateFormat,
                        builder: (context, dateFormat, _) {
                          return ValueListenableBuilder(
                            valueListenable: SettingsService().timeZone,
                            builder: (context, timeZone, _) {
                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _reminders.length,
                                itemBuilder: (context, index) {
                                  final reminder = _reminders[index];
                                  final date = DateTime.parse(reminder['time']);
                                  final formattedTime = SettingsService().formatTime(date);
                                  final formattedDate = SettingsService().formatDate(date);
                                  final bool isActive = reminder['isActive'] ?? true;
                                  final bool isSelected = _selectedIds.contains(reminder['_id']);

                                  return GestureDetector(
                                    onLongPress: () => _toggleSelection(reminder['_id']),
                                    onTap: _isSelectionMode ? () => _toggleSelection(reminder['_id']) : null,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? (isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFFFE4E6))
                                            : (isDark ? const Color(0xFF1F2937) : Colors.white),
                                        borderRadius: BorderRadius.circular(20),
                                        border: isSelected 
                                            ? Border.all(color: const Color(0xFFEF4444), width: 2)
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        leading: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              formattedTime,
                                              style: TextStyle(
                                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                        title: Text(
                                          reminder['message'],
                                          style: TextStyle(
                                            color: isActive 
                                                ? (isDark ? Colors.white : const Color(0xFF1F2937)) 
                                                : (isDark ? Colors.grey[600] : const Color(0xFF9CA3AF)),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            decoration: isActive ? null : TextDecoration.lineThrough,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${l10n.translate('repeat')}: ${reminder['repeat'] != null ? l10n.translate(reminder['repeat'].toString().toLowerCase()) : l10n.translate('none')}',
                                          style: TextStyle(
                                            color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: _isSelectionMode 
                                          ? Checkbox(
                                              value: isSelected,
                                              activeColor: const Color(0xFFEF4444),
                                              onChanged: (val) => _toggleSelection(reminder['_id']),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Switch(
                                                  value: isActive,
                                                  activeColor: const Color(0xFFEF4444),
                                                  onChanged: (val) => _toggleReminder(reminder['_id'], val),
                                                ),
                                                PopupMenuButton<String>(
                                                  icon: Icon(Icons.more_vert, color: isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
                                                  onSelected: (value) async {
                                                    if (value == 'edit') {
                                                       final result = await Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (context) {
                                                            final reminderData = Map<String, dynamic>.from(reminder);
                                                            if (reminderData['id'] == null && reminderData['_id'] != null) {
                                                              reminderData['id'] = reminderData['_id'];
                                                            }
                                                            return AddReminderScreen(reminderToEdit: reminderData);
                                                          },
                                                        ),
                                                      );
                                                      // Only refresh if reminder was actually updated
                                                      if (result == true) {
                                                        // Update only this specific reminder instead of reloading all
                                                        await _refreshSingleReminder(reminder['_id']);
                                                      }
                                                    } else if (value == 'delete') {
                                                      _deleteReminder(reminder['_id']);
                                                    }
                                                  },
                                                  itemBuilder: (BuildContext context) => [
                                                    PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.edit, color: isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
                                                          const SizedBox(width: 8),
                                                          Text(l10n.translate('edit')),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.delete, color: Color(0xFFEF4444)),
                                                          const SizedBox(width: 8),
                                                          Text(l10n.translate('delete')),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
          );
        },
      ),
    );
  }
}
