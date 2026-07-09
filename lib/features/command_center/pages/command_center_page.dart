import 'package:flutter/material.dart';

import '../extensions/command_status_extension.dart';
import '../models/morning_fact.dart';

import '../widgets/situation_card.dart';
import '../widgets/summary_card.dart';
import '../widgets/operation_status_card.dart';
import '../widgets/commander_intent_card.dart';
import '../widgets/operation_action_card.dart';
import '../services/morning_brief_service.dart';

class CommandCenterPage extends StatelessWidget {
  const CommandCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    const fact = MorningFact(
      weight: 106.0,
      sleepMinutes: 420,
      fatigue: 2,
      plantarPain: 1,
    );

    final brief = const MorningBriefService().build(fact);

    return Scaffold(
      appBar: AppBar(title: const Text('Commander Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SituationCard(situation: brief.situation),

          SummaryCard(summary: brief.summary),

          OperationStatusCard(
            status: brief.operationStatus.label,
            description: brief.operationStatus.description,
            operationId: 'MB-DEBUG',
            statusColor: brief.operationStatus.color,
          ),

          CommanderIntentCard(intent: brief.commanderIntent),

          OperationActionCard(
            action: brief.actions.isEmpty ? null : brief.actions.first,
          ),
        ],
      ),
    );
  }
}
