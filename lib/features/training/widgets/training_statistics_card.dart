import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/statistics_result.dart';
import 'training_metric_format.dart';

class TrainingStatisticsCard extends StatelessWidget {
  final StatisticsResult result;

  const TrainingStatisticsCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
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
          Text('Statistics', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          _metricRow(
            context,
            label: 'Volume',
            value:
                '${formatTrainingNumberWithThousands(result.totalVolume)} kg',
          ),
          AppSpacing.gapXS,
          _metricRow(
            context,
            label: 'Working Sets',
            value: '${result.workingSets}',
          ),
          AppSpacing.gapXS,
          _metricRow(
            context,
            label: 'Total Reps',
            value: '${result.totalRepetitions}',
          ),
          AppSpacing.gapXS,
          _metricRow(
            context,
            label: 'Average Weight',
            value: '${formatTrainingNumber(result.averageWeight)} kg',
          ),
          AppSpacing.gapXS,
          _metricRow(
            context,
            label: 'Heaviest',
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
