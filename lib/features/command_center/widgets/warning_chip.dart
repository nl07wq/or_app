import 'package:flutter/material.dart';

import '../models/commander_warning.dart';

class WarningChip extends StatelessWidget {
  final CommanderWarning warning;

  const WarningChip({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(warning.icon, size: 18, color: Colors.white),
      label: Text(warning.title, style: const TextStyle(color: Colors.white)),
      backgroundColor: warning.color,
    );
  }
}
