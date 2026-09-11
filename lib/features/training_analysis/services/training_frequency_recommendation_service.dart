import '../../training/models/training_record_read_model.dart';
import '../../training/services/training_exercise_identity.dart';
import '../../training/services/training_history_domain_service.dart';
import 'training_analysis_metrics_adapter.dart';

/// Evidence quality for a recommended training interval. This is deliberately
/// categorical rather than a probability or performance score.
enum TrainingFrequencyConfidence { insufficient, low, medium }

enum TrainingFrequencyRecommendationStatus {
  baselineOnly,
  personalized,
  conflicting,
  unavailable,
}

enum TrainingFrequencyObservationClassification {
  supported,
  conflicting,
  limited,
  insufficient,
}

enum TrainingFrequencyReasonCode {
  weightMaintained,
  weightIncreased,
  repsMaintained,
  repsIncreased,
  loadMaintained,
  loadIncreased,
  rpeLowerAtComparableWork,
  loadProgression,
  programmingChanged,
  metricsConflict,
  missingMetrics,
  longGap,
}

class TrainingFrequencyMetricSnapshot {
  const TrainingFrequencyMetricSnapshot({
    required this.maxWeight,
    required this.totalReps,
    required this.recordedSetCount,
    required this.recordedVolume,
    required this.workingVolume,
    required this.averageRpe,
  });

  factory TrainingFrequencyMetricSnapshot.fromPoint(
    ExerciseHistoryPoint point,
  ) {
    final values = TrainingAnalysisExerciseMetricValues.fromPoint(point);
    return TrainingFrequencyMetricSnapshot(
      maxWeight: values.maxWeight,
      totalReps: values.totalReps,
      recordedSetCount: values.recordedSetCount,
      recordedVolume: values.recordedVolume,
      workingVolume: values.workingVolume,
      averageRpe: values.averageRpe,
    );
  }

  final double? maxWeight;
  final int? totalReps;
  final int? recordedSetCount;
  final double? recordedVolume;
  final double? workingVolume;
  final double? averageRpe;

  bool get hasComparableObjectiveMetrics =>
      maxWeight != null && totalReps != null && recordedVolume != null;
}

class TrainingFrequencyObservation {
  TrainingFrequencyObservation({
    required this.previousRecordId,
    required this.currentRecordId,
    required this.previousEndTime,
    required this.currentStartTime,
    required this.intervalHours,
    required this.previous,
    required this.current,
    required this.classification,
    required Iterable<TrainingFrequencyReasonCode> reasonCodes,
    required this.isLongGap,
  }) : reasonCodes = List.unmodifiable(reasonCodes);

  final String previousRecordId;
  final String currentRecordId;
  final DateTime previousEndTime;
  final DateTime currentStartTime;
  final double intervalHours;
  final TrainingFrequencyMetricSnapshot previous;
  final TrainingFrequencyMetricSnapshot current;
  final TrainingFrequencyObservationClassification classification;
  final List<TrainingFrequencyReasonCode> reasonCodes;
  final bool isLongGap;
}

class TrainingFrequencyRecommendation {
  TrainingFrequencyRecommendation({
    required this.targetIdentity,
    required Iterable<MuscleGroup> targetMuscles,
    required this.recoveryReferenceHours,
    required this.recommendedMinHours,
    required this.recommendedMaxHours,
    required this.observedMinHours,
    required this.observedMaxHours,
    required this.validObservationCount,
    required this.supportedObservationCount,
    required this.longGapObservationCount,
    required this.confidence,
    required this.status,
    required this.latestObservedIntervalHours,
    required Iterable<TrainingFrequencyObservation> evidence,
  }) : targetMuscles = List.unmodifiable(targetMuscles),
       evidence = List.unmodifiable(evidence);

  final TrainingExerciseIdentity targetIdentity;
  final List<MuscleGroup> targetMuscles;
  final int? recoveryReferenceHours;
  final double? recommendedMinHours;
  final double? recommendedMaxHours;
  final double? observedMinHours;
  final double? observedMaxHours;
  final int validObservationCount;
  final int supportedObservationCount;
  final int longGapObservationCount;
  final TrainingFrequencyConfidence confidence;
  final TrainingFrequencyRecommendationStatus status;
  final double? latestObservedIntervalHours;
  final List<TrainingFrequencyObservation> evidence;
}

/// On-demand, deterministic recommendation derivation from Formal Training
/// History. It never mutates or persists Training Records.
class TrainingFrequencyRecommendationService {
  const TrainingFrequencyRecommendationService({
    this.domain = const TrainingHistoryDomainService(),
  });

  static const _longGap = Duration(days: 14);
  static const _windowSize = 5;

  final TrainingHistoryDomainService domain;

