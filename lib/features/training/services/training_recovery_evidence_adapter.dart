import 'package:flutter/material.dart';

import '../models/training_record_read_model.dart';
import 'training_exercise_history_adapter.dart';
import 'training_history_domain_service.dart';
import 'training_history_overview_adapter.dart';

/// Period-scoped, presentation-ready recovery evidence.
///
/// This intentionally exposes formal PRIMARY-muscle evidence only. Recovery
/// progress remains the responsibility of a later policy-enabled view.
class TrainingRecoveryEvidenceAdapter {
  const TrainingRecoveryEvidenceAdapter({
    this.domain = const TrainingHistoryDomainService(),
    this.periods = const TrainingHistoryOverviewAdapter(),
    this.exercisePresentation = const TrainingExerciseHistoryAdapter(),
  });

  final TrainingHistoryDomainService domain;
  final TrainingHistoryOverviewAdapter periods;
  final TrainingExerciseHistoryAdapter exercisePresentation;

  List<TrainingRecoveryEvidence> evidence(
    Iterable<TrainingRecordReadModel> records, {
    required TrainingHistoryOverviewPeriod period,
    required DateTime now,
    DateTime? referenceDate,
    DateTimeRange? customRange,
  }) {
    final periodRecords = [
      for (final record in records)
        if (periods.includesOperationDate(
          record.localDate,
          period: period,
          referenceDate: referenceDate,
          customRange: customRange,
        ))
          record,
    ];
    final values =
        [
          for (final muscle in activeRecoveryMuscleGroups)
            if (domain.recoveryEstimate(muscle, periodRecords, now: now)
                case final estimate
                when estimate.sourceExerciseIdentity != null)
              TrainingRecoveryEvidence(
                estimate: estimate,
                source: exercisePresentation.selectorPresentation(
                  estimate.sourceExerciseIdentity!,
                ),
              ),
        ]..sort((a, b) {
          final timeA =
              a.estimate.lastExposureDateTime ??
              DateTime.parse(a.estimate.lastExposureOperationDate!);
          final timeB =
              b.estimate.lastExposureDateTime ??
              DateTime.parse(b.estimate.lastExposureOperationDate!);
          final latest = timeB.compareTo(timeA);
          return latest != 0
              ? latest
              : a.estimate.muscleGroup.index.compareTo(
                  b.estimate.muscleGroup.index,
                );
        });
    return values;
  }

  /// Period-scoped SUPPORT-role involvement. This is deliberately separate
  /// from [evidence]: only target muscles produce recovery evidence.
  List<TrainingSupportInvolvement> supportInvolvement(
    Iterable<TrainingRecordReadModel> records, {
    required TrainingHistoryOverviewPeriod period,
    DateTime? referenceDate,
    DateTimeRange? customRange,
  }) {
    final periodRecords = [
      for (final record in records)
        if (periods.includesOperationDate(
          record.localDate,
          period: period,
          referenceDate: referenceDate,
          customRange: customRange,
        ))
          record,
    ];
    final latest = <MuscleGroup, TrainingSupportInvolvement>{};
    for (final point in domain.exerciseHistory(periodRecords)) {
      final mapping = ExerciseMuscleRegistry.resolve(point.identity);
      if (mapping == null) continue;
      for (final muscle in mapping.supportMuscles) {
        final involvement = TrainingSupportInvolvement(
          muscle: muscle,
          operationDate: point.operationDate,
          startTime: point.startTime,
          sourceRecordId: point.recordId,
          source: exercisePresentation.selectorPresentation(point.identity),
        );
        final current = latest[muscle];
        if (current == null || _isLater(involvement, current)) {
          latest[muscle] = involvement;
        }
      }
    }
    return latest.values.toList()
      ..sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
  }

  bool _isLater(
    TrainingSupportInvolvement candidate,
    TrainingSupportInvolvement current,
  ) {
    final date = candidate.operationDate.compareTo(current.operationDate);
    if (date != 0) return date > 0;
    if (candidate.startTime == null) return false;
    if (current.startTime == null) return true;
    return candidate.startTime!.isAfter(current.startTime!);
  }

  DateTime _sortTime(TrainingSupportInvolvement involvement) =>
      involvement.startTime ?? DateTime.parse(involvement.operationDate);
}

class TrainingRecoveryEvidence {
  const TrainingRecoveryEvidence({
    required this.estimate,
    required this.source,
  });

  final MuscleRecoveryEstimate estimate;
  final TrainingExerciseSelectorPresentation source;
}

/// Derived SUPPORT-role metadata for Body Map presentation. It is not
/// recovery evidence and is never persisted into formal training records.
class TrainingSupportInvolvement {
  const TrainingSupportInvolvement({
    required this.muscle,
    required this.operationDate,
    required this.startTime,
    required this.sourceRecordId,
    required this.source,
  });

  final MuscleGroup muscle;
  final String operationDate;
  final DateTime? startTime;
  final String sourceRecordId;
  final TrainingExerciseSelectorPresentation source;
}

String muscleGroupDisplayName(MuscleGroup muscle) => switch (muscle) {
  MuscleGroup.chest => '胸',
  MuscleGroup.back => '背中（旧分類）',
  MuscleGroup.trapezius => '僧帽筋',
  MuscleGroup.lats => '広背筋',
  MuscleGroup.shoulders => '肩',
  MuscleGroup.biceps => '上腕二頭筋',
  MuscleGroup.triceps => '上腕三頭筋',
  MuscleGroup.forearms => '前腕',
  MuscleGroup.core => '体幹',
  MuscleGroup.quadriceps => '大腿四頭筋',
  MuscleGroup.hamstrings => 'ハムストリングス',
  MuscleGroup.glutes => '臀部',
  MuscleGroup.calves => 'ふくらはぎ',
};
