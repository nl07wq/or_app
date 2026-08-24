import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../training_analysis/pages/training_analysis_page.dart';

import 'widgets/training_history_button.dart';
import 'widgets/training_manual_card.dart';
import 'widgets/training_sync_card.dart';
import 'training_plan_import_page.dart';

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TRAINING')),
      body: SingleChildScrollView(
        padding: MediaQuery.sizeOf(context).width < 360
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 16)
            : AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  'Operation Reboot Reportから\n'
                  '本日のトレーニング記録を同期します。',
            ),

            AppSpacing.gapMD,

            const TrainingSyncCard(),

            AppSpacing.gapXL,

            const SectionHeader(icon: Icons.event_note_outlined, title: 'PLAN'),

            AppSpacing.gapSM,

            const OperationDescription(
              text: 'Formal Training Factから次回Training Planを作成します。',
            ),

            AppSpacing.gapMD,

            OperationCard(
              child: OperationButton(
                icon: Icons.event_note_outlined,
                text: 'TRAINING PLAN',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TrainingPlanImportPage(),
                  ),
                ),
              ),
            ),

            AppSpacing.gapXL,

            const SectionHeader(
              icon: Icons.fitness_center,
              title: 'MANUAL ENTRY',
            ),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  '本日のトレーニング内容を\n'
                  '手動で記録します。',
            ),

            AppSpacing.gapMD,

            const TrainingManualCard(),

            AppSpacing.gapXL,

            const SectionHeader(icon: Icons.history, title: 'RECORD'),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  '過去のトレーニング履歴を\n'
                  '確認・編集できます。',
            ),

            AppSpacing.gapMD,

            const TrainingHistoryButton(),

            AppSpacing.gapXL,

            const SectionHeader(
              icon: Icons.analytics_outlined,
              title: 'ANALYSIS REPORT',
            ),

            AppSpacing.gapSM,

            const OperationDescription(
              text: '正式なTraining Recordを選択し、\n分析Reportを作成・閲覧します。',
            ),

            AppSpacing.gapMD,

            OperationCard(
              child: OperationButton(
                icon: Icons.analytics_outlined,
                text: 'TRAINING ANALYSIS REPORT',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TrainingAnalysisPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
