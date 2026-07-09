import 'package:flutter/material.dart';

import '../extensions/command_status_extension.dart';
import '../models/command_status.dart';

class OperationStatusBadge extends StatelessWidget {
  final CommandStatus status;

  const OperationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: status.color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
