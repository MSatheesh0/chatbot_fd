import 'package:flutter/material.dart';
import '../widgets/chat_panel.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The ChatPanel already has the dark gradient background and star particles
      body: ChatPanel(
        onClose: () {
          Navigator.of(context).pop();
        },
        onMessageSent: (reply, action, emotion) {
          // No avatar to animate in this standalone chat view
          // But we could add logic here if needed later
        },
        initialMode: 'Mental Health',
        headerColor: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFFDCEEFF),
      ),
    );
  }
}
