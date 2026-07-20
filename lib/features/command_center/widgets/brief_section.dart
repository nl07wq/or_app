import 'package:flutter/material.dart';

import '../../../core/engine/commander_analysis_snapshot.dart';
import '../../../core/engine/operation_status.dart';
import 'commander_intent_card.dart';
import 'operation_action_card.dart';
import 'operation_status_card.dart';
import 'situation_card.dart';
import 'summary_card.dart';

class BriefSection extends StatelessWidget {
  final CommanderAnalysisSnapshot analysis;

  const BriefSection({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SituationCard(situation: analysis.overview),
        SummaryCard(summary: analysis.recoveryAnalysis),
        OperationStatusCard(
          status: analysis.status.name.toUpperCase(),
          description: analysis.recoveryAnalysis,
          operationId: 'OPERATION ENGINE',
          statusColor: _statusColor(analysis.status),
        ),
        CommanderIntentCard(intent: analysis.overview),
        OperationActionCard(
          action: analysis.recommendations.isEmpty
              ? null
              : analysis.recommendations.first,
        ),
      ],
    );
  }

  Color _statusColor(OperationStatus status) {
    switch (status) {
      case OperationStatus.green:
        return Colors.green;
      case OperationStatus.yellow:
        return Colors.yellow;
      case OperationStatus.red:
        return Colors.red;
      case OperationStatus.black:
        return Colors.black;
    }
  }
}
