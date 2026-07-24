import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/training_summary.dart';

class TrainingProgressionCard extends StatelessWidget {
  final TrainingSummary summary;

  const TrainingProgressionCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final result = summary.progressionResult;
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
          Text('Progression', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          if (result == null)
            Text(
              'No previous progression data.',
              key: const Key('progression-empty'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: secondaryColor),
            )
          else
            Column(
              key: const Key('progression-result'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _resultRow(
                  context,
                  label: 'Last',
                  value:
                      '${_formatWeight(result.lastWeight)}kg ×${result.lastReps}',
                ),
                AppSpacing.gapXS,
                _resultRow(
                  context,
                  label: 'Suggested',
                  value:
                      '${_formatWeight(result.suggestedWeight)}kg '
                      '×${result.suggestedRepsMin}〜${result.suggestedRepsMax}',
                ),
                AppSpacing.gapXS,
                Text(
                  'Reason  ${result.reason}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondaryColor),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _resultRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  String _formatWeight(double weight) {
    return weight == weight.truncateToDouble()
        ? weight.toInt().toString()
        : weight.toString();
  }
}
