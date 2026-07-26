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
    appBar: AppBar(title: const Text('Activity')),
    body: SingleChildScrollView(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            icon: Icons.directions_walk_outlined,
            title: 'ACTIVITY',
          ),

          AppSpacing.gapSM,

          const OperationDescription(text: '歩数・排便・足底などを入力します。'),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.edit_outlined,
            text: 'Log Activity',
            onPressed: () => _openEntry(context),
          ),

          AppSpacing.gapXL,

          const SectionHeader(icon: Icons.history, title: 'HISTORY'),

          AppSpacing.gapSM,

          const OperationDescription(text: '保存済みActivityを確認できます。'),

          AppSpacing.gapMD,

          OperationButton(
            icon: Icons.history_outlined,
            text: 'Activity History',
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
