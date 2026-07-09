import 'package:flutter/material.dart';

import '../models/morning_brief.dart';

import 'situation_card.dart';
import 'summary_card.dart';
import 'operation_status_card.dart';
import 'commander_intent_card.dart';
import 'operation_action_card.dart';
import 'warning_chip.dart';
import '../extensions/command_status_extension.dart';

class BriefSection extends StatelessWidget {
  final MorningBrief brief;

  const BriefSection({super.key, required this.brief});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SituationCard(situation: brief.situation),

        SummaryCard(summary: brief.summary),

        if (brief.commanderWarnings.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brief.commanderWarnings
                .map((e) => WarningChip(warning: e))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],

        OperationStatusCard(
          status: brief.operationStatus.label,
          description: brief.operationStatus.description,
          operationId: brief.operationId,
          statusColor: brief.operationStatus.color,
        ),

        CommanderIntentCard(intent: brief.commanderIntent),

        OperationActionCard(
          action: brief.actions.isEmpty ? null : brief.actions.first,
        ),
      ],
    );
  }
}
