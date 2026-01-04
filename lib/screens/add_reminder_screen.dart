import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/reminder_service.dart';

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
              primary: Color(0xFF6A11CB),
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
              primary: Color(0xFF6A11CB),
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
    if (!_formKey.currentState!.validate()) return;

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
            const SnackBar(content: Text('Please select a time in the future')),
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
        'repeat': _repeat == 'Today Only' ? 'None' : _repeat,
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
        // Ensure we handle both _id and id, and default to empty string if missing to avoid crash
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
            SnackBar(content: Text(isEditing ? 'Reminder updated!' : 'Reminder saved successfully!')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Reminder', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFEF4444),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFFFE4E6), // Light Coral / Pink Background
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Title'),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  decoration: _inputDecoration('Enter reminder title'),
                  validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 24),

                _buildLabel('Description (Optional)'),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  decoration: _inputDecoration('Enter description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Date'),
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, color: Color(0xFFEF4444), size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_selectedDate),
                                    style: const TextStyle(color: Color(0xFF1F2937)),
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
                          _buildLabel('Time'),
                          GestureDetector(
                            onTap: () => _selectTime(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, color: Color(0xFFEF4444), size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    _selectedTime.format(context),
                                    style: const TextStyle(color: Color(0xFF1F2937)),
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

                _buildLabel('Repeat'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _repeat,
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFEF4444)),
                      isExpanded: true,
                      items: ['Today Only', 'Daily', 'Weekly', 'Monthly'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(color: Color(0xFF1F2937))),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Vibration',
                      style: TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Vibrate when reminder triggers',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
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
                        : const Text(
                            'SAVE REMINDER',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
    );
  }
}
