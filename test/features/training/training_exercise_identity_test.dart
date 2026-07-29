import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/services/training_exercise_identity.dart';

import 'training_v2_calculation_test_fixture.dart';

void main() {
  test('matches exercise and the same catalog ID across v1 and v2', () {
    final v1 = TrainingExerciseIdentity.fromV1(
      exerciseName: ' Bench   Press ',
      equipmentId: 'POWER_RACK',
    );
    final v2 = TrainingExerciseIdentity.v2(
      v2Exercise(name: 'bench press', equipmentId: 'power_rack'),
    );

    expect(v1, v2);
  });

  test('matches normalized equipment names when both are v2 snapshots', () {
    final first = TrainingExerciseIdentity.v2(
      v2Exercise(equipmentId: null, equipmentName: ' Cable  Machine '),
    );
    final second = TrainingExerciseIdentity.v2(
      v2Exercise(equipmentId: null, equipmentName: 'cable machine'),
    );

    expect(first, second);
  });

  test('keeps different equipment separate', () {
    final rack = TrainingExerciseIdentity.v2(
      v2Exercise(equipmentId: 'power_rack'),
    );
    final smith = TrainingExerciseIdentity.v2(
      v2Exercise(equipmentId: 'smith_machine'),
    );

    expect(rack, isNot(smith));
  });

  test('matches no-equipment exercises', () {
    expect(
      TrainingExerciseIdentity.fromV1(exerciseName: 'Squat', equipmentId: null),
      TrainingExerciseIdentity.v2(
        v2Exercise(name: 'squat', equipmentId: null, equipmentName: null),
      ),
    );
  });

  test('normalizes case and whitespace but not different exercises', () {
    final bench = TrainingExerciseIdentity.v2(
      v2Exercise(name: ' Bench   Press '),
    );
    expect(bench, TrainingExerciseIdentity.v2(v2Exercise(name: 'bench press')));
    expect(
      bench,
      isNot(
        TrainingExerciseIdentity.v2(v2Exercise(name: 'Incline Bench Press')),
      ),
    );
  });

  test('does not infer an unknown v1 ID from a v2 equipment name', () {
    final unknownV1 = TrainingExerciseIdentity.fromV1(
      exerciseName: 'Bench Press',
      equipmentId: 'unknown_machine',
    );
    final namedV2 = TrainingExerciseIdentity.v2(
      v2Exercise(equipmentId: null, equipmentName: 'Unknown Machine'),
    );

    expect(unknownV1, isNot(namedV2));
  });
}
