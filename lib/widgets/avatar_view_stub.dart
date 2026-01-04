import 'package:flutter/material.dart';

class AvatarView extends StatelessWidget {
  final String avatarUrl;
  final String action;
  final String emotion;

  const AvatarView({
    super.key,
    required this.avatarUrl,
    this.action = 'idle',
    this.emotion = 'neutral',
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Unsupported Platform'));
  }
}
