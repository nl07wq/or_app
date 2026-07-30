import 'package:flutter/material.dart';

import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/progression_result.dart';
import '../models/training_record_read_model.dart';
import '../models/training_v2_form_controller.dart';
import '../services/training_v2_entry_insight_service.dart';
import 'training_metric_format.dart';

class TrainingV2EntryInsightPanel extends StatelessWidget {
  final TrainingV2ExerciseFormController controller;
  final List<TrainingRecordReadModel> preferredRecords;
  final TrainingRecordReadModel? targetRecord;
  final String sessionDate;

  const TrainingV2EntryInsightPanel({
    super.key,
    required this.controller,
    required this.preferredRecords,
    required this.targetRecord,
    required this.sessionDate,
  });

  @override
  Widget build(BuildContext context) {
    final exercise = _currentExercise();
    final insights = TrainingV2EntryInsightService.calculate(
      preferredRecords: preferredRecords,
      currentExercise: exercise,
      sessionDate: sessionDate,
      targetRecord: targetRecord,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightCard(
          title: 'PROGRESSION',
          child: _ProgressionContent(result: insights.progression),
        ),
        AppSpacing.gapXS,
        _InsightCard(
          title: 'STATISTICS',
          child: insights.statistics.mainSetCount == 0
              ? const Text('記録なし')
              : Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text('${insights.statistics.mainSetCount} Sets'),
                    Text('${insights.statistics.totalReps} Reps'),
                    Text(
                      '${formatTrainingNumberWithThousands(insights.statistics.totalVolume)} kg',
                    ),
                    if (insights.statistics.averageWeight != null)
                      Text(
                        '平均 ${formatTrainingNumber(insights.statistics.averageWeight!)} kg',
                      ),
                    if (insights.statistics.heaviestSet != null)
                      Text(
                        '最高 ${formatTrainingNumber(insights.statistics.heaviestSet!.weightKg)} kg'
                        ' × ${insights.statistics.heaviestSet!.reps}',
                      ),
                  ],
                ),
        ),
        AppSpacing.gapXS,
        _InsightCard(
          title: 'PERSONAL RECORD',
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              const Text('自己ベスト'),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  insights.personalRecord == null
                      ? '記録なし'
                      : '${formatTrainingNumber(insights.personalRecord!.highestWeight)} kg'
                            ' × ${insights.personalRecord!.highestRepetitions}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TrainingExerciseV2 _currentExercise() {
    final sets = <TrainingSetV2>[];
    for (final (index, value) in controller.sets.indexed) {
      if (value.setType == TrainingSetType.legacyUnknown) continue;
      final weight = double.tryParse(value.weight.text.trim());
      final reps = int.tryParse(value.reps.text.trim());
      if (weight == null || !weight.isFinite || weight < 0) continue;
      if (reps == null || reps < 1) continue;
      sets.add(
        TrainingSetV2(
          setNo: index + 1,
          setType: value.setType,
          weightKg: weight,
          reps: reps,
        ),
      );
    }
    return TrainingExerciseV2(
      exerciseName: controller.exerciseName.text.trim(),
      order: 1,
      equipment: controller.equipment,
      sets: sets,
    );
  }
}

class _ProgressionContent extends StatelessWidget {
  final ProgressionResult? result;

  const _ProgressionContent({required this.result});

  @override
  Widget build(BuildContext context) {
    final value = result;
    if (value == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('前回　記録なし'),
          Text('今回　提案なし'),
          Text('理由　比較できる前回記録がありません'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '前回　${formatTrainingNumber(value.lastWeight)} kg'
          ' × ${value.lastReps}',
        ),
        Text(
          '今回　${formatTrainingNumber(value.suggestedWeight)} kg'
          ' × ${value.suggestedRepsMin}–${value.suggestedRepsMax}',
        ),
        Text('理由　${_reason(value.recommendation)}'),
      ],
    );
  }

  String _reason(ProgressionRecommendation recommendation) {
    return switch (recommendation) {
      ProgressionRecommendation.increaseWeight => '前回目標を達成',
      ProgressionRecommendation.maintainWeight => '現在重量でレップ数を伸ばす',
      ProgressionRecommendation.repeatWeight => '現在重量を継続',
    };
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InsightCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: AppRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          child,
        ],
      ),
    );
  }
}
