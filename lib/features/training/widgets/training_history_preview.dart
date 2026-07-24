import 'package:flutter/material.dart';

import '../../../core/models/training_set.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/training_summary.dart';

class TrainingHistoryPreview extends StatelessWidget {
  final TrainingSummary summary;

  const TrainingHistoryPreview({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final sets = summary.historySummary?.sets;
    final text = sets == null || sets.isEmpty
        ? 'No previous record'
        : sets.map(_formatSet).join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Previous',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        AppSpacing.gapXS,
        Text(
          text,
          key: const Key('training-history-preview'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }

  String _formatSet(TrainingSet set) {
    final weight = set.weight == set.weight.truncateToDouble()
        ? set.weight.toInt().toString()
        : set.weight.toString();
    return '${weight}kg × ${set.reps}';
  }
}
