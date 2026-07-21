import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import 'activity_entry_page.dart';
import 'activity_history_page.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity')),
    body: Padding(
      padding: AppSpacing.cardPadding,
      child: OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(icon: Icons.directions_walk_outlined, title: 'ACTIVITY'),
            AppSpacing.gapMD,
            OperationButton(
              icon: Icons.edit_outlined,
              text: 'Log Activity',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityEntryPage())),
            ),
            AppSpacing.gapMD,
            OperationButton(
              icon: Icons.history_outlined,
              text: 'Activity History',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityHistoryPage())),
            ),
          ],
        ),
      ),
    ),
  );
}
