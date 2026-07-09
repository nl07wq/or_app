import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';

class ModuleStatusCard extends StatelessWidget {
  final String module;
  final String message;
  final Color color;

  const ModuleStatusCard({
    super.key,
    required this.module,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Row(
        children: [
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
