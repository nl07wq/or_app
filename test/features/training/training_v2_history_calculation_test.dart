import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/progression_result.dart';
import 'package:or_app/features/training/services/training_exercise_identity.dart';
import 'package:or_app/features/training/services/training_v2_personal_record_service.dart';
import 'package:or_app/features/training/services/training_v2_previous_service.dart';
import 'package:or_app/features/training/services/training_v2_progression_service.dart';

import 'training_v2_calculation_test_fixture.dart';

void main() {
  final nextTarget = TrainingNextTarget(
    targetWeightKg: 105,
    targetReps: const [8, 8],
    notes: 'Keep form',
  );
  final first = v2Record(
    id: 'training:00000000-0000-4000-8000-000000000001',
    createdAt: DateTime.utc(2026, 7, 30, 8),
    exercises: [
      v2Exercise(
        nextTarget: nextTarget,
        sets: [
          v2Set(setNo: 1, type: TrainingSetType.warmUp, weight: 150, reps: 20),
          v2Set(
            setNo: 2,
            type: TrainingSetType.main,
            weight: 100,
            reps: 10,
            rpe: 9,
            rest: 120,
          ),
        ],
      ),
    ],
  );
  final second = v2Record(
    id: 'training:00000000-0000-4000-8000-000000000002',
    createdAt: DateTime.utc(2026, 7, 30, 10),
    exercises: [
      v2Exercise(
        sets: [
          v2Set(setNo: 1, type: TrainingSetType.main, weight: 102.5, reps: 8),
          v2Set(
            setNo: 2,
            type: TrainingSetType.legacyUnknown,
            weight: 200,
            reps: 20,
          ),
        ],
      ),
    ],
  );
  final otherEquipment = v2Record(
    id: 'training:00000000-0000-4000-8000-000000000003',
    createdAt: DateTime.utc(2026, 7, 29),
    localDate: '2026-07-29',
    exercises: [
      v2Exercise(
        equipmentId: 'smith_machine',
        equipmentName: 'Smith Machine',
        sets: [
          v2Set(setNo: 1, type: TrainingSetType.main, weight: 300, reps: 20),
        ],
      ),
    ],
  );
  final records = [second, first, otherEquipment];
  final identity = TrainingExerciseIdentity.v2(second.v2Data!.exercises.single);

  test('PR uses Main Sets and matching Exercise plus Equipment', () {
    final result = TrainingV2PersonalRecordService.find(
      preferredRecords: records,
      identity: identity,
    );

    expect(result?.weightKg, 102.5);
    expect(result?.reps, 8);
    expect(result?.recordId, second.id);
    expect(result?.localDate, second.localDate);
  });

  test('Previous selects the prior same-day session and excludes self', () {
    final result = TrainingV2PreviousService.find(
      preferredRecords: records,
      targetRecord: second,
      identity: identity,
    );

    expect(result?.record.id, first.id);
    expect(result?.statistics.topSet?.weightKg, 100);
    expect(result?.statistics.topSet?.reps, 10);
  });

  test('Progression uses the previous Main Set and preserves Next Target', () {
    final before = first.v2Data!.exercises.single.nextTarget!.toJson();

    final result = TrainingV2ProgressionService.forRecord(
      preferredRecords: records,
      targetRecord: second,
      identity: identity,
    );

    expect(result?.recommendation, ProgressionRecommendation.increaseWeight);
    expect(result?.suggestedWeight, 102.5);
    expect(first.v2Data!.exercises.single.nextTarget!.toJson(), before);
    expect(
      first.v2Data!.exercises.single.sets
          .singleWhere((set) => set.setType == TrainingSetType.main)
          .rpe,
      9,
    );
  });

  test('Progression rejects Warm-up and legacyUnknown reference sets', () {
    for (final type in [
      TrainingSetType.warmUp,
      TrainingSetType.legacyUnknown,
    ]) {
      expect(
        () => TrainingV2ProgressionService.evaluate(
          v2Set(setNo: 1, type: type, weight: 50, reps: 10),
        ),
        throwsArgumentError,
      );
    }
  });
}
