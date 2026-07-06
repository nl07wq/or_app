import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/summary_row.dart';
import '../../../core/widgets/section_header.dart';

class TrainingSessionSummaryCard extends StatelessWidget {
  final int exerciseCount;
  final int setCount;
  final int totalRep;
  final double totalVolume;

  const TrainingSessionSummaryCard({
    super.key,
    required this.exerciseCount,
    required this.setCount,
    required this.totalRep,
    required this.totalVolume,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.analytics_outlined,
            title: 'SESSION SUMMARY',
          ),

          AppSpacing.gapMD,
          const Divider(),
          AppSpacing.gapMD,

          SummaryRow(title: 'Exercise', value: '$exerciseCount'),

          SummaryRow(title: 'Set', value: '$setCount'),

          SummaryRow(
            title: 'Volume',
            value: '${totalVolume.toStringAsFixed(0)} kg',
          ),

          SummaryRow(title: 'Rep', value: '$totalRep'),
        ],
      ),
    );
  }
}
