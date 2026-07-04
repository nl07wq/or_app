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
      appBar: AppBar(title: const Text('Training')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SectionHeader(icon: Icons.sync, title: 'TRAINING SYNC'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  'トレーニングデータを同期し、\n'
                  '最新の記録を反映します。',
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

            SectionHeader(icon: Icons.history, title: 'HISTORY'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '過去のトレーニング履歴を\n'
                  '確認します。',
            ),

            AppSpacing.gapMD,

            TrainingHistoryButton(),
          ],
        ),
      ),
    );
  }
}
