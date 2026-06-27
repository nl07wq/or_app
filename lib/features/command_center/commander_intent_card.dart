import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';

class CommanderIntentCard extends StatelessWidget {
  final String intent;

  const CommanderIntentCard({
    super.key,
    required this.intent,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "COMMANDER INTENT",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),

          SizedBox(height: 8),

          Text(
            intent,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}