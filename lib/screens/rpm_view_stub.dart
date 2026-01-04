import 'package:flutter/material.dart';

class RpmView extends StatelessWidget {
  final Function(String) onAvatarExported;

  const RpmView({super.key, required this.onAvatarExported});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Unsupported Platform'));
  }
}
