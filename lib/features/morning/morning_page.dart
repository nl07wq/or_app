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
      appBar: AppBar(title: const Text('Morning')),
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
                  'Morning Factを同期します。',
            ),

            AppSpacing.gapMD,

            MorningSyncCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.edit_note, title: 'MORNING FACT'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '体重・睡眠・勤務情報など\n'
                  'Morning Factを入力します。',
            ),

            AppSpacing.gapMD,

            MorningManualCard(),

            AppSpacing.gapXL,

            SectionHeader(icon: Icons.history, title: 'HISTORY'),

            AppSpacing.gapSM,

            OperationDescription(
              text:
                  '保存済みのMorning Factを\n'
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
