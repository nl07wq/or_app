import '../../../core/models/training_set_v2.dart';
import '../../../core/models/training_exercise.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../models/training_record_read_model.dart';
import 'training_exercise_identity.dart';

/// Stable V1 muscle groups for derived history and recovery analysis.
enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  core,
  quadriceps,
  hamstrings,
  glutes,
  calves,
}

class ExerciseMuscleMapping {
  const ExerciseMuscleMapping({
    required this.targetMuscles,
    this.supportMuscles = const [],
    required this.exerciseType,
  });

  /// Muscles this exercise directly targets. Recovery evidence is derived only
  /// from these muscles.
  final List<MuscleGroup> targetMuscles;

  /// Muscles with explicit supporting involvement. They are descriptive
  /// mapping metadata only and never reset a recovery clock.
  final List<MuscleGroup> supportMuscles;

  final ExerciseMuscleExerciseType exerciseType;

  /// Compatibility alias for the former recovery-oriented terminology.
  List<MuscleGroup> get primaryMuscles => targetMuscles;

  /// Compatibility alias for the former recovery-oriented terminology.
  List<MuscleGroup> get secondaryMuscles => supportMuscles;
}

enum ExerciseMuscleExerciseType { isolation, compound }

/// Domain metadata only. Unknown/custom exercises intentionally have no entry.
class ExerciseMuscleRegistry {
  const ExerciseMuscleRegistry._();

  static const _byExerciseKey = <String, ExerciseMuscleMapping>{
    'benchpress': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.chest],
      supportMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'inclinebenchpress': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.chest],
      supportMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'chestpress': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.chest],
      supportMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'latpulldown': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.back],
      supportMuscles: [MuscleGroup.biceps, MuscleGroup.forearms],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'seatedrow': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.back],
      supportMuscles: [MuscleGroup.biceps],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'shoulderpress': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.shoulders],
      supportMuscles: [MuscleGroup.triceps],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'facepull': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.shoulders],
      supportMuscles: [MuscleGroup.back],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'dumbbellcurl': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.biceps],
      supportMuscles: [MuscleGroup.forearms],
      exerciseType: ExerciseMuscleExerciseType.isolation,
    ),
    'legpress': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.quadriceps, MuscleGroup.glutes],
      supportMuscles: [MuscleGroup.hamstrings],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'hacksquat': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.quadriceps],
      supportMuscles: [MuscleGroup.glutes],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'squat': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.quadriceps, MuscleGroup.glutes],
      supportMuscles: [MuscleGroup.hamstrings],
      exerciseType: ExerciseMuscleExerciseType.compound,
    ),
    'legcurl': ExerciseMuscleMapping(
      targetMuscles: [MuscleGroup.hamstrings],
      supportMuscles: [MuscleGroup.calves],
      exerciseType: ExerciseMuscleExerciseType.isolation,
    ),
  };

  static ExerciseMuscleMapping? resolve(TrainingExerciseIdentity identity) =>
      resolveExerciseKey(identity.exerciseKey);

  /// Default exercise-level profile. Equipment-specific overrides can be
  /// layered here later without changing formal exercise identities.
  static ExerciseMuscleMapping? resolveExerciseKey(String exerciseKey) =>
      _byExerciseKey[exerciseKey];
}

/// Active analysis policy. It is separate from Formal Training Records.
class RecoveryReferencePolicy {
  const RecoveryReferencePolicy({
    this.policyVersion = policyVersionV1,
    this.referenceDurations = referenceDurationsV1,
  });

  static const policyVersionV1 = 'recovery-reference-policy-v1';

  static const referenceDurationsV1 = <MuscleGroup, Duration>{
    MuscleGroup.chest: Duration(hours: 48),
    MuscleGroup.back: Duration(hours: 48),
    MuscleGroup.shoulders: Duration(hours: 48),
    MuscleGroup.biceps: Duration(hours: 48),
    MuscleGroup.triceps: Duration(hours: 48),
    MuscleGroup.forearms: Duration(hours: 48),
    MuscleGroup.core: Duration(hours: 48),
    MuscleGroup.calves: Duration(hours: 48),
    MuscleGroup.quadriceps: Duration(hours: 72),
    MuscleGroup.hamstrings: Duration(hours: 72),
    MuscleGroup.glutes: Duration(hours: 72),
  };

