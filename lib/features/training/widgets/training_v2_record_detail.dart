import 'package:flutter/material.dart';

import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../core/repositories/training_repository.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../models/persisted_training_record.dart';
import '../models/progression_result.dart';
import '../services/training_exercise_identity.dart';
import '../services/training_cardio_energy_service.dart';
import '../services/training_v2_personal_record_service.dart';
import '../services/training_v2_previous_service.dart';
import '../services/training_v2_progression_service.dart';
import '../services/training_v2_statistics_service.dart';

class TrainingV2RecordDetail extends StatelessWidget {
  final TrainingRecord record;

  const TrainingV2RecordDetail({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final session = record.readModel.v2Data!;
    return FutureBuilder<Map<int, _ExerciseAnalysis>>(
      future: _loadAnalysis(),
      builder: (context, snapshot) {
        final analysis = snapshot.data ?? const <int, _ExerciseAnalysis>{};
        return Column(
          children: [
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    icon: Icons.event_note_outlined,
                    title: 'SESSION',
                  ),
                  AppSpacing.gapSM,
                  const Text('READ ONLY — Training Record v2'),
                  if (session.sessionName != null)
                    Text('Session ${session.sessionName}'),
                  if (session.sessionGrade != null)
                    Text('Grade ${session.sessionGrade!.displayLabel}'),
                  Text('Memo ${session.memo ?? '-'}'),
                  Text(
                    'Dynamic Stretch '
                    '${_formatBool(session.dynamicStretchCompleted)}',
                  ),
                  Text(
                    'Cooldown Stretch '
                    '${_formatBool(session.cooldownStretchCompleted)}',
                  ),
                  Text('Evaluation ${session.overallEvaluation ?? '-'}'),
                ],
              ),
            ),
            for (final exercise in session.exercises)
              _ExerciseCard(
                exercise: exercise,
                analysis: analysis[exercise.order],
              ),
            if (session.cardioEntries.isNotEmpty)
              _CardioCard(entries: session.cardioEntries),
          ],
        );
      },
    );
  }

  Future<Map<int, _ExerciseAnalysis>> _loadAnalysis() async {
    final records = await TrainingRepository.getReadModels();
    final session = record.readModel.v2Data!;
    return {
      for (final exercise in session.exercises)
        exercise.order: _ExerciseAnalysis(
          statistics: TrainingV2StatisticsService.calculate(exercise),
          personalRecord: TrainingV2PersonalRecordService.find(
            preferredRecords: records,
            identity: TrainingExerciseIdentity.v2(exercise),
          ),
          previous: TrainingV2PreviousService.find(
            preferredRecords: records,
            targetRecord: record.readModel,
            identity: TrainingExerciseIdentity.v2(exercise),
          ),
          progression: TrainingV2ProgressionService.forRecord(
            preferredRecords: records,
            targetRecord: record.readModel,
            identity: TrainingExerciseIdentity.v2(exercise),
          ),
        ),
    };
  }
}

class _ExerciseCard extends StatelessWidget {
  final TrainingExerciseV2 exercise;
  final _ExerciseAnalysis? analysis;

