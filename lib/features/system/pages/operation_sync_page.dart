import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class OperationSyncPage extends StatelessWidget {
  const OperationSyncPage({super.key});

  static const modules = ['STATUS', 'ACTIVITY', 'TRAINING', 'FOOD', 'ARCHIVE'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('OPERATION SYNC')),
    body: ListView(
      key: const ValueKey('operation-sync-content'),
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(icon: Icons.sync_alt, title: 'OPERATION SYNC'),
        AppSpacing.gapSM,
        const Text('This feature transfers data\nbetween devices.'),
        AppSpacing.gapMD,
        OperationCard(
          child: Column(
            children: [
              for (final module in modules)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle_outlined),
                  title: Text(module),
                  trailing: const Text('COMING LATER'),
                ),
            ],
          ),
        ),
        AppSpacing.gapMD,
        const OperationButton(
          text: 'COMING LATER',
          icon: Icons.schedule_outlined,
          onPressed: null,
        ),
      ],
    ),
  );
}