  List<TrainingFrequencyRecommendation> build({
    required TrainingRecordReadModel target,
    required Iterable<TrainingRecordReadModel> records,
    required DateTime now,
  }) {
    final values = records.toList(growable: false);
    final recordsById = {for (final record in values) record.id: record};
    final targetPoints = domain
        .exerciseHistory(values)
        .where((point) => point.recordId == target.id)
        .toList(growable: false);
    return [
      for (final point in targetPoints)
        _recommendationFor(
          target: target,
          identity: point.identity,
          recordsById: recordsById,
          points: domain.exerciseHistory(values),
          now: now,
        ),
    ];
  }

  TrainingFrequencyRecommendation _recommendationFor({
    required TrainingRecordReadModel target,
    required TrainingExerciseIdentity identity,
    required Map<String, TrainingRecordReadModel> recordsById,
    required List<ExerciseHistoryPoint> points,
    required DateTime now,
  }) {
    final mapping = ExerciseMuscleRegistry.resolve(identity);
    final targetMuscles = mapping?.targetMuscles ?? const <MuscleGroup>[];
    final reference = _maximumReference(targetMuscles);
    if (mapping == null || reference == null) {
      return TrainingFrequencyRecommendation(
        targetIdentity: identity,
        targetMuscles: targetMuscles,
        recoveryReferenceHours: null,
        recommendedMinHours: null,
        recommendedMaxHours: null,
        observedMinHours: null,
        observedMaxHours: null,
        validObservationCount: 0,
        supportedObservationCount: 0,
        longGapObservationCount: 0,
        confidence: TrainingFrequencyConfidence.insufficient,
        status: TrainingFrequencyRecommendationStatus.unavailable,
        latestObservedIntervalHours: null,
        evidence: const [],
      );
    }

    final occurrences = [
      for (final point in points)
        if (point.identity == identity &&
            (point.recordId == target.id ||
                (recordsById[point.recordId]?.sortDateTime.isBefore(
                      target.sortDateTime,
                    ) ??
                    false)))
          _Occurrence(point, recordsById[point.recordId]!),
    ]..sort((a, b) => a.record.sortDateTime.compareTo(b.record.sortDateTime));

    final allExact = <TrainingFrequencyObservation>[];
    for (var index = 1; index < occurrences.length; index++) {
      final observation = _observation(
        previous: occurrences[index - 1],
        current: occurrences[index],
        now: now,
      );
      if (observation != null) allExact.add(observation);
    }
    final longGapCount = allExact.where((value) => value.isLongGap).length;
    final normal = allExact.where((value) => !value.isLongGap).toList();
    final evidence = normal.length <= _windowSize
        ? normal
        : normal.sublist(normal.length - _windowSize);
    final supported = evidence
        .where(
          (value) =>
              value.classification ==
              TrainingFrequencyObservationClassification.supported,
        )
        .toList(growable: false);
    final conflicts = evidence.where(
      (value) =>
          value.classification ==
          TrainingFrequencyObservationClassification.conflicting,
    );
    final observedHours = evidence
        .map((value) => value.intervalHours)
        .toList(growable: false);
    final baselineHours = reference.inMinutes / Duration.minutesPerHour;
    final hasConflicts = conflicts.isNotEmpty;
    final canPersonalize =
        evidence.length >= 3 && supported.length >= 3 && !hasConflicts;
    final status = canPersonalize
        ? TrainingFrequencyRecommendationStatus.personalized
        : hasConflicts
        ? TrainingFrequencyRecommendationStatus.conflicting
        : TrainingFrequencyRecommendationStatus.baselineOnly;
    final confidence = canPersonalize
        ? TrainingFrequencyConfidence.medium
        : evidence.length <= 1
        ? TrainingFrequencyConfidence.insufficient
        : TrainingFrequencyConfidence.low;
    final recommendedIntervals = supported
        .map((value) => value.intervalHours)
        .toList(growable: false);
    final recommendedMin = canPersonalize
        ? _max(baselineHours, _min(recommendedIntervals))
        : baselineHours;
    final recommendedMax = canPersonalize
        ? _max(recommendedMin, _maxValue(recommendedIntervals))
        : null;
    return TrainingFrequencyRecommendation(
      targetIdentity: identity,
      targetMuscles: targetMuscles,
      recoveryReferenceHours: reference.inHours,
      recommendedMinHours: recommendedMin,
      recommendedMaxHours: recommendedMax,
      observedMinHours: observedHours.isEmpty ? null : _min(observedHours),
      observedMaxHours: observedHours.isEmpty ? null : _maxValue(observedHours),
      validObservationCount: evidence.length,
      supportedObservationCount: supported.length,
      longGapObservationCount: longGapCount,
      confidence: confidence,
      status: status,
      latestObservedIntervalHours: evidence.isEmpty
          ? null
          : evidence.last.intervalHours,
      evidence: evidence,
    );
  }

  Duration? _maximumReference(Iterable<MuscleGroup> muscles) {
    Duration? result;
    for (final muscle in muscles) {
      final duration = domain.recoveryPolicy.durationFor(muscle);
      if (duration == null) return null;
      if (result == null || duration > result) result = duration;
    }
    return result;
  }

