import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iconsax/iconsax.dart';
import 'home_screen.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> {
  int _currentStep = 0;
  final int _totalSteps = 6;

  List<Map<String, dynamic>> _getSteps(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      {
        'title': l10n.translate('mic_access'),
        'description': l10n.translate('mic_desc'),
        'icon': Iconsax.microphone,
        'permission': Permission.microphone,
        'isCritical': true,
      },
      {
        'title': l10n.translate('notif_access'),
        'description': l10n.translate('notif_desc'),
        'icon': Iconsax.notification,
        'permission': Permission.notification,
        'isCritical': true,
      },
      {
        'title': l10n.translate('overlay_access'),
        'description': l10n.translate('overlay_desc'),
        'icon': Iconsax.mobile,
        'permission': Permission.systemAlertWindow,
        'isCritical': true,
      },
      {
        'title': l10n.translate('battery_access'),
        'description': l10n.translate('battery_desc'),
        'icon': Iconsax.battery_charging,
        'permission': Permission.ignoreBatteryOptimizations,
        'isCritical': true,
      },
      {
        'title': l10n.translate('alarm_access'),
        'description': l10n.translate('alarm_desc'),
        'icon': Iconsax.timer,
        'permission': Permission.scheduleExactAlarm,
        'isCritical': true,
      },
      {
        'title': l10n.translate('location_access'),
        'description': l10n.translate('location_desc'),
        'icon': Iconsax.location,
        'permission': Permission.location,
        'isCritical': false,
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _checkCurrentPermission();
  }

  Future<void> _checkCurrentPermission() async {
    if (_currentStep >= _getSteps(context).length) {
      _finishSetup();
      return;
    }

    final step = _getSteps(context)[_currentStep];
    final permission = step['permission'] as Permission;

    if (await permission.isGranted) {
      setState(() {
        _currentStep++;
      });
      _checkCurrentPermission();
    }
  }

  Future<void> _requestPermission() async {
    final step = _getSteps(context)[_currentStep];
    final permission = step['permission'] as Permission;

    // Special handling for system alert window and battery optimizations as they might not return standard results immediately on all devices
    if (permission == Permission.systemAlertWindow) {
      if (await permission.status.isGranted) {
         _nextStep();
         return;
      }
      await permission.request();
      // We can't easily know if they granted it immediately for this specific permission on some android versions
      // So we just move next or check status again.
      if (await permission.status.isGranted) {
        _nextStep();
      } else {
        // If denied, we still move next but maybe show a snackbar?
        // For this flow, we just move next to avoid blocking.
        _nextStep(); 
      }
      return;
    }

    final status = await permission.request();

    if (status.isGranted) {
      _nextStep();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog();
      }
    } else {
      // Denied but not permanently
      // We don't block, just stay or move next?
      // Requirement: "If user denies permission: Do not block the app... Mark permission as pending"
      // We will just move to next step to keep flow smooth.
      _nextStep();
    }
  }

  void _nextStep() {
    if (_currentStep < _getSteps(context).length - 1) {
      setState(() {
        _currentStep++;
      });
      _checkCurrentPermission();
    } else {
      _finishSetup();
    }
  }

  void _finishSetup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _showSettingsDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('permission_required')),
        content: Text(l10n.translate('permission_desc')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextStep(); // Skip for now
            },
            child: Text(l10n.translate('skip')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(l10n.translate('open_settings')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = _getSteps(context);

    if (_currentStep >= steps.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final step = steps[_currentStep];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFEF3C7),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step['icon'],
                      size: 60,
                      color: isDark ? Colors.deepPurpleAccent : const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    step['title'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step['description'],
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  // Progress Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalSteps, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentStep
                              ? (isDark ? Colors.deepPurpleAccent : const Color(0xFFD97706))
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _requestPermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.deepPurpleAccent : const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        l10n.translate('allow_access'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _nextStep,
                    child: Text(
                      step['isCritical'] ? l10n.translate('skip_for_now') : l10n.translate('no_thanks'),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
