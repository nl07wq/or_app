import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/training_summary.dart';
import 'training_metric_format.dart';

class TrainingStatisticsCard extends StatelessWidget {
  final TrainingSummary summary;

  const TrainingStatisticsCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final result = summary.statisticsResult;
    final heaviestSet = result.heaviestSet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATISTICS', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          _metricRow(
            context,
            label: '総重量',
            value:
                '${formatTrainingNumberWithThousands(result.totalVolume)} kg',
          ),
          AppSpacing.gapXS,
          _metricRow(context, label: 'セット数', value: '${result.workingSets}'),
          AppSpacing.gapXS,
          _metricRow(
            context,
            label: '総レップ数',
            value: '${result.totalRepetitions}',
          ),
          AppSpacing.gapXS,
          _metricRow(
            context,
            label: '平均重量',
            value: '${formatTrainingNumber(result.averageWeight)} kg',
          ),
          AppSpacing.gapXS,
          _metricRow(
            context,
            label: '最高重量',
            value: heaviestSet == null
                ? '—'
                : '${formatTrainingNumber(heaviestSet.weight)} kg '
                      '×${heaviestSet.reps}',
          ),
        ],
      ),
    );
  }

  Widget _metricRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
