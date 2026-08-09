import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/models/training_v2_form_controller.dart';
import 'package:or_app/features/training/services/training_equipment_candidates.dart';
import 'package:or_app/features/training/services/training_v2_form_mapper.dart';

void main() {
  test('new form starts with one Main set and no cardio', () {
    final form = TrainingV2FormController.newSession(
      now: DateTime(2026, 7, 30, 12),
    );
    addTearDown(form.dispose);

    expect(form.exercises, hasLength(1));
    expect(form.exercises.single.sets.single.setType, TrainingSetType.main);
    expect(form.cardioEntries, isEmpty);
    expect(form.sessionGrade, isNull);
    expect(form.dynamicStretchCompleted, isNull);
    expect(form.cooldownStretchCompleted, isNull);
    expect(form.overallEvaluation.text, isEmpty);
    expect(form.exercises.single.evaluation.text, isEmpty);
    expect(form.exercises.single.targetReps, isEmpty);
  });

  test('session name accepts null and preserves a non-empty value', () {
    final unnamed = TrainingSessionV2(date: '2026-08-03', sessionName: null);
    final named = TrainingSessionV2(
      date: '2026-08-03',
      sessionName: 'Full Body',
    );

    expect(unnamed.sessionName, isNull);
    expect(named.sessionName, 'Full Body');
  });

  test('mapper normalizes an empty session name to null', () {
    final form = TrainingV2FormController.fromSession(_session());
    addTearDown(form.dispose);
    form.sessionName.text = '   ';

    final result = TrainingV2FormMapper.toDomain(form);

    expect(result.sessionName, isNull);
  });

  test('ADD SET inherits only set type and rest', () {
    final exercise = TrainingV2ExerciseFormController();
    addTearDown(exercise.dispose);
    exercise.sets.single
      ..setType = TrainingSetType.warmUp
      ..weight.text = '40'
      ..reps.text = '10'
      ..rpe = 7
      ..rest.text = '60';

    exercise.addSet();

    final added = exercise.sets.last;
    expect(added.setType, TrainingSetType.warmUp);
    expect(added.rest.text, '60');
    expect(added.weight.text, isEmpty);
    expect(added.reps.text, isEmpty);
    expect(added.rpe, isNull);
  });

  test('edit form restores every v2 field without inference', () {
    final source = _session();
    final form = TrainingV2FormController.fromSession(source);
    addTearDown(form.dispose);

    expect(form.sessionName.text, 'Upper');
    expect(form.sessionGrade, TrainingSessionGrade.a);
    expect(form.sessionMemo.text, 'Quality first');
    expect(form.dynamicStretchCompleted, isTrue);
    expect(form.cooldownStretchCompleted, isFalse);
    expect(form.overallEvaluation.text, 'Stable');
    final exercise = form.exercises.single;
    expect(exercise.equipment?.catalogId, 'power_rack');
    expect(exercise.sets.single.setType, TrainingSetType.main);
    expect(exercise.sets.single.rpe, 8);
    expect(exercise.sets.single.rest.text, '90');
    expect(exercise.evaluation.text, 'Good');
    expect(exercise.targetWeight.text, '85');
    expect(exercise.targetReps.map((value) => value.text), ['8', '8']);
    final cardio = form.cardioEntries.single;
    expect(cardio.duration.text, '1:30');
    expect(cardio.mets.text, '6.5');
    expect(cardio.averageHeartRate.text, '120');
    expect(cardio.maximumHeartRate.text, '145');
  });

  test('mapper creates complete normal v2 data and keeps calories null', () {
    final form = TrainingV2FormController.fromSession(_session());
    addTearDown(form.dispose);

    final result = TrainingV2FormMapper.toDomain(form);

    expect(result.toJson(), _session().toJson());
    final cardio = result.cardioEntries.single;
    expect(cardio.estimatedCaloriesKcal, isNull);
    expect(cardio.weightSnapshotKg, isNull);
    expect(cardio.calculationMethod, isNull);
    expect(cardio.calculationVersion, isNull);
    expect(cardio.legacyIntensity, isNull);
    expect(cardio.legacyReferenceCaloriesKcal, isNull);
    expect(result.hasLegacyUnknown, isFalse);
  });

  test('set-only edit preserves hidden evaluation and next target values', () {
    final form = TrainingV2FormController.fromSession(_session());
    addTearDown(form.dispose);
    form.exercises.single.sets.single.reps.text = '9';

    final result = TrainingV2FormMapper.toDomain(form);

    expect(result.overallEvaluation, 'Stable');
    expect(result.exercises.single.evaluation, 'Good');
    expect(result.exercises.single.nextTarget?.targetWeightKg, 85);
    expect(result.exercises.single.nextTarget?.targetReps, [8, 8]);
    expect(result.exercises.single.nextTarget?.notes, 'Control');
    expect(result.exercises.single.sets.single.reps, 9);
  });

  test('mapper skips untouched exercise when valid cardio exists', () {
    final form = TrainingV2FormController.newSession();
    addTearDown(form.dispose);
    final cardio = TrainingV2CardioFormController()
      ..purpose = CardioPurpose.cooldown
      ..type = CardioType.walking
      ..duration.text = '0:30';
    form.cardioEntries.add(cardio);

    final result = TrainingV2FormMapper.toDomain(form);

    expect(result.exercises, isEmpty);
    expect(result.cardioEntries.single.durationSeconds, 30);
  });

  test('duration accepts mm:ss and hh:mm:ss then rejects invalid formats', () {
    expect(TrainingV2FormMapper.parseDurationSeconds('12:34'), 754);
    expect(TrainingV2FormMapper.parseDurationSeconds('1:02:03'), 3723);
    for (final value in ['', '90', '1:60', '1:60:00', 'abc:10', '-1:10']) {
      expect(
        () => TrainingV2FormMapper.parseDurationSeconds(value),
        throwsA(isA<TrainingV2FormValidationException>()),
        reason: value,
      );
    }
  });

  test('average speed accepts decimal text and maps it before save', () {
    final form = TrainingV2FormController.newSession();
    addTearDown(form.dispose);
    final cardio = TrainingV2CardioFormController()
      ..purpose = CardioPurpose.main
      ..type = CardioType.running
      ..duration.text = '10:00'
      ..averageSpeed.text = '12.75';
    form.cardioEntries.add(cardio);

    final result = TrainingV2FormMapper.toDomain(form);

    expect(result.cardioEntries.single.durationSeconds, 600);
    expect(result.cardioEntries.single.averageSpeedKmh, 12.75);
  });

  test(
    'mapper preserves formal snapshot when calculation inputs are unchanged',
    () {
      final form = TrainingV2FormController.fromSession(_calculatedSession());
      addTearDown(form.dispose);
      form.cardioEntries.single.averageHeartRate.text = '130';

      final cardio = TrainingV2FormMapper.toDomain(form).cardioEntries.single;

      expect(cardio.weightSnapshotKg, 96.8);
      expect(cardio.estimatedCaloriesKcal, closeTo(33.88, 1e-12));
      expect(cardio.calculationMethod, 'metsAcsmV1');
      expect(cardio.calculationVersion, 1);
    },
  );

  test('mapper clears stale calories but retains weight when METs changes', () {
    final form = TrainingV2FormController.fromSession(_calculatedSession());
    addTearDown(form.dispose);
    form.cardioEntries.single.mets.text = '5';

    final cardio = TrainingV2FormMapper.toDomain(form).cardioEntries.single;

    expect(cardio.weightSnapshotKg, 96.8);
    expect(cardio.estimatedCaloriesKcal, isNull);
    expect(cardio.calculationMethod, isNull);
    expect(cardio.calculationVersion, isNull);
  });

  test('mapper rejects invalid set and target values', () {
    final form = TrainingV2FormController.newSession();
    addTearDown(form.dispose);
    final exercise = form.exercises.single
      ..exerciseName.text = 'Squat'
      ..targetReps.addAll([]);
    exercise.sets.single
      ..weight.text = '80'
      ..reps.text = '0';

    expect(
      () => TrainingV2FormMapper.toDomain(form),
      throwsA(isA<TrainingV2FormValidationException>()),
    );

    exercise.sets.single.reps.text = '5';
    exercise.addTargetRep();
    exercise.targetReps.single.text = '-1';
    expect(
      () => TrainingV2FormMapper.toDomain(form),
      throwsA(isA<TrainingV2FormValidationException>()),
    );
  });

  test('mapper rejects invalid rest, RPE, and heart-rate order', () {
    final form = TrainingV2FormController.fromSession(_session());
    addTearDown(form.dispose);

    form.exercises.single.sets.single.rest.text = '-1';
    expect(
      () => TrainingV2FormMapper.toDomain(form),
      throwsA(isA<TrainingV2FormValidationException>()),
    );

    form.exercises.single.sets.single.rest.text = '90';
    form.exercises.single.sets.single.rpe = 11;
    expect(
      () => TrainingV2FormMapper.toDomain(form),
      throwsA(isA<TrainingV2FormValidationException>()),
    );

    form.exercises.single.sets.single.rpe = 8;
    form.cardioEntries.single.maximumHeartRate.text = '100';
    expect(
      () => TrainingV2FormMapper.toDomain(form),
      throwsA(isA<TrainingV2FormValidationException>()),
    );
  });

  test('equipment candidates merge catalog and history deterministically', () {
    final custom = TrainingEquipmentSnapshot(name: 'Custom Handle');
    final record = TrainingRecordReadModel.v2(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
      data: TrainingSessionV2(
        date: '2026-07-30T12:00:00',
        exercises: [
          TrainingExerciseV2(
            exerciseName: 'Press',
            order: 1,
            equipment: custom,
            sets: const [],
          ),
        ],
        cardioEntries: [
          CardioEntryV2(
            purpose: CardioPurpose.main,
            type: CardioType.running,
            equipment: custom,
            durationSeconds: 60,
          ),
        ],
      ),
    );

    final values = TrainingEquipmentCandidates.forExercise(
      exerciseName: 'Press',
      preferredRecords: [record],
    ).values;

    expect(
      values.where((value) => value.name == 'Custom Handle'),
      hasLength(1),
    );
    expect(values.any((value) => value.catalogId != null), isFalse);
  });
}

