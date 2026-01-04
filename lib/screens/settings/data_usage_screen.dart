import 'package:flutter/material.dart';
import '../../services/settings_service.dart';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  bool _analyticsConsent = true;
  bool _marketingConsent = false;

  @override
  void initState() {
    super.initState();
    // Ideally load from backend, for now default
  }

  void _updateConsent(String type, bool value) {
    setState(() {
      if (type == 'Analytics') _analyticsConsent = value;
      if (type == 'Marketing') _marketingConsent = value;
    });
    
    SettingsService().logConsent(
      type,
      '1.0',
      value ? 'Accepted' : 'Withdrawn',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consent & Data Usage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Data Usage Policy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'We value your privacy. Below you can manage how we use your data. '
            'Some permissions are required for the app to function correctly.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Analytics & Improvements'),
            subtitle: const Text('Allow us to collect anonymous usage data to improve the app.'),
            value: _analyticsConsent,
            activeColor: const Color(0xFF6A11CB),
            onChanged: (val) => _updateConsent('Analytics', val),
          ),
          SwitchListTile(
            title: const Text('Marketing Communications'),
            subtitle: const Text('Receive updates about new features and offers.'),
            value: _marketingConsent,
            activeColor: const Color(0xFF6A11CB),
            onChanged: (val) => _updateConsent('Marketing', val),
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View Consent History'),
            onTap: () {
              // Navigate to history if needed
            },
          ),
        ],
      ),
    );
  }
}
