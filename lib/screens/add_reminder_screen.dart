import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants.dart';
import '../services/reminder_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class AddReminderScreen extends StatefulWidget {
  final Map<String, dynamic>? reminderToEdit;
  const AddReminderScreen({super.key, this.reminderToEdit});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _repeat = 'Today Only';
  bool _isLoading = false;
  bool _isVibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.reminderToEdit != null) {
      final r = widget.reminderToEdit!;
      _titleController.text = r['message'];
      _descriptionController.text = r['description'] ?? '';
      final dt = DateTime.parse(r['time']);
      _selectedDate = dt;
      _selectedTime = TimeOfDay.fromDateTime(dt);
      _repeat = r['repeat'] == 'None' ? 'Today Only' : (r['repeat'] ?? 'Today Only');
      _isVibrationEnabled = r['vibration'] ?? false;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEF4444),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEF4444),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    // Check and request necessary permissions before saving
    final permissionsGranted = await _checkAndRequestPermissions();
    if (!permissionsGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('permissions_required_reminder')),
            action: SnackBarAction(
              label: l10n.translate('open_settings'),
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'jwt_token');
      final DateTime scheduledTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (scheduledTime.isBefore(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('err_future'))),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final isEditing = widget.reminderToEdit != null;
      String url = ApiConstants.remindersUrl;
      if (isEditing) {
        final id = widget.reminderToEdit!['id'] ?? widget.reminderToEdit!['_id'];
        url = '$url/$id';
      }

      final body = {
        'message': _titleController.text,
        'description': _descriptionController.text,
        'time': scheduledTime.toIso8601String(),
        'repeat': _repeat == l10n.translate('today_only') ? 'None' : _repeat,
        'action': 'wave',
        'vibration': _isVibrationEnabled,
      };

      final response = isEditing
          ? await http.put(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'x-auth-token': token ?? '',
              },
              body: jsonEncode(body),
            )
          : await http.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'x-auth-token': token ?? '',
              },
              body: jsonEncode(body),
            );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final savedReminder = jsonDecode(response.body);
        final String idStr = savedReminder['_id'] ?? savedReminder['id'] ?? '';
        
        if (idStr.isEmpty) {
             throw Exception('Server returned reminder without ID');
        }

        final int alarmId = idStr.hashCode;

        await ReminderService().scheduleReminder(
          id: alarmId,
          title: _titleController.text,
          description: _descriptionController.text,
          dateTime: scheduledTime,
          vibrate: _isVibrationEnabled,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEditing ? l10n.translate('msg_updated') : l10n.translate('msg_saved'))),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to save reminder');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    final l10n = AppLocalizations.of(context);
    
    // List of permissions needed for reminders
    final permissions = [
      Permission.notification,
      Permission.systemAlertWindow,
      Permission.scheduleExactAlarm,
    ];

    bool allGranted = true;

    for (final permission in permissions) {
      var status = await permission.status;
      
      if (!status.isGranted) {
        // Show explanation dialog before requesting
        final shouldRequest = await _showPermissionExplanationDialog(permission);
        
        if (!shouldRequest) {
          allGranted = false;
          continue;
        }

        // Request the permission
        status = await permission.request();
        
        if (!status.isGranted) {
          allGranted = false;
        }
      }
    }

    return allGranted;
  }

  Future<bool> _showPermissionExplanationDialog(Permission permission) async {
    final l10n = AppLocalizations.of(context);
    String title = '';
    String message = '';

    switch (permission) {
      case Permission.notification:
        title = l10n.translate('notif_access');
        message = l10n.translate('notif_desc');
        break;
      case Permission.systemAlertWindow:
        title = l10n.translate('overlay_access');
        message = l10n.translate('overlay_desc');
        break;
      case Permission.scheduleExactAlarm:
        title = l10n.translate('alarm_access');
        message = l10n.translate('alarm_desc');
        break;
      default:
        title = l10n.translate('permission_required');
        message = l10n.translate('permission_desc');
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('skip_for_now')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.translate('allow_access')),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.reminderToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.translate('edit_reminder') : l10n.translate('add_reminder'),
          style: TextStyle(color: isDark ? Colors.white : Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFEF4444),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFFFE4E6),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel(l10n.translate('title')),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937)),
                      decoration: _inputDecoration(l10n.translate('enter_title')),
                      validator: (value) => value!.isEmpty ? l10n.translate('err_title') : null,
                    ),
                    const SizedBox(height: 24),

                    _buildLabel(l10n.translate('description_optional')),
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937)),
                      decoration: _inputDecoration(l10n.translate('enter_desc')),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(l10n.translate('date')),
                              GestureDetector(
                                onTap: () => _selectDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[850] : Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, color: Color(0xFFEF4444), size: 20),
                                      const SizedBox(width: 10),
                                      ValueListenableBuilder(
                                        valueListenable: SettingsService().dateFormat,
                                        builder: (context, dateFormat, _) {
                                          return Text(
                                            SettingsService().formatDate(_selectedDate),
                                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(l10n.translate('time')),
                              GestureDetector(
                                onTap: () => _selectTime(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[850] : Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Color(0xFFEF4444), size: 20),
                                      const SizedBox(width: 10),
                                      ValueListenableBuilder(
                                        valueListenable: SettingsService().timeZone,
                                        builder: (context, timeZone, _) {
                                          return Text(
                                            SettingsService().formatTime(DateTime(
                                              _selectedDate.year,
                                              _selectedDate.month,
                                              _selectedDate.day,
                                              _selectedTime.hour,
                                              _selectedTime.minute,
                                            )),
                                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildLabel(l10n.translate('repeat')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _repeat,
                          dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFEF4444)),
                          isExpanded: true,
                          items: [
                            l10n.translate('today_only'),
                            l10n.translate('daily'),
                            l10n.translate('weekly'),
                            l10n.translate('monthly')
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937))),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _repeat = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          l10n.translate('vibration'),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          l10n.translate('vibrate_desc'),
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                        value: _isVibrationEnabled,
                        onChanged: (bool value) {
                          setState(() {
                            _isVibrationEnabled = value;
                          });
                        },
                        secondary: const Icon(Icons.vibration, color: Color(0xFFEF4444)),
                        activeColor: const Color(0xFFEF4444),
                        activeTrackColor: const Color(0xFFFFE4E6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveReminder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                l10n.translate('save_reminder'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
    );
  }
}
