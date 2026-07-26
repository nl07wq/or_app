import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';

import 'widgets/morning_history_button.dart';
import 'widgets/morning_manual_card.dart';
import 'widgets/morning_sync_card.dart';

class MorningPage extends StatelessWidget {
  const MorningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STATUS')),
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
                  '本日の状態記録を同期します。',
            ),

            AppSpacing.gapMD,

            MorningSyncCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.edit_note, title: 'MANUAL ENTRY'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '体重・睡眠・勤務情報など\n'
                  '本日の状態を記録します。',
            ),

            AppSpacing.gapMD,

            MorningManualCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.history, title: 'RECORD'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '保存済みの状態履歴を\n'
                  '確認できます。',
            ),

            AppSpacing.gapMD,

            MorningHistoryButton(),
          ],
        ),
      ),
    );
  }
}
