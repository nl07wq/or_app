import 'package:flutter/material.dart';

import '../models/command_status.dart';

class OperationStatusBadge extends StatelessWidget {
  final CommandStatus status;

  const OperationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    switch (status) {
      case CommandStatus.complete:
        color = Colors.blue;
        label = 'COMPLETE';
        break;

      case CommandStatus.ready:
        color = Colors.green;
        label = 'READY';
        break;

      case CommandStatus.caution:
        color = Colors.yellow;
        label = 'CAUTION';
        break;

      case CommandStatus.warning:
        color = Colors.orange;
        label = 'WARNING';
        break;

      case CommandStatus.locked:
        color = Colors.red;
        label = 'LOCKED';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
