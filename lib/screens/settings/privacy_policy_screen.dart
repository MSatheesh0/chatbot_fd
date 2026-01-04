import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: const Text(
          '''
Privacy Policy

1. Data Collection
We collect personal information you provide, such as name, email, and health data.

2. Data Usage
We use your data to provide AI companion services and reminders.

3. Data Sharing
We do not sell your data. We may share data with service providers who help us operate the app.

4. Security
We implement security measures to protect your data.

5. Your Rights
You can access, correct, or delete your data at any time via Settings.

Last updated: Jan 2026
          ''',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
