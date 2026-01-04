import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  final List<Map<String, String>> faqs = const [
    {
      'question': 'How do I reset my password?',
      'answer': 'Go to the login screen and tap "Forgot Password". Follow the instructions sent to your email.'
    },
    {
      'question': 'Is my data secure?',
      'answer': 'Yes, we use end-to-end encryption for all your chats and personal data.'
    },
    {
      'question': 'Can I use the app offline?',
      'answer': 'Some features like viewing past reminders work offline, but AI chat requires an internet connection.'
    },
    {
      'question': 'How do I change the AI voice?',
      'answer': 'Go to Settings > Audio & AI > Voice Response to toggle voice, or use the Voice Selection screen to pick a new voice.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          return ExpansionTile(
            title: Text(faqs[index]['question']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(faqs[index]['answer']!),
              ),
            ],
          );
        },
      ),
    );
  }
}