  final String policyVersion;
  final Map<MuscleGroup, Duration> referenceDurations;

  Duration? durationFor(MuscleGroup muscle) => referenceDurations[muscle];
}

enum RecoveryPrecision { exact, dateOnly, invalid, unavailable }

enum RecoveryStatus { loaded, recovering, nearReady, estimatedReady, noData }

class TrainingSessionAggregate {
  const TrainingSessionAggregate({
    required this.recordId,
    required this.operationDate,
    required this.startTime,
    required this.duration,
    required this.workingVolume,
    required this.recordedVolume,
    required this.workingSetCount,
    required this.recordedSetCount,
    required this.recordedReps,
    required this.exerciseCount,
    required this.recordedRpeAverage,
    required this.recordedRpeMax,
  });

  final String recordId;
  final String operationDate;
  final DateTime? startTime;
  final Duration? duration;
  final double? workingVolume;
  final double recordedVolume;
  final int? workingSetCount;
  final int recordedSetCount;
  final int recordedReps;
  final int exerciseCount;
  final double? recordedRpeAverage;
  final int? recordedRpeMax;
}

class ExerciseHistoryPoint {
  const ExerciseHistoryPoint({
    required this.recordId,
    required this.operationDate,
    required this.startTime,
    required this.identity,
    required this.maxWeight,
    required this.workingVolume,
    required this.recordedVolume,
    required this.workingSetCount,
    required this.recordedSetCount,
    required this.recordedReps,
    required this.recordedRpeAverage,
    required this.recordedRpeMax,
  });

  final String recordId;
  final String operationDate;
  final DateTime? startTime;
  final TrainingExerciseIdentity identity;
  final double? maxWeight;
  final double? workingVolume;
  final double recordedVolume;
  final int? workingSetCount;
  final int recordedSetCount;
  final int recordedReps;
  final double? recordedRpeAverage;
  final int? recordedRpeMax;
}

class MuscleRecoveryEstimate {
  const MuscleRecoveryEstimate({
    required this.muscleGroup,
    required this.lastExposureOperationDate,
    required this.lastExposureDateTime,
    required this.sourceRecordId,
    required this.sourceExerciseIdentity,
    required this.referenceRecoveryDuration,
    required this.elapsedDuration,
    required this.referenceProgressRatio,
    required this.displayProgressRatio,
    required this.estimatedReadyAt,
    required this.status,
    required this.precision,
  });

  final MuscleGroup muscleGroup;
  final String? lastExposureOperationDate;
  final DateTime? lastExposureDateTime;
  final String? sourceRecordId;
  final TrainingExerciseIdentity? sourceExerciseIdentity;
  final Duration? referenceRecoveryDuration;
  final Duration? elapsedDuration;
  final double? referenceProgressRatio;

  /// UI-safe clamped ratio; [referenceProgressRatio] retains elapsed excess.
  final double? displayProgressRatio;
  final DateTime? estimatedReadyAt;
  final RecoveryStatus status;
  final RecoveryPrecision precision;
}

/// Pure derived calculations. It never mutates or persists formal records.
class TrainingHistoryDomainService {
  const TrainingHistoryDomainService({
    this.recoveryPolicy = const RecoveryReferencePolicy(),
  });

  final RecoveryReferencePolicy recoveryPolicy;

  TrainingSessionAggregate sessionAggregate(TrainingRecordReadModel record) {
    final points = _exercisePoints(record);
    final allRpes = _recordedRpes(record);
    return TrainingSessionAggregate(
      recordId: record.id,
      operationDate: record.localDate,
      startTime: _exactStart(record),
      duration: _duration(record),
      workingVolume: record.recordVersion == 2
          ? points.fold<double>(
              0,
              (sum, point) => sum + (point.workingVolume ?? 0),
            )
          : null,
      recordedVolume: points.fold<double>(
        0,
        (sum, point) => sum + point.recordedVolume,
      ),
      workingSetCount: record.recordVersion == 2
          ? points.fold<int>(
              0,
              (sum, point) => sum + (point.workingSetCount ?? 0),
            )
          : null,
      recordedSetCount: points.fold<int>(
        0,
        (sum, point) => sum + point.recordedSetCount,
      ),
      recordedReps: points.fold<int>(
        0,
        (sum, point) => sum + point.recordedReps,
      ),
      exerciseCount: record.exerciseCount,
      recordedRpeAverage: allRpes.isEmpty
          ? null
          : allRpes.reduce((a, b) => a + b) / allRpes.length,
      recordedRpeMax: allRpes.isEmpty ? null : allRpes.reduce(_maxInt),
    );
  }

