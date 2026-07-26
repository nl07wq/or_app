import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/services/app_clock.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';
import 'activity_entry_page.dart';
import 'activity_history_page.dart';
import 'repository/activity_repository.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  Future<void> _openEntry(BuildContext context) async {
    final targetDate = AppClock.today();
    final existing = await const LocalActivityRepository().findByDate(
      targetDate,
    );
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ActivityEntryPage(initialData: existing, targetDate: targetDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ACTIVITY')),
    body: SingleChildScrollView(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

          AppSpacing.gapSM,

          const OperationDescription(
            text:
                'Operation Reboot Reportから\n'
                '本日の活動記録を同期します。',
          ),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.sync,
            text: 'SYNC ACTIVITY',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming Soon')));
            },
          ),

          AppSpacing.gapXL,

          const SectionHeader(
            icon: Icons.directions_walk_outlined,
            title: 'MANUAL ENTRY',
          ),

          AppSpacing.gapSM,

          const OperationDescription(
            text:
                '本日の歩数・排便など\n'
                '本日の活動を記録します。',
          ),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.edit_outlined,
            text: 'ACTIVITY ENTRY',
            onPressed: () => _openEntry(context),
          ),

          AppSpacing.gapXL,

          const SectionHeader(icon: Icons.history, title: 'RECORD'),

          AppSpacing.gapSM,

          const OperationDescription(
            text:
                '過去の活動履歴を\n'
                '確認・編集できます。',
          ),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.history_outlined,
            text: 'RECORD',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActivityHistoryPage()),
            ),
          ),
        ],
      ),
    ),
  );
}
