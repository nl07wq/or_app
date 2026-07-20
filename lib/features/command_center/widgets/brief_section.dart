import 'package:flutter/material.dart';

import '../../../core/engine/commander_analysis_snapshot.dart';
import '../../../core/engine/operation_status.dart';
import 'operation_status_card.dart';
import '../../../core/widgets/operation_card.dart';

class BriefSection extends StatelessWidget {
  final CommanderAnalysisSnapshot analysis;

  const BriefSection({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DailyCommandCard(analysis: analysis),
        const SizedBox(height: 16),
        OperationStatusCard(
          status: analysis.status.name.toUpperCase(),
          description: analysis.recoveryAnalysis,
          statusColor: _statusColor(analysis.status),
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

class _DailyCommandCard extends StatelessWidget {
  final CommanderAnalysisSnapshot analysis;

  const _DailyCommandCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAILY COMMAND',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'SITUATION',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(analysis.situation),
          const Divider(height: 24),
          Text(
            'COMMANDER INTENT',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            analysis.commanderIntent,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Divider(height: 24),
          Text(
            'TODAY\'S ACTION',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(analysis.primaryAction),
        ],
      ),
    );
  }
}
