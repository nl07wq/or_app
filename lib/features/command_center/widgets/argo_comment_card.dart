import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../models/commander_message.dart';

class ArgoCommentCard extends StatelessWidget {
  final CommanderMessage commanderMessage;

  const ArgoCommentCard({super.key, required this.commanderMessage});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "ARGO COMMENT",
            style: TextStyle(color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Text(
            commanderMessage.message,
            style: const TextStyle(color: Colors.white, height: 1.5),
          ),
          if (commanderMessage.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            ...commanderMessage.recommendations.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
