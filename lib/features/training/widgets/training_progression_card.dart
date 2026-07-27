import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/progression_result.dart';
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
          Text('PROGRESSION', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          if (result == null)
            Column(
              key: const Key('progression-empty'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _resultRow(context, label: '前回', value: '記録なし'),
                AppSpacing.gapXS,
                _resultRow(context, label: '今回', value: '提案なし'),
                AppSpacing.gapXS,
                _resultRow(
                  context,
                  label: '理由',
                  value: '比較できる前回記録がありません',
                  valueColor: secondaryColor,
                ),
              ],
            )
          else
            Column(
              key: const Key('progression-result'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _resultRow(
                  context,
                  label: '前回',
                  value:
                      '${_formatWeight(result.lastWeight)}kg ×${result.lastReps}',
                ),
                AppSpacing.gapXS,
                _resultRow(
                  context,
                  label: '今回',
                  value:
                      '${_formatWeight(result.suggestedWeight)}kg '
                      '×${result.suggestedRepsMin}〜${result.suggestedRepsMax}',
                ),
                AppSpacing.gapXS,
                _resultRow(
                  context,
                  label: '理由',
                  value: _reasonLabel(result.recommendation),
                  valueColor: secondaryColor,
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
    Color? valueColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }

  String _formatWeight(double weight) {
    return weight == weight.truncateToDouble()
        ? weight.toInt().toString()
        : weight.toString();
  }

  String _reasonLabel(ProgressionRecommendation recommendation) {
    return switch (recommendation) {
      ProgressionRecommendation.increaseWeight => '前回目標達成済みのため',
      ProgressionRecommendation.maintainWeight => '現重量でレップ数を伸ばすため',
      ProgressionRecommendation.repeatWeight => '前回目標未達のため重量を維持',
    };
  }
}
