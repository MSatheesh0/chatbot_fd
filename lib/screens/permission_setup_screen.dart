import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iconsax/iconsax.dart';
import 'home_screen.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Microphone Access',
      'description': 'We need microphone access so your Avatar Companion can listen and respond to you.',
      'icon': Iconsax.microphone,
      'permission': Permission.microphone,
      'isCritical': true,
    },
    {
      'title': 'Notifications',
      'description': 'Enable notifications to receive important reminders and alerts from your companion.',
      'icon': Iconsax.notification,
      'permission': Permission.notification,
      'isCritical': true,
    },
    {
      'title': 'Display Over Apps',
      'description': 'Allow the Avatar to appear over other apps when a reminder triggers, even on the lock screen.',
      'icon': Iconsax.mobile,
      'permission': Permission.systemAlertWindow,
      'isCritical': true,
    },
    {
      'title': 'Battery Optimization',
      'description': 'To ensure reminders ring on time, please allow the app to run in the background without restrictions.',
      'icon': Iconsax.battery_charging,
      'permission': Permission.ignoreBatteryOptimizations,
      'isCritical': true,
    },
    {
      'title': 'Location Access',
      'description': 'Optional: We use your location to help you find nearby doctors and services.',
      'icon': Iconsax.location,
      'permission': Permission.location,
      'isCritical': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkCurrentPermission();
  }

  Future<void> _checkCurrentPermission() async {
    if (_currentStep >= _steps.length) {
      _finishSetup();
      return;
    }

    final step = _steps[_currentStep];
    final permission = step['permission'] as Permission;

    if (await permission.isGranted) {
      setState(() {
        _currentStep++;
      });
      _checkCurrentPermission();
    }
  }

  Future<void> _requestPermission() async {
    final step = _steps[_currentStep];
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
    if (_currentStep < _steps.length - 1) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('This feature requires permission to function. Please enable it in app settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextStep(); // Skip for now
            },
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep >= _steps.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final step = _steps[_currentStep];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step['icon'],
                  size: 60,
                  color: const Color(0xFF6A11CB),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                step['title'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                step['description'],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
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
                          ? const Color(0xFF6A11CB)
                          : Colors.grey.shade300,
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
                    backgroundColor: const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Allow Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _nextStep,
                child: Text(
                  step['isCritical'] ? 'Skip for now' : 'No thanks',
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
      ),
    );
  }
}