  List<ExerciseHistoryPoint> exerciseHistory(
    Iterable<TrainingRecordReadModel> records,
  ) =>
      [for (final record in records) ..._exercisePoints(record)]
        ..sort((a, b) => _historyTime(a).compareTo(_historyTime(b)));

  MuscleRecoveryEstimate recoveryEstimate(
    MuscleGroup muscle,
    Iterable<TrainingRecordReadModel> records, {
    required DateTime now,
  }) {
    _Exposure? latestExact;
    _Exposure? latestDateOnly;
    for (final record in records) {
      for (final point in _exercisePoints(record)) {
        final mapping = ExerciseMuscleRegistry.resolve(point.identity);
        if (mapping == null || !mapping.targetMuscles.contains(muscle))
          continue;
        final exposure = _Exposure(record, point);
        if (point.startTime != null &&
            (latestExact == null ||
                point.startTime!.isAfter(latestExact.point.startTime!)))
          latestExact = exposure;
        if (latestDateOnly == null ||
            record.localDate.compareTo(latestDateOnly.record.localDate) > 0)
          latestDateOnly = exposure;
      }
    }
    final exposure =
        latestDateOnly != null &&
            (latestExact == null ||
                latestDateOnly.record.localDate.compareTo(
                      latestExact.record.localDate,
                    ) >
                    0)
        ? latestDateOnly
        : latestExact ?? latestDateOnly;
    final reference = recoveryPolicy.durationFor(muscle);
    if (exposure == null || reference == null)
      return MuscleRecoveryEstimate(
        muscleGroup: muscle,
        lastExposureOperationDate: exposure?.record.localDate,
        lastExposureDateTime: exposure?.point.startTime,
        sourceRecordId: exposure?.record.id,
        sourceExerciseIdentity: exposure?.point.identity,
        referenceRecoveryDuration: reference,
        elapsedDuration: null,
        referenceProgressRatio: null,
        displayProgressRatio: null,
        estimatedReadyAt: null,
        status: RecoveryStatus.noData,
        precision: exposure == null
            ? RecoveryPrecision.unavailable
            : exposure.point.startTime == null
            ? RecoveryPrecision.dateOnly
            : RecoveryPrecision.exact,
      );
    final time = exposure.point.startTime;
    if (time == null)
      return MuscleRecoveryEstimate(
        muscleGroup: muscle,
        lastExposureOperationDate: exposure.record.localDate,
        lastExposureDateTime: null,
        sourceRecordId: exposure.record.id,
        sourceExerciseIdentity: exposure.point.identity,
        referenceRecoveryDuration: reference,
        elapsedDuration: null,
        referenceProgressRatio: null,
        displayProgressRatio: null,
        estimatedReadyAt: null,
        status: RecoveryStatus.noData,
        precision: RecoveryPrecision.dateOnly,
      );
    if (now.isBefore(time)) {
      return MuscleRecoveryEstimate(
        muscleGroup: muscle,
        lastExposureOperationDate: exposure.record.localDate,
        lastExposureDateTime: time,
        sourceRecordId: exposure.record.id,
        sourceExerciseIdentity: exposure.point.identity,
        referenceRecoveryDuration: reference,
        elapsedDuration: null,
        referenceProgressRatio: null,
        displayProgressRatio: null,
        estimatedReadyAt: null,
        status: RecoveryStatus.noData,
        precision: RecoveryPrecision.invalid,
      );
    }
    final elapsed = now.difference(time);
    final ratio = elapsed.inMicroseconds / reference.inMicroseconds;
    final status = ratio < .25
        ? RecoveryStatus.loaded
        : ratio < .75
        ? RecoveryStatus.recovering
        : ratio < 1
        ? RecoveryStatus.nearReady
        : RecoveryStatus.estimatedReady;
    return MuscleRecoveryEstimate(
      muscleGroup: muscle,
      lastExposureOperationDate: exposure.record.localDate,
      lastExposureDateTime: time,
      sourceRecordId: exposure.record.id,
      sourceExerciseIdentity: exposure.point.identity,
      referenceRecoveryDuration: reference,
      elapsedDuration: elapsed,
      referenceProgressRatio: ratio,
      displayProgressRatio: ratio.clamp(0.0, 1.0).toDouble(),
      estimatedReadyAt: time.add(reference),
      status: status,
      precision: RecoveryPrecision.exact,
    );
  }

