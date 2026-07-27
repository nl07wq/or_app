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
            'PERSONAL RECORD',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          AppSpacing.gapSM,
          _recordRow(context, record),
        ],
      ),
    );
  }

  Widget _recordRow(BuildContext context, PersonalRecordResult? record) {
    return Row(
      key: record == null
          ? const Key('personal-record-empty')
          : const Key('personal-record-result'),
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('自己ベスト', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            record == null
                ? '記録なし'
                : '${formatTrainingNumber(record.highestWeight)} kg '
                      '×${record.highestRepetitions}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: record == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
