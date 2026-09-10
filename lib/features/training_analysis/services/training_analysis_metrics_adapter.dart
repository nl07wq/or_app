import '../../training/models/training_record_read_model.dart';
import '../../training/services/training_exercise_history_adapter.dart';
import '../../training/services/training_exercise_identity.dart';
import '../../training/services/training_history_domain_service.dart';

/// Presentation-safe structured metrics for a Training Analysis Report.
///
/// Values are derived from the same History domain service used by Training
/// History. This adapter deliberately turns a no-set exercise into unavailable
/// metrics instead of presenting its domain aggregation zero as a performed
/// measurement.
class TrainingAnalysisMetricsAdapter {
  const TrainingAnalysisMetricsAdapter({
    this.domain = const TrainingHistoryDomainService(),
    this.exerciseHistory = const TrainingExerciseHistoryAdapter(),
  });

  final TrainingHistoryDomainService domain;
  final TrainingExerciseHistoryAdapter exerciseHistory;

  TrainingAnalysisMetrics build({
    required TrainingRecordReadModel target,
    required Iterable<TrainingRecordReadModel> records,
  }) {
    final values = records.toList(growable: false);
    final recordsById = {for (final record in values) record.id: record};
    final points = domain.exerciseHistory(values);
    final currentPoints = points
        .where((point) => point.recordId == target.id)
        .toList(growable: false);

    return TrainingAnalysisMetrics(
      session: TrainingAnalysisSessionMetrics.fromAggregate(
        domain.sessionAggregate(target),
      ),
      exercises: [
        for (final current in currentPoints)
          _exerciseMetrics(
            current: current,
            target: target,
            recordsById: recordsById,
            allPoints: points,
          ),
      ],
    );
  }

  TrainingAnalysisExerciseMetrics _exerciseMetrics({
    required ExerciseHistoryPoint current,
    required TrainingRecordReadModel target,
    required Map<String, TrainingRecordReadModel> recordsById,
    required List<ExerciseHistoryPoint> allPoints,
  }) {
    final historical =
        [
          for (final point in allPoints)
            if (point.identity == current.identity &&
                point.recordId != target.id &&
                (recordsById[point.recordId]?.sortDateTime.isBefore(
                      target.sortDateTime,
                    ) ??
                    false))
              point,
        ]..sort((a, b) {
          final first = recordsById[a.recordId]!.sortDateTime;
          final second = recordsById[b.recordId]!.sortDateTime;
          return second.compareTo(first);
        });
    final selector = exerciseHistory.selectorPresentation(current.identity);
    return TrainingAnalysisExerciseMetrics(
      identity: current.identity,
      exerciseName: selector.exerciseLabel,
      equipmentLabel: selector.equipmentLabel,
      current: TrainingAnalysisExerciseMetricValues.fromPoint(current),
      previous: historical.isEmpty
          ? null
          : TrainingAnalysisExerciseMetricValues.fromPoint(historical.first),
      recentHistory: [
        for (final point in historical.take(5))
          TrainingAnalysisHistoryEvidence.fromPoint(point),
      ],
    );
  }
}

class TrainingAnalysisMetrics {
  TrainingAnalysisMetrics({
    required this.session,
    required Iterable<TrainingAnalysisExerciseMetrics> exercises,
  }) : exercises = List.unmodifiable(exercises);

  final TrainingAnalysisSessionMetrics session;
  final List<TrainingAnalysisExerciseMetrics> exercises;
}

class TrainingAnalysisSessionMetrics {
  const TrainingAnalysisSessionMetrics({
    required this.operationDate,
    required this.duration,
    required this.exerciseCount,
    required this.recordedSetCount,
    required this.totalReps,
    required this.recordedVolume,
    required this.workingVolume,
    required this.averageRpe,
  });

  factory TrainingAnalysisSessionMetrics.fromAggregate(
    TrainingSessionAggregate aggregate,
  ) => TrainingAnalysisSessionMetrics(
    operationDate: aggregate.operationDate,
    duration: aggregate.duration,
    exerciseCount: aggregate.exerciseCount,
    recordedSetCount: aggregate.recordedSetCount == 0
        ? null
        : aggregate.recordedSetCount,
    totalReps: aggregate.recordedSetCount == 0 ? null : aggregate.recordedReps,
    recordedVolume: aggregate.recordedSetCount == 0
        ? null
        : aggregate.recordedVolume,
    workingVolume:
        aggregate.workingSetCount == null || aggregate.workingSetCount == 0
        ? null
        : aggregate.workingVolume,
    averageRpe: aggregate.recordedRpeAverage,
  );

  final String operationDate;
  final Duration? duration;
  final int exerciseCount;
  final int? recordedSetCount;
  final int? totalReps;
  final double? recordedVolume;
  final double? workingVolume;
  final double? averageRpe;
}

class TrainingAnalysisExerciseMetrics {
  TrainingAnalysisExerciseMetrics({
    required this.identity,
    required this.exerciseName,
    required this.equipmentLabel,
    required this.current,
    required this.previous,
    required Iterable<TrainingAnalysisHistoryEvidence> recentHistory,
  }) : recentHistory = List.unmodifiable(recentHistory);

  final TrainingExerciseIdentity identity;
  final String exerciseName;
  final String? equipmentLabel;
  final TrainingAnalysisExerciseMetricValues current;
  final TrainingAnalysisExerciseMetricValues? previous;
  final List<TrainingAnalysisHistoryEvidence> recentHistory;
}

class TrainingAnalysisExerciseMetricValues {
  const TrainingAnalysisExerciseMetricValues({
    required this.maxWeight,
    required this.totalReps,
    required this.recordedSetCount,
    required this.recordedVolume,
    required this.workingVolume,
    required this.averageRpe,
  });

  factory TrainingAnalysisExerciseMetricValues.fromPoint(
    ExerciseHistoryPoint point,
  ) {
    final hasRecordedSets = point.recordedSetCount > 0;
    return TrainingAnalysisExerciseMetricValues(
      maxWeight: point.maxWeight,
      totalReps: hasRecordedSets ? point.recordedReps : null,
      recordedSetCount: hasRecordedSets ? point.recordedSetCount : null,
      recordedVolume: hasRecordedSets ? point.recordedVolume : null,
      workingVolume: point.workingSetCount == null || point.workingSetCount == 0
          ? null
          : point.workingVolume,
      averageRpe: point.recordedRpeAverage,
    );
  }

  final double? maxWeight;
  final int? totalReps;
  final int? recordedSetCount;
  final double? recordedVolume;
  final double? workingVolume;
  final double? averageRpe;
}

class TrainingAnalysisHistoryEvidence {
  const TrainingAnalysisHistoryEvidence({
    required this.recordId,
    required this.operationDate,
  });

  factory TrainingAnalysisHistoryEvidence.fromPoint(
    ExerciseHistoryPoint point,
  ) => TrainingAnalysisHistoryEvidence(
    recordId: point.recordId,
    operationDate: point.operationDate,
  );

  final String recordId;
  final String operationDate;
}
