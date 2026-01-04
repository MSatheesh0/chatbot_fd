import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: const Text(
          '''
Terms and Conditions

1. Introduction
Welcome to ChatBot AI. By using our app, you agree to these terms.

2. Usage
You agree to use the app for lawful purposes only.

3. Medical Disclaimer
This app is not a substitute for professional medical advice. If you are in crisis, please contact emergency services immediately.

4. Privacy
We respect your privacy. Please review our Privacy Policy.

5. Changes
We may update these terms at any time.

Last updated: Jan 2026
          ''',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
