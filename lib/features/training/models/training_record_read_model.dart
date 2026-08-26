import '../../../core/models/cardio_entry.dart';
import '../../../core/models/training_exercise.dart';
import '../../../core/models/training_session.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set.dart';

class TrainingRecordReadModel {
  static final Expando<bool> _readOnlyProjections = Expando<bool>(
    'trainingV2ReadOnlyProjection',
  );

  final String id;
  final int recordVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?>? migrationSource;
  final TrainingSession? v1Data;
  final TrainingSessionV2? v2Data;

  TrainingRecordReadModel.v1({
    required this.id,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required TrainingSession data,
  }) : recordVersion = 1,
       v1Data = _copyV1(data),
       v2Data = null;

  TrainingRecordReadModel.v2({
    required this.id,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required TrainingSessionV2 data,
  }) : recordVersion = 2,
       v1Data = null,
       v2Data = data;

  String get sessionDate => v1Data?.date ?? v2Data!.date;

  String? get displaySessionName => v2Data?.sessionName;

  String get memo => v1Data?.memo ?? v2Data?.memo ?? '';

  int get exerciseCount => v1Data?.exercises.length ?? v2Data!.exercises.length;

  int get setCount =>
      v1Data?.exercises.fold<int>(
        0,
        (sum, exercise) => sum + exercise.sets.length,
      ) ??
      v2Data!.exercises.fold<int>(
        0,
        (sum, exercise) => sum + exercise.sets.length,
      );

  int get cardioEntryCount =>
      v1Data?.cardioEntries.length ?? v2Data!.cardioEntries.length;

  bool get strengthTrainingPerformed => exerciseCount > 0;

  bool get cardioPerformed => cardioEntryCount > 0;

  bool get isLegacy => migrationSource != null;

  bool get isEditable => recordVersion == 2 && migrationSource == null;

  DateTime get sortDateTime =>
      DateTime.tryParse(sessionDate) ??
      DateTime.tryParse(localDate) ??
      createdAt;

  TrainingSession toCompatibilityProjection() {
    final legacy = v1Data;
    if (legacy != null) return _copyV1(legacy);

    final current = v2Data!;
    final projectedCardio = <CardioEntry>[];
    for (final entry in current.cardioEntries) {
      final intensity = _compatibilityIntensity(entry.legacyIntensity);
      if (intensity == null) continue;
      projectedCardio.add(
        CardioEntry(
          type: entry.type,
          intensity: intensity,
          durationMinutes: (entry.durationSeconds / 60).ceil(),
          distanceKm: entry.distanceKm,
          notes: entry.notes,
        ),
      );
    }
    final projection = TrainingSession(
      date: current.date,
      memo: current.memo ?? '',
      exercises: [
        for (final exercise in current.exercises)
          TrainingExercise(
            exerciseName: exercise.exerciseName,
            order: exercise.order,
            equipmentId: exercise.equipment?.catalogId,
            sets: [
              for (final set in exercise.sets)
                TrainingSet(
                  setNo: set.setNo,
                  weight: set.weightKg,
                  reps: set.reps,
                ),
            ],
          ),
      ],
      cardioEntries: projectedCardio,
    );
    _readOnlyProjections[projection] = true;
    return projection;
  }

  static bool isReadOnlyProjection(TrainingSession session) {
    return _readOnlyProjections[session] ?? false;
  }

  static TrainingSession _copyV1(TrainingSession session) {
    return TrainingSession.fromJson(
      Map<String, dynamic>.from(_copyMap(session.toJson())),
    );
  }

  static CardioIntensity? _compatibilityIntensity(String? value) {
    return switch (value) {
      'light' => CardioIntensity.light,
      'moderate' => CardioIntensity.moderate,
      'vigorous' => CardioIntensity.vigorous,
      _ => null,
    };
  }

  static Map<String, Object?> _copyMap(Map source) {
    return {
      for (final entry in source.entries)
        entry.key.toString(): _copyValue(entry.value),
    };
  }

  static Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) return [for (final item in value) _copyValue(item)];
    return value;
  }
}

class TrainingRecord {
  final TrainingRecordReadModel readModel;

  const TrainingRecord._(this.readModel);

  factory TrainingRecord.fromReadModel(TrainingRecordReadModel readModel) {
    return TrainingRecord._(readModel);
  }

  factory TrainingRecord({
    required String id,
    required TrainingSession session,
  }) {
    final timestamp = DateTime.tryParse(session.date) ?? DateTime(1970);
    return TrainingRecord._(
      TrainingRecordReadModel.v1(
        id: id,
        localDate: session.date.substring(0, 10),
        createdAt: timestamp,
        updatedAt: timestamp,
        data: session,
      ),
    );
  }

  String get id => readModel.id;

  int get recordVersion => readModel.recordVersion;

  String get localDate => readModel.localDate;

  bool get isEditable => readModel.isEditable;

  TrainingSession get session => readModel.toCompatibilityProjection();
}
