import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';

class OperationStatusCard extends StatelessWidget {
  final String status;
  final String description;
  final String operationId;
  final Color statusColor;

  const OperationStatusCard({
    super.key,
    required this.status,
    required this.description,
    required this.operationId,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              CircleAvatar(
                radius: 6,
                backgroundColor: statusColor,
              ),

              const SizedBox(width: 8),

              const Text(
                "OPERATION STATUS",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),

            ],
          ),

          const SizedBox(height: 16),

          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),

          const Divider(
            color: Colors.white24,
            height: 32,
          ),

          Text(
            operationId,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),

        ],
      ),
    );
  }
}