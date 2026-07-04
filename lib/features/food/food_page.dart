import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';

import 'widgets/food_history_button.dart';
import 'widgets/food_manual_card.dart';
import 'widgets/food_sync_card.dart';

class FoodPage extends StatelessWidget {
  const FoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  'Operation Reboot Reportから\n'
                  '本日の食事データを同期します。',
            ),

            AppSpacing.gapMD,

            FoodSyncCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.edit_note, title: 'MANUAL ENTRY'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '食品を検索または手入力して\n'
                  '食事を記録します。',
            ),

            AppSpacing.gapMD,

            FoodManualCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.history, title: 'HISTORY'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '登録済みの食事履歴を\n'
                  '確認・編集できます。',
            ),

            AppSpacing.gapMD,

            FoodHistoryButton(),
          ],
        ),
      ),
    );
  }
}
