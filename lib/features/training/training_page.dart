import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';

import 'widgets/training_history_button.dart';
import 'widgets/training_manual_card.dart';
import 'widgets/training_sync_card.dart';

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
          children: const [
            SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  'Operation Reboot Reportから\n'
                  '本日のトレーニング記録を同期します。',
            ),

            AppSpacing.gapMD,

            TrainingSyncCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.fitness_center, title: 'MANUAL ENTRY'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '本日のトレーニング内容を\n'
                  '手動で記録します。',
            ),

            AppSpacing.gapMD,

            TrainingManualCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.history, title: 'RECORD'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '過去のトレーニング履歴を\n'
                  '確認・編集できます。',
            ),

            AppSpacing.gapMD,

            TrainingHistoryButton(),
          ],
        ),
      ),
    );
  }
}
