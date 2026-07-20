import 'package:flutter/material.dart';

import '../../../core/engine/commander_analysis_snapshot.dart';
import '../../../core/engine/operation_status.dart';
import '../models/command_priority.dart';
import '../models/command_state.dart';
import '../models/command_status.dart';
import '../models/commander_message.dart';
import 'argo_comment_card.dart';
import 'brief_section.dart';
import 'module_section.dart';
import 'situation_card.dart';
import 'summary_card.dart';

class CommanderPanel extends StatelessWidget {
  final CommanderAnalysisSnapshot? analysis;

  const CommanderPanel({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final currentAnalysis = analysis;

    if (currentAnalysis == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SituationCard(
            situation: 'Morning Routineを完了するとCommander分析を開始できます。',
          ),
          SummaryCard(summary: 'Morning Factの確認を待っています。'),
        ],
      );
    }

    final commandStatus = _toCommandStatus(currentAnalysis.status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BriefSection(analysis: currentAnalysis),
        const SizedBox(height: 16),
        ModuleSection(
          states: [
            CommandState(
              module: 'NUTRITION',
              status: commandStatus,
              priority: CommandPriority.none,
              message: currentAnalysis.nutritionAnalysis,
            ),
            CommandState(
              module: 'TRAINING',
              status: commandStatus,
              priority: CommandPriority.none,
              message: currentAnalysis.trainingAnalysis,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ArgoCommentCard(
          commanderMessage: CommanderMessage(
            title: 'COMMANDER ANALYSIS',
            message: currentAnalysis.recoveryAnalysis,
            recommendations: currentAnalysis.recommendations,
          ),
        ),
      ],
    );
  }

  CommandStatus _toCommandStatus(OperationStatus status) {
    switch (status) {
      case OperationStatus.green:
        return CommandStatus.ready;
      case OperationStatus.yellow:
        return CommandStatus.caution;
      case OperationStatus.red:
        return CommandStatus.warning;
      case OperationStatus.black:
        return CommandStatus.locked;
    }
  }
}