  TrainingFrequencyObservation? _observation({
    required _Occurrence previous,
    required _Occurrence current,
    required DateTime now,
  }) {
    final previousEnd = _exactEnd(previous.record);
    final currentStart = _exactStart(current.record);
    if (previousEnd == null ||
        currentStart == null ||
        previousEnd.isAfter(now) ||
        currentStart.isAfter(now) ||
        !currentStart.isAfter(previousEnd)) {
      return null;
    }
    final interval = currentStart.difference(previousEnd);
    final isLongGap = interval > _longGap;
    final previousMetrics = TrainingFrequencyMetricSnapshot.fromPoint(
      previous.point,
    );
    final currentMetrics = TrainingFrequencyMetricSnapshot.fromPoint(
      current.point,
    );
    final classification = _classify(previousMetrics, currentMetrics);
    return TrainingFrequencyObservation(
      previousRecordId: previous.record.id,
      currentRecordId: current.record.id,
      previousEndTime: previousEnd,
      currentStartTime: currentStart,
      intervalHours: interval.inMinutes / Duration.minutesPerHour,
      previous: previousMetrics,
      current: currentMetrics,
      classification: classification.$1,
      reasonCodes: [
        ...classification.$2,
        if (isLongGap) TrainingFrequencyReasonCode.longGap,
      ],
      isLongGap: isLongGap,
    );
  }

  (
    TrainingFrequencyObservationClassification,
    List<TrainingFrequencyReasonCode>,
  )
  _classify(
    TrainingFrequencyMetricSnapshot previous,
    TrainingFrequencyMetricSnapshot current,
  ) {
    if (!previous.hasComparableObjectiveMetrics ||
        !current.hasComparableObjectiveMetrics) {
      return (
        TrainingFrequencyObservationClassification.insufficient,
        [TrainingFrequencyReasonCode.missingMetrics],
      );
    }
    final reasons = <TrainingFrequencyReasonCode>[];
    final weightComparison = current.maxWeight!.compareTo(previous.maxWeight!);
    final repsComparison = current.totalReps!.compareTo(previous.totalReps!);
    final loadComparison = current.recordedVolume!.compareTo(
      previous.recordedVolume!,
    );
    if (weightComparison > 0) {
      reasons.add(TrainingFrequencyReasonCode.weightIncreased);
    } else if (weightComparison == 0) {
      reasons.add(TrainingFrequencyReasonCode.weightMaintained);
    }
    if (repsComparison > 0) {
      reasons.add(TrainingFrequencyReasonCode.repsIncreased);
    } else if (repsComparison == 0) {
      reasons.add(TrainingFrequencyReasonCode.repsMaintained);
    }
    if (loadComparison > 0) {
      reasons.add(TrainingFrequencyReasonCode.loadIncreased);
    } else if (loadComparison == 0) {
      reasons.add(TrainingFrequencyReasonCode.loadMaintained);
    }
    final programmingChanged =
        current.recordedSetCount != previous.recordedSetCount;
    if (programmingChanged) {
      reasons.add(TrainingFrequencyReasonCode.programmingChanged);
      return (TrainingFrequencyObservationClassification.limited, reasons);
    }
    final sameWork =
        weightComparison == 0 && repsComparison == 0 && loadComparison == 0;
    if (sameWork &&
        previous.averageRpe != null &&
        current.averageRpe != null &&
        current.averageRpe! < previous.averageRpe!) {
      reasons.add(TrainingFrequencyReasonCode.rpeLowerAtComparableWork);
    }
    if (weightComparison == 0 && repsComparison >= 0 && loadComparison >= 0) {
      return (TrainingFrequencyObservationClassification.supported, reasons);
    }
    if (weightComparison > 0 && (repsComparison >= 0 || loadComparison >= 0)) {
      return (TrainingFrequencyObservationClassification.supported, reasons);
    }
    if (weightComparison > 0) {
      reasons.add(TrainingFrequencyReasonCode.loadProgression);
      return (TrainingFrequencyObservationClassification.limited, reasons);
    }
    reasons.add(TrainingFrequencyReasonCode.metricsConflict);
    return (TrainingFrequencyObservationClassification.conflicting, reasons);
  }

  DateTime? _exactStart(TrainingRecordReadModel record) =>
      record.v2Data?.startTime == null
      ? null
      : DateTime.tryParse(record.v2Data!.startTime!);

  DateTime? _exactEnd(TrainingRecordReadModel record) =>
      record.v2Data?.endTime == null
      ? null
      : DateTime.tryParse(record.v2Data!.endTime!);
}

class _Occurrence {
  const _Occurrence(this.point, this.record);
  final ExerciseHistoryPoint point;
  final TrainingRecordReadModel record;
}

double _min(Iterable<double> values) => values.reduce((a, b) => a < b ? a : b);
double _maxValue(Iterable<double> values) =>
    values.reduce((a, b) => a > b ? a : b);
double _max(double first, double second) => first > second ? first : second;