  const _ExerciseCard({required this.exercise, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final statistics =
        analysis?.statistics ?? TrainingV2StatisticsService.calculate(exercise);
    final nextTarget = exercise.nextTarget;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.fitness_center_outlined,
            title: 'EXERCISE',
          ),
          AppSpacing.gapSM,
          Text(
            exercise.exerciseName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Equipment ${exercise.equipment?.name ?? 'None'}'),
          for (final set in exercise.sets)
            Text(
              '${set.setType.displayLabel} ${set.setNo}   '
              '${_number(set.weightKg)} kg x ${set.reps}'
              '${set.rpe == null ? '' : '   RPE ${set.rpe}'}'
              '${set.restAfterSeconds == null ? '' : '   Rest ${set.restAfterSeconds}s'}',
            ),
          AppSpacing.gapSM,
          Text(
            statistics.mainSetCount == 0
                ? 'Main Statistics: Not available'
                : 'Main Sets ${statistics.mainSetCount}   '
                      'Reps ${statistics.totalReps}   '
                      'Volume ${_number(statistics.totalVolume)} kg',
          ),
          if (statistics.averageWeight != null)
            Text(
              'Average ${_number(statistics.averageWeight!)} kg   '
              'Heaviest ${_number(statistics.heaviestSet!.weightKg)} kg '
              'x ${statistics.heaviestSet!.reps}',
            ),
          Text(
            analysis?.personalRecord == null
                ? 'Personal Record: Not available'
                : 'Personal Record '
                      '${_number(analysis!.personalRecord!.weightKg)} kg '
                      'x ${analysis!.personalRecord!.reps}',
          ),
          Text(
            analysis?.previous == null
                ? 'Previous: Not available'
                : 'Previous ${analysis!.previous!.record.localDate}   '
                      '${_number(analysis!.previous!.statistics.topSet!.weightKg)} kg '
                      'x ${analysis!.previous!.statistics.topSet!.reps}',
          ),
          Text(
            analysis?.progression == null
                ? 'Progression: Not available'
                : 'Progression '
                      '${_number(analysis!.progression!.suggestedWeight)} kg   '
                      '${analysis!.progression!.suggestedRepsMin}-'
                      '${analysis!.progression!.suggestedRepsMax} reps',
          ),
          Text(
            nextTarget == null
                ? 'Next Target: Not recorded'
                : 'Next Target '
                      '${nextTarget.targetWeightKg == null ? '-' : '${_number(nextTarget.targetWeightKg!)} kg'}   '
                      '${nextTarget.targetReps.isEmpty ? '-' : nextTarget.targetReps.join('/')}'
                      '${nextTarget.notes == null ? '' : '   ${nextTarget.notes}'}',
          ),
          if (exercise.evaluation != null)
            Text('Evaluation ${exercise.evaluation}'),
        ],
      ),
    );
  }
}

class _CardioCard extends StatelessWidget {
  final List<CardioEntryV2> entries;

  const _CardioCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.directions_run_outlined,
            title: 'CARDIO',
          ),
          AppSpacing.gapSM,
          for (final entry in entries) ...[
            if (TrainingCardioEnergyService.isFormalCalculation(entry))
              ..._formalEnergyDetails(entry)
            else
              ..._uncomputedEnergyDetails(entry),
            if (entry.legacyReferenceCaloriesKcal != null)
              Text(
                'Legacy Reference '
                '${_number(entry.legacyReferenceCaloriesKcal!)} kcal',
              ),
            AppSpacing.gapSM,
          ],
        ],
      ),
    );
  }

  List<Widget> _formalEnergyDetails(CardioEntryV2 entry) => [
    Text(
      '${entry.purpose.displayLabel} ${entry.type.name}   '
      '${entry.durationSeconds}s'
      '${entry.equipment == null ? '' : '   ${entry.equipment!.name}'}',
    ),
    Text('METs ${entry.mets == null ? 'Not recorded' : _number(entry.mets!)}'),
    Text(
      'Estimated Calories '
      '${_number(entry.estimatedCaloriesKcal!)} kcal',
    ),
    Text(
      'Weight Snapshot '
      '${_number(entry.weightSnapshotKg!)} kg',
    ),
    Text('Calculation ${_calculationLabel(entry)}'),
  ];

  List<Widget> _uncomputedEnergyDetails(CardioEntryV2 entry) => [
    Text(
      '${entry.purpose.displayLabel} ${entry.type.name}   '
      '${entry.durationSeconds}s'
      '${entry.equipment == null ? '' : '   ${entry.equipment!.name}'}',
    ),
    Text('METs ${entry.mets == null ? 'Not recorded' : _number(entry.mets!)}'),
    const Text('Estimated Calories Not calculated'),
    const Text('Weight Snapshot Not available'),
    const Text('Calculation Not available'),
  ];
}

class _ExerciseAnalysis {
  final TrainingV2Statistics statistics;
  final TrainingV2PersonalRecord? personalRecord;
  final TrainingV2PreviousResult? previous;
  final ProgressionResult? progression;

  const _ExerciseAnalysis({
    required this.statistics,
    required this.personalRecord,
    required this.previous,
    required this.progression,
  });
}

String _formatBool(bool? value) => switch (value) {
  true => 'Completed',
  false => 'Not completed',
  null => '-',
};

String _number(double value) {
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}

String _calculationLabel(CardioEntryV2 entry) {
  if (entry.calculationMethod == 'metsAcsmV1' &&
      entry.calculationVersion == 1) {
    return 'METs ACSM v1';
  }
  return '${entry.calculationMethod} v${entry.calculationVersion}';
}
