import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';

class TrainingSummaryCard extends StatelessWidget {
  final String date;
  final String memo;
  final int exerciseCount;
  final int setCount;
  final double totalVolume;

  const TrainingSummaryCard({
    super.key,
    required this.date,
    required this.memo,
    required this.exerciseCount,
    required this.setCount,
    required this.totalVolume,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: Theme.of(context).textTheme.titleLarge),

          if (memo.isNotEmpty) ...[
            AppSpacing.gapSM,
            Text(memo, style: Theme.of(context).textTheme.bodyMedium),
          ],

          AppSpacing.gapLG,

          Text('Exercise : $exerciseCount'),

          Text('Set : $setCount'),

          Text('Volume : ${totalVolume.toStringAsFixed(0)} kg'),
        ],
      ),
    );
  }
}
