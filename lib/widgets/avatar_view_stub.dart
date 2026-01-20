import 'package:flutter/material.dart';

class AvatarView extends StatelessWidget {
  final String avatarUrl;
  final String action;
  final String emotion;
  final double speed;
  final String eyeState;

  const AvatarView({
    super.key,
    required this.avatarUrl,
    this.action = 'idle',
    this.emotion = 'neutral',
    this.speed = 1.0,
    this.eyeState = 'normal',
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Unsupported Platform'));
  }
}
