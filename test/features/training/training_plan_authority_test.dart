import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_v2_form_controller.dart';

void main() {
  TrainingV2PlanAuthorityItem cassette() => TrainingV2PlanAuthorityItem(
    planItemId: 'benchpress|none',
    exerciseIdentity: 'benchpress|none',
    exerciseName: 'Bench Press',
    equipment: null,
    planSlots: const [
      TrainingV2PlannedSetSlot(
        index: 0,
        setType: TrainingSetType.main,
        plannedWeightKg: 70,
        targetMinReps: 8,
        targetMaxReps: 10,
        restAfterSeconds: 90,
      ),
    ],
  );

  test('attached plan detaches without changing an existing duplicate', () {
    final form = TrainingV2FormController.newSession(localDate: '2026-09-28');
    addTearDown(form.dispose);
    final plan = cassette();
    form.planAuthorityItems.add(plan);
    final attached = form.exercises.single;
    plan.attach(attached);
    final duplicate = form.addExercise()..exerciseName.text = 'Bench Press';

    form.removeExercise(attached);

    expect(plan.attachedExerciseInstanceId, isNull);
    expect(duplicate.planSlots, isEmpty);
    expect(duplicate.sets.single.weight.text, isEmpty);
    expect(form.attachDetachedPlanForNewExercise(duplicate), isFalse);

    final reattached = form.addExercise()..exerciseName.text = 'Bench Press';
    expect(form.attachDetachedPlanForNewExercise(reattached), isTrue);
    expect(plan.attachedExerciseInstanceId, reattached.instanceId);
    expect(duplicate.planSlots, isEmpty);
    expect(reattached.sets.single.weight.text, '70');
  });

  test(
    'detached cassette and instance identities survive draft round-trip',
    () {
      final source = TrainingV2FormController.newSession(
        localDate: '2026-09-28',
      );
      addTearDown(source.dispose);
      final plan = cassette();
      source.planAuthorityItems.add(plan);
      plan.attach(source.exercises.single);
      final attachedId = source.exercises.single.instanceId;
      source.removeExercise(source.exercises.single);
      final draft = source.toDraftState();

      final restored = TrainingV2FormController.newSession(
        localDate: '2026-09-28',
      );
      addTearDown(restored.dispose);
      restored.restoreDraftState(draft);
      expect(
        restored.planAuthorityItems.single.attachedExerciseInstanceId,
        isNull,
      );
      final newExercise = restored.addExercise()
        ..exerciseName.text = 'Bench Press';
      expect(newExercise.instanceId, isNot(attachedId));
      expect(restored.attachDetachedPlanForNewExercise(newExercise), isTrue);
    },
  );

  test('reordering execution exercises does not move plan attachment', () {
    final form = TrainingV2FormController.newSession(localDate: '2026-09-28');
    addTearDown(form.dispose);
    final plan = cassette();
    form.planAuthorityItems.add(plan);
    final attached = form.exercises.single;
    plan.attach(attached);
    final duplicate = form.addExercise()..exerciseName.text = 'Bench Press';
    form.exercises
      ..remove(duplicate)
      ..insert(0, duplicate);

    expect(form.exercises.first, duplicate);
    expect(plan.attachedExerciseInstanceId, attached.instanceId);
    expect(duplicate.planSlots, isEmpty);
  });
}
