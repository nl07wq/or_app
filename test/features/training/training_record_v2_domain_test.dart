import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';

void main() {
  group('record versions', () {
    test('v1 decode and round trip preserve every legacy field', () {
      final record = PersistedTrainingRecord(
        id: _id,
        localDate: '2026-07-29',
        createdAt: _createdAt,
        updatedAt: _updatedAt,
        migrationSource: _migrationSource,
        data: _legacySession(),
      );

      final restored = PersistedTrainingRecord.fromRecord(record.toRecord());

      expect(restored.recordVersion, 1);
      expect(restored.id, _id);
      expect(restored.localDate, '2026-07-29');
      expect(restored.createdAt, _createdAt);
      expect(restored.updatedAt, _updatedAt);
      expect(restored.migrationSource?.migrationId, 'legacy-v1');
      expect(restored.data.toJson(), _legacySession().toJson());
      expect(restored.data.memo, 'legacy memo');
      expect(restored.data.exercises.single.equipmentId, 'power-rack');
      expect(restored.data.exercises.single.sets.single.weight, 82.5);
      expect(
        restored.data.cardioEntries.single.intensity,
        CardioIntensity.vigorous,
      );
      expect(restored.data.cardioEntries.single.estimatedCalories, 321.5);
      expect(() => restored.dataV2, throwsStateError);
      expect(record.toRecord(), restored.toRecord());
    });

    test('v2 decode and round trip preserve all fields and envelope', () {
      final record = PersistedTrainingRecord.v2(
        id: _id,
        localDate: '2026-07-29',
        createdAt: _createdAt,
        updatedAt: _updatedAt,
        migrationSource: _migrationSource,
        data: _completeSession(),
      );

      final restored = PersistedTrainingRecord.fromRecord(record.toRecord());

      expect(restored.recordVersion, 2);
      expect(restored.id, _id);
      expect(restored.localDate, '2026-07-29');
      expect(restored.createdAt, _createdAt);
      expect(restored.updatedAt, _updatedAt);
      expect(restored.migrationSource?.duplicateOrdinal, 2);
      expect(restored.dataV2.toJson(), _completeSession().toJson());
      expect(restored.versionedData, isA<TrainingSessionV2>());
      expect(restored.sessionDate, '2026-07-29T18:30:00+09:00');
      expect(() => restored.data, throwsStateError);
      expect(record.toRecord(), restored.toRecord());
    });

    test('unknown version and invalid envelope data are rejected', () {
      final record = PersistedTrainingRecord(
        id: _id,
        localDate: '2026-07-29',
        createdAt: _createdAt,
        updatedAt: _updatedAt,
        data: _legacySession(),
      ).toRecord();

      expect(
        () => PersistedTrainingRecord.fromRecord({
          ...record,
          'recordVersion': 99,
        }),
        throwsFormatException,
      );
      expect(
        () => PersistedTrainingRecord.fromRecord({...record, 'data': 'bad'}),
        throwsFormatException,
      );
      expect(
        () => PersistedTrainingRecord.v2(
          id: _id,
          localDate: '2026-07-28',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
          data: _completeSession(),
        ),
        throwsFormatException,
      );
    });

    test('production write version remains v1', () {
      expect(PersistedTrainingRecord.currentRecordVersion, 1);
      expect(PersistedTrainingRecord.version2RecordVersion, 2);
    });
  });

  group('session grade and session v2', () {
    test('all nine grades keep stable IDs and display labels', () {
      expect(TrainingSessionGrade.values.map((grade) => grade.stableId), [
        'sPlus',
        's',
        'sMinus',
        'aPlus',
        'a',
        'aMinus',
        'bPlus',
        'b',
        'bMinus',
      ]);
      expect(TrainingSessionGrade.values.map((grade) => grade.displayLabel), [
        'S+',
        'S',
        'S-',
        'A+',
        'A',
        'A-',
        'B+',
        'B',
        'B-',
      ]);
      for (final grade in TrainingSessionGrade.values) {
        expect(TrainingSessionGrade.fromStableId(grade.stableId), grade);
      }
      expect(
        () => TrainingSessionGrade.fromStableId('gold'),
        throwsFormatException,
      );
    });

    test('null fields, empty lists, and trim normalization round trip', () {
      final session = TrainingSessionV2(
        date: '2026-07-29',
        sessionName: ' ',
        memo: '',
        overallEvaluation: '  ',
      );

      final restored = TrainingSessionV2.fromJson(session.toJson());

      expect(restored.sessionName, isNull);
      expect(restored.sessionGrade, isNull);
      expect(restored.memo, isNull);
      expect(restored.dynamicStretchCompleted, isNull);
      expect(restored.cooldownStretchCompleted, isNull);
      expect(restored.overallEvaluation, isNull);
      expect(restored.exercises, isEmpty);
      expect(restored.cardioEntries, isEmpty);
    });

    test('unknown grade and duplicate exercise order are rejected', () {
      final json = _completeSession().toJson();
      expect(
        () => TrainingSessionV2.fromJson({...json, 'sessionGrade': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => TrainingSessionV2(
          date: '2026-07-29',
          exercises: [
            _exercise(order: 1),
            _exercise(order: 1, exerciseName: 'Squat'),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('equipment, exercise, and next target', () {
    test('equipment keeps optional and unknown catalog IDs with name', () {
      final known = TrainingEquipmentSnapshot(
        catalogId: 'power-rack',
        name: ' Power Rack ',
      );
      final unknown = TrainingEquipmentSnapshot(
        catalogId: 'future-device',
        name: 'Future Device',
      );
      final noId = TrainingEquipmentSnapshot(name: 'Dumbbell');

      expect(
        TrainingEquipmentSnapshot.fromJson(known.toJson()).name,
        'Power Rack',
      );
      expect(
        TrainingEquipmentSnapshot.fromJson(unknown.toJson()).catalogId,
        'future-device',
      );
      expect(
        TrainingEquipmentSnapshot.fromJson(noId.toJson()).catalogId,
        isNull,
      );
      expect(() => TrainingEquipmentSnapshot(name: '  '), throwsArgumentError);
    });

    test('next target round trips weights, reps, and notes', () {
      final target = TrainingNextTarget(
        targetWeightKg: 0,
        targetReps: const [10, 8, 6],
        notes: '  Keep tempo  ',
      );

      final restored = TrainingNextTarget.fromJson(target.toJson());

      expect(restored.targetWeightKg, 0);
      expect(restored.targetReps, [10, 8, 6]);
      expect(restored.notes, 'Keep tempo');
      expect(TrainingNextTarget().targetReps, isEmpty);
      expect(
        () => TrainingNextTarget(targetReps: const [8, 0]),
        throwsArgumentError,
      );
      expect(
        () => TrainingNextTarget(targetWeightKg: double.nan),
        throwsArgumentError,
      );
    });

    test('exercise validates name, order, and unique set numbers', () {
      expect(
        () => TrainingExerciseV2(exerciseName: ' ', order: 1),
        throwsArgumentError,
      );
      expect(
        () => TrainingExerciseV2(exerciseName: 'Squat', order: 0),
        throwsArgumentError,
      );
      expect(
        () => TrainingExerciseV2(
          exerciseName: 'Squat',
          order: 1,
          sets: [
            _set(setNo: 1),
            _set(setNo: 1, setType: TrainingSetType.warmUp),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('set v2', () {
    test('warm-up and main support boundary values and round trip', () {
      final warmUp = TrainingSetV2(
        setNo: 1,
        setType: TrainingSetType.warmUp,
        weightKg: 0,
        reps: 1,
        rpe: 1,
        restAfterSeconds: 0,
      );
      final main = TrainingSetV2(
        setNo: 2,
        setType: TrainingSetType.main,
        weightKg: 82.5,
        reps: 8,
        rpe: 10,
      );

      expect(TrainingSetV2.fromJson(warmUp.toJson()).toJson(), warmUp.toJson());
      expect(TrainingSetV2.fromJson(main.toJson()).toJson(), main.toJson());
      expect(main.restAfterSeconds, isNull);
    });

    test('legacyUnknown is migration-only and has a stable ID', () {
      expect(TrainingSetType.legacyUnknown.stableId, 'legacyUnknown');
      expect(
        () => TrainingSetV2(
          setNo: 1,
          setType: TrainingSetType.legacyUnknown,
          weightKg: 20,
          reps: 10,
        ),
        throwsArgumentError,
      );
      final migrated = TrainingSetV2.forMigration(
        setNo: 1,
        setType: TrainingSetType.legacyUnknown,
        weightKg: 20,
        reps: 10,
      );
      expect(
        TrainingSetV2.fromMigrationJson(migrated.toJson()).setType,
        TrainingSetType.legacyUnknown,
      );
      expect(
        () => TrainingSetType.fromStableId('working'),
        throwsFormatException,
      );
    });

    test('invalid numeric values are rejected', () {
      expect(() => _set(setNo: 0), throwsArgumentError);
      expect(() => _set(weightKg: -1), throwsArgumentError);
      expect(() => _set(weightKg: double.infinity), throwsArgumentError);
      expect(() => _set(reps: 0), throwsArgumentError);
      expect(() => _set(rpe: 0), throwsArgumentError);
      expect(() => _set(rpe: 11), throwsArgumentError);
      expect(() => _set(restAfterSeconds: -1), throwsArgumentError);
    });
  });

  group('cardio v2', () {
    test('all fields and purposes round trip', () {
      for (final purpose in const [
        CardioPurpose.warmUp,
        CardioPurpose.main,
        CardioPurpose.cooldown,
      ]) {
        final entry = _cardio(purpose: purpose);
        final restored = CardioEntryV2.fromJson(entry.toJson());
        expect(restored.toJson(), entry.toJson());
        expect(restored.equipment?.name, 'Treadmill');
        expect(restored.durationSeconds, 1800);
        expect(restored.mets, 8.3);
        expect(restored.averageHeartRateBpm, 145);
        expect(restored.maximumHeartRateBpm, 172);
        expect(restored.averageSpeedKmh, 10.5);
        expect(restored.estimatedCaloriesKcal, 410.25);
        expect(restored.weightSnapshotKg, 96.8);
        expect(restored.calculationMethod, 'metsAcsmV1');
        expect(restored.calculationVersion, 1);
        expect(restored.notes, 'Intervals');
        expect(restored.legacyIntensity, 'vigorous');
        expect(restored.legacyReferenceCaloriesKcal, 400);
      }
    });

    test('legacy purpose is migration-only', () {
      expect(
        () => _cardio(purpose: CardioPurpose.legacyUnknown),
        throwsArgumentError,
      );
      final migrated = CardioEntryV2.forMigration(
        purpose: CardioPurpose.legacyUnknown,
        type: CardioType.walking,
        durationSeconds: 60,
        legacyIntensity: 'moderate',
      );
      expect(
        CardioEntryV2.fromMigrationJson(migrated.toJson()).purpose,
        CardioPurpose.legacyUnknown,
      );
      expect(
        () => CardioPurpose.fromStableId('recovery'),
        throwsFormatException,
      );
    });

    test('duration, heart rate, and finite validations reject bad data', () {
      expect(() => _cardio(durationSeconds: 0), throwsArgumentError);
      expect(() => _cardio(mets: 0), throwsArgumentError);
      expect(() => _cardio(mets: double.nan), throwsArgumentError);
      expect(() => _cardio(distanceKm: -1), throwsArgumentError);
      expect(
        () => _cardio(averageHeartRateBpm: 150, maximumHeartRateBpm: 149),
        throwsArgumentError,
      );
      expect(() => _cardio(averageHeartRateBpm: 0), throwsArgumentError);
      expect(() => _cardio(calculationVersion: 0), throwsArgumentError);
      expect(
        () => _cardio(estimatedCaloriesKcal: double.infinity),
        throwsArgumentError,
      );
      expect(() => _cardio(weightSnapshotKg: 0), throwsArgumentError);
      expect(
        () => CardioEntryV2.fromJson({..._cardio().toJson(), 'type': 'rowing'}),
        throwsFormatException,
      );
    });
  });

  group('migration validation mode', () {
    test(
      'normal v2 rejects legacy values while migration envelope keeps them',
      () {
        final legacySet = TrainingSetV2.forMigration(
          setNo: 1,
          setType: TrainingSetType.legacyUnknown,
          weightKg: 40,
          reps: 10,
        );
        final exercise = TrainingExerciseV2.forMigration(
          exerciseName: 'Legacy Press',
          order: 1,
          sets: [legacySet],
        );
        final cardio = CardioEntryV2.forMigration(
          purpose: CardioPurpose.legacyUnknown,
          type: CardioType.exerciseBike,
          durationSeconds: 1200,
          legacyIntensity: 'moderate',
          legacyReferenceCaloriesKcal: 180,
        );
        final session = TrainingSessionV2.forMigration(
          date: '2026-07-29',
          exercises: [exercise],
          cardioEntries: [cardio],
        );

        expect(
          () => PersistedTrainingRecord.v2(
            id: _id,
            localDate: '2026-07-29',
            createdAt: _createdAt,
            updatedAt: _updatedAt,
            data: session,
          ),
          throwsArgumentError,
        );
        final migrated = PersistedTrainingRecord.v2ForMigration(
          id: _id,
          localDate: '2026-07-29',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
          migrationSource: _migrationSource,
          data: session,
        );
        final restored = PersistedTrainingRecord.fromRecord(
          migrated.toRecord(),
        );
        expect(
          restored.dataV2.exercises.single.sets.single.setType,
          TrainingSetType.legacyUnknown,
        );
        expect(
          restored.dataV2.cardioEntries.single.purpose,
          CardioPurpose.legacyUnknown,
        );
        final withoutMigrationSource = migrated.toRecord()
          ..remove('migrationSource');
        expect(
          () => PersistedTrainingRecord.fromRecord(withoutMigrationSource),
          throwsArgumentError,
        );
      },
    );
  });
}

const _id = 'training:00112233-4455-4677-8899-aabbccddeeff';
final _createdAt = DateTime.utc(2026, 7, 29, 9);
final _updatedAt = DateTime.utc(2026, 7, 29, 10);
const _migrationSource = TrainingMigrationSource(
  migrationId: 'legacy-v1',
  sourceSystem: 'sharedPreferences',
  sourceKey: 'training_sessions',
  sourceIndex: 4,
  duplicateOrdinal: 2,
);

TrainingSession _legacySession() => TrainingSession(
  date: '2026-07-29T18:30:00+09:00',
  memo: 'legacy memo',
  exercises: const [
    TrainingExercise(
      exerciseName: 'Bench Press',
      order: 0,
      equipmentId: 'power-rack',
      sets: [TrainingSet(setNo: 1, weight: 82.5, reps: 8)],
    ),
  ],
  cardioEntries: [
    CardioEntry(
      type: CardioType.running,
      intensity: CardioIntensity.vigorous,
      durationMinutes: 30,
      distanceKm: 5,
      notes: 'legacy cardio',
      estimatedCalories: 321.5,
    ),
  ],
);

TrainingSessionV2 _completeSession() => TrainingSessionV2(
  date: '2026-07-29T18:30:00+09:00',
  startTime: '2026-07-29T18:30:00+09:00',
  endTime: '2026-07-29T20:30:00+09:00',
  sessionName: 'Upper Body',
  sessionGrade: TrainingSessionGrade.aPlus,
  memo: 'Before session',
  dynamicStretchCompleted: true,
  cooldownStretchCompleted: false,
  overallEvaluation: 'Good control\nNo pain',
  estimatedStrengthCaloriesKcal: 355.74,
  strengthWeightSnapshotKg: 96.8,
  strengthCalculationMethod: 'strengthSessionMetsAcsmV1',
  strengthCalculationVersion: 1,
  exercises: [
    _exercise(order: 1),
    _exercise(order: 2, exerciseName: 'Squat'),
  ],
  cardioEntries: [
    _cardio(purpose: CardioPurpose.warmUp),
    _cardio(purpose: CardioPurpose.cooldown),
  ],
);

TrainingExerciseV2 _exercise({
  int order = 1,
  String exerciseName = 'Bench Press',
}) => TrainingExerciseV2(
  exerciseName: exerciseName,
  order: order,
  equipment: TrainingEquipmentSnapshot(
    catalogId: 'power-rack',
    name: 'Power Rack',
  ),
  sets: [
    _set(setNo: 1, setType: TrainingSetType.warmUp, weightKg: 20, reps: 12),
    _set(setNo: 2, rpe: 8, restAfterSeconds: 120),
  ],
  evaluation: 'Stable',
  nextTarget: TrainingNextTarget(
    targetWeightKg: 85,
    targetReps: const [8, 8],
    notes: 'Add weight',
  ),
);

TrainingSetV2 _set({
  int setNo = 1,
  TrainingSetType setType = TrainingSetType.main,
  double weightKg = 80,
  int reps = 8,
  int? rpe,
  int? restAfterSeconds,
}) => TrainingSetV2(
  setNo: setNo,
  setType: setType,
  weightKg: weightKg,
  reps: reps,
  rpe: rpe,
  restAfterSeconds: restAfterSeconds,
);

CardioEntryV2 _cardio({
  CardioPurpose purpose = CardioPurpose.main,
  int durationSeconds = 1800,
  double? distanceKm = 5.25,
  double? mets = 8.3,
  int? averageHeartRateBpm = 145,
  int? maximumHeartRateBpm = 172,
  double? averageSpeedKmh = 10.5,
  double? estimatedCaloriesKcal = 410.25,
  double? weightSnapshotKg = 96.8,
  int? calculationVersion = 1,
}) => CardioEntryV2(
  purpose: purpose,
  type: CardioType.treadmillRunning,
  equipment: TrainingEquipmentSnapshot(
    catalogId: 'treadmill',
    name: 'Treadmill',
  ),
  durationSeconds: durationSeconds,
  distanceKm: distanceKm,
  mets: mets,
  averageHeartRateBpm: averageHeartRateBpm,
  maximumHeartRateBpm: maximumHeartRateBpm,
  averageSpeedKmh: averageSpeedKmh,
  estimatedCaloriesKcal: estimatedCaloriesKcal,
  weightSnapshotKg: weightSnapshotKg,
  calculationMethod: 'metsAcsmV1',
  calculationVersion: calculationVersion,
  notes: 'Intervals',
  legacyIntensity: 'vigorous',
  legacyReferenceCaloriesKcal: 400,
);
