import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/personal_record_result.dart';
import '../models/training_summary.dart';
import 'training_metric_format.dart';

class TrainingPersonalRecordCard extends StatelessWidget {
  final TrainingSummary summary;

  const TrainingPersonalRecordCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final record = summary.personalRecordResult;
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
          Text(
            'Personal Record',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          AppSpacing.gapSM,
          if (record == null)
            Text(
              'No previous personal records.',
              key: const Key('personal-record-empty'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: secondaryColor),
            )
          else
            _recordRow(context, record),
        ],
      ),
    );
  }

  Widget _recordRow(BuildContext context, PersonalRecordResult record) {
    final status = record.status == PersonalRecordStatus.newRecord
        ? 'New PR'
        : 'Current PR';
    return Row(
      key: const Key('personal-record-result'),
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(status, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${formatTrainingNumber(record.highestWeight)} kg '
            '×${record.highestRepetitions}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