  List<ExerciseHistoryPoint> _exercisePoints(TrainingRecordReadModel record) {
    if (record.v2Data case final session?)
      return [
        for (final exercise in session.exercises) _v2Point(record, exercise),
      ];
    final session = record.v1Data!;
    return [
      for (final exercise in session.exercises) _v1Point(record, exercise),
    ];
  }

  ExerciseHistoryPoint _v1Point(
    TrainingRecordReadModel record,
    TrainingExercise exercise,
  ) {
    final sets = exercise.sets;
    return ExerciseHistoryPoint(
      recordId: record.id,
      operationDate: record.localDate,
      startTime: null,
      identity: TrainingExerciseIdentity.v1(exercise),
      maxWeight: sets.isEmpty
          ? null
          : sets.map<double>((set) => set.weight).reduce(mathMax),
      workingVolume: null,
      recordedVolume: sets.fold<double>(
        0,
        (sum, set) => sum + set.weight * set.reps,
      ),
      workingSetCount: null,
      recordedSetCount: sets.length,
      recordedReps: sets.fold<int>(0, (sum, set) => sum + set.reps),
      recordedRpeAverage: null,
      recordedRpeMax: null,
    );
  }

  ExerciseHistoryPoint _v2Point(
    TrainingRecordReadModel record,
    TrainingExerciseV2 exercise,
  ) {
    final sets = exercise.sets;
    final main = sets
        .where((set) => set.setType == TrainingSetType.main)
        .toList();
    final rpes = sets
        .where((set) => set.rpe != null)
        .map<int>((set) => set.rpe as int)
        .toList();
    double volume(Iterable<TrainingSetV2> values) =>
        values.fold<double>(0, (sum, set) => sum + set.weightKg * set.reps);
    return ExerciseHistoryPoint(
      recordId: record.id,
      operationDate: record.localDate,
      startTime: _exactStart(record),
      identity: TrainingExerciseIdentity.v2(exercise),
      maxWeight: sets.isEmpty
          ? null
          : sets.map<double>((set) => set.weightKg).reduce(mathMax),
      workingVolume: volume(main),
      recordedVolume: volume(sets),
      workingSetCount: main.length,
      recordedSetCount: sets.length,
      recordedReps: sets.fold<int>(0, (sum, set) => sum + set.reps),
      recordedRpeAverage: rpes.isEmpty
          ? null
          : rpes.reduce((a, b) => a + b) / rpes.length,
      recordedRpeMax: rpes.isEmpty ? null : rpes.reduce(_maxInt),
    );
  }

  List<int> _recordedRpes(TrainingRecordReadModel record) =>
      record.v2Data == null
      ? const []
      : [
          for (final exercise in record.v2Data!.exercises)
            for (final set in exercise.sets)
              if (set.rpe != null) set.rpe!,
        ];
  DateTime? _exactStart(TrainingRecordReadModel record) =>
      record.v2Data?.startTime == null
      ? null
      : DateTime.tryParse(record.v2Data!.startTime!);
  Duration? _duration(TrainingRecordReadModel record) {
    final start = _exactStart(record);
    final end = record.v2Data?.endTime == null
        ? null
        : DateTime.tryParse(record.v2Data!.endTime!);
    return start == null || end == null ? null : end.difference(start);
  }

  DateTime _historyTime(ExerciseHistoryPoint point) =>
      point.startTime ?? DateTime.parse(point.operationDate);
}

class _Exposure {
  const _Exposure(this.record, this.point);
  final TrainingRecordReadModel record;
  final ExerciseHistoryPoint point;
}

double mathMax(double a, double b) => a > b ? a : b;
int _maxInt(int a, int b) => a > b ? a : b;
