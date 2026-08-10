import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class SystemMonitoringPage extends StatelessWidget {
  const SystemMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SYSTEM MONITORING')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: const [
        SectionHeader(
          icon: Icons.monitor_heart_outlined,
          title: 'SYSTEM MONITORING',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('復元履歴とデータ整合性の確認機能を今後追加します。'),
              AppSpacing.gapMD,
              _ComingLaterItem(label: 'IMPORT HISTORY'),
              AppSpacing.gapSM,
              _ComingLaterItem(label: 'CONFLICTS'),
              AppSpacing.gapSM,
              _ComingLaterItem(label: 'QUARANTINE'),
            ],
          ),
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _ComingLaterItem extends StatelessWidget {
  const _ComingLaterItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      );
      if (constraints.maxWidth < 300) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelRow, AppSpacing.gapXS, const Text('COMING LATER')],
        );
      }
      return Row(
        children: [
          Expanded(child: labelRow),
          const SizedBox(width: 8),
          const Text('COMING LATER'),
        ],
      );
    },
  );
}
