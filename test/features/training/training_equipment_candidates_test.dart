import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/services/training_equipment_candidates.dart';

void main() {
  test('exercise candidates combine compatible and same-exercise history', () {
    final candidates = TrainingEquipmentCandidates.forExercise(
      exerciseName: 'Bench Press',
      preferredRecords: [
        _v2Record(
          id: 'same',
          exerciseName: 'BenchPress',
          equipment: TrainingEquipmentSnapshot(name: 'Custom Bench'),
        ),
        _v2Record(
          id: 'other',
          exerciseName: 'LegPress',
          equipment: TrainingEquipmentSnapshot(name: 'Leg Custom'),
        ),
        _v1Record(),
      ],
    );

    expect(
      candidates.values.map((value) => value.catalogId),
      containsAll(['power_rack', 'bench_press_rack', 'smith_machine']),
    );
    expect(
      candidates.values.map((value) => value.name),
      contains('Custom Bench'),
    );
    expect(
      candidates.values.map((value) => value.name),
      isNot(contains('Leg Custom')),
    );
    expect(
      candidates.values.map((value) => value.catalogId),
      isNot(contains('cable_machine')),
    );
  });

  test('custom exercise receives only its own preferred history', () {
    final candidates = TrainingEquipmentCandidates.forExercise(
      exerciseName: 'My Press',
      preferredRecords: [
        _v2Record(
          id: 'one',
          exerciseName: 'My Press',
          equipment: TrainingEquipmentSnapshot(name: 'Blue Handle'),
        ),
        _v2Record(
          id: 'duplicate',
          exerciseName: ' my  press ',
          equipment: TrainingEquipmentSnapshot(name: ' blue handle '),
        ),
      ],
    );

    expect(candidates.values, hasLength(1));
    expect(candidates.values.single.name, 'Blue Handle');
  });

  test(
    'unknown custom labels remain unchanged while catalog labels localize',
    () {
      expect(
        trainingEquipmentDisplayLabel(
          TrainingEquipmentSnapshot(
            catalogId: 'power_rack',
            name: 'Power Rack',
          ),
        ),
        'パワーラック',
      );
      expect(
        trainingEquipmentDisplayLabel(
          TrainingEquipmentSnapshot(name: 'Custom Handle'),
        ),
        'Custom Handle',
      );
    },
  );

  test('exercise without a selection exposes no global candidates', () {
    final candidates = TrainingEquipmentCandidates.forExercise(
      exerciseName: '',
      preferredRecords: [
        _v2Record(
          id: 'one',
          exerciseName: 'Bench Press',
          equipment: TrainingEquipmentSnapshot(name: 'Custom Handle'),
        ),
      ],
    );

    expect(candidates.values, isEmpty);
  });
}

TrainingRecordReadModel _v2Record({
  required String id,
  required String exerciseName,
  required TrainingEquipmentSnapshot equipment,
}) {
  return TrainingRecordReadModel.v2(
    id: id,
    localDate: '2026-07-30',
    createdAt: DateTime.utc(2026, 7, 30),
    updatedAt: DateTime.utc(2026, 7, 30),
    data: TrainingSessionV2(
      date: '2026-07-30T12:00:00Z',
      exercises: [
        TrainingExerciseV2(
          exerciseName: exerciseName,
          order: 1,
          equipment: equipment,
          sets: const [],
        ),
      ],
    ),
  );
}

TrainingRecordReadModel _v1Record() {
  return TrainingRecordReadModel.v1(
    id: 'v1',
    localDate: '2026-07-30',
    createdAt: DateTime.utc(2026, 7, 30),
    updatedAt: DateTime.utc(2026, 7, 30),
    data: TrainingSession(
      date: '2026-07-30T10:00:00Z',
      memo: '',
      exercises: [
        TrainingExercise(
          exerciseName: 'Bench Press',
          order: 1,
          equipmentId: 'cable_machine',
          sets: const [],
        ),
      ],
    ),
  );
}