TrainingSessionV2 _session() {
  return TrainingSessionV2(
    date: '2026-07-30T18:00:00+09:00',
    sessionName: 'Upper',
    sessionGrade: TrainingSessionGrade.a,
    memo: 'Quality first',
    dynamicStretchCompleted: true,
    cooldownStretchCompleted: false,
    overallEvaluation: 'Stable',
    exercises: [
      TrainingExerciseV2(
        exerciseName: 'Bench Press',
        order: 1,
        equipment: TrainingEquipmentSnapshot(
          catalogId: 'power_rack',
          name: 'Power Rack',
        ),
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.main,
            weightKg: 82.5,
            reps: 8,
            rpe: 8,
            restAfterSeconds: 90,
          ),
        ],
        evaluation: 'Good',
        nextTarget: TrainingNextTarget(
          targetWeightKg: 85,
          targetReps: const [8, 8],
          notes: 'Control',
        ),
      ),
    ],
    cardioEntries: [
      CardioEntryV2(
        purpose: CardioPurpose.cooldown,
        type: CardioType.running,
        equipment: TrainingEquipmentSnapshot(name: 'Custom Treadmill'),
        durationSeconds: 90,
        distanceKm: 0.3,
        mets: 6.5,
        averageHeartRateBpm: 120,
        maximumHeartRateBpm: 145,
        averageSpeedKmh: 12,
        notes: 'Easy',
      ),
    ],
  );
}

TrainingSessionV2 _calculatedSession() {
  return TrainingSessionV2(
    date: '2026-07-30T18:00:00+09:00',
    cardioEntries: [
      CardioEntryV2(
        purpose: CardioPurpose.main,
        type: CardioType.running,
        durationSeconds: 300,
        mets: 4,
        averageHeartRateBpm: 120,
        weightSnapshotKg: 96.8,
        estimatedCaloriesKcal: 33.88,
        calculationMethod: 'metsAcsmV1',
        calculationVersion: 1,
      ),
    ],
  );
}
