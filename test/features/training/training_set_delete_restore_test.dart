import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_v2_form_controller.dart';
import 'package:or_app/features/training/widgets/training_set_v2_editor.dart';

void main() {
  test('missing planned slots restore in source order before an extra set', () {
    final exercise = _plannedExercise();
    addTearDown(exercise.dispose);

    exercise.removeSet(exercise.sets[2]);
    exercise.removeSet(exercise.sets[1]);
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 3]);

    exercise.addSet();
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 1, 3]);
    expect(exercise.sets[1].setType, TrainingSetType.warmUp);
    expect(exercise.sets[1].weight.text, '40');
    expect(exercise.sets[1].reps.text, '5');
    expect(exercise.sets[1].rest.text, '60');

    exercise.addSet();
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 1, 2, 3]);
    expect(exercise.sets[2].setType, TrainingSetType.main);
    expect(exercise.sets[2].weight.text, '70');
    expect(exercise.sets[2].reps.text, '8');
    expect(exercise.sets[2].targetMaxReps, 10);
    expect(exercise.sets[2].rest.text, '90');

    exercise.addSet();
    expect(exercise.sets.last.planSlotIndex, isNull);
    expect(exercise.sets, hasLength(5));
  });

  test('planned slot linkage survives draft round-trip after deletion', () {
    final source = TrainingV2FormController.newSession(localDate: '2026-08-31');
    addTearDown(source.dispose);
    final sourceExercise = source.exercises.single;
    sourceExercise.dispose();
    source.exercises[0] = _plannedExercise();
    source.exercises.single.removeSet(source.exercises.single.sets[2]);

    final restored = TrainingV2FormController.newSession(
      localDate: '2026-08-31',
    );
    addTearDown(restored.dispose);
    restored.restoreDraftState(source.toDraftState());

    final exercise = restored.exercises.single;
    expect(exercise.planSlots, hasLength(4));
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 1, 3]);
    exercise.addSet();
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 1, 2, 3]);
    expect(exercise.sets[2].plannedWeightKg, 70);
    expect(exercise.sets[2].targetMinReps, 8);
    expect(exercise.sets[2].targetMaxReps, 10);
  });

  test('null plan values remain null when a missing slot is restored', () {
    final exercise = TrainingV2ExerciseFormController(
      planSlots: const [
        TrainingV2PlannedSetSlot(
          index: 0,
          setType: TrainingSetType.main,
          plannedWeightKg: null,
          targetMinReps: null,
          targetMaxReps: null,
          restAfterSeconds: null,
        ),
      ],
    );
    addTearDown(exercise.dispose);
    exercise.removeSet(exercise.sets.single);

    exercise.addSet();

    expect(exercise.sets.single.planSlotIndex, 0);
    expect(exercise.sets.single.weight.text, isEmpty);
    expect(exercise.sets.single.reps.text, isEmpty);
    expect(exercise.sets.single.rest.text, isEmpty);
  });

  testWidgets('delete requires confirmation and cancel preserves every set', (
    tester,
  ) async {
    final exercise = _plannedExercise();
    addTearDown(exercise.dispose);
    var changes = 0;
    await _pumpEditor(tester, exercise, onChanged: () => changes++);

    final deleteButton = tester.widget<IconButton>(
      find.byKey(const Key('v2-set-2-delete')),
    );
    final context = tester.element(find.byKey(const Key('v2-set-2-delete')));
    expect(deleteButton.color, Theme.of(context).colorScheme.error);

    await tester.ensureVisible(find.byKey(const Key('v2-set-2-delete')));
    await tester.tap(find.byKey(const Key('v2-set-2-delete')));
    await tester.pumpAndSettle();
    expect(find.text('このSETを削除しますか？'), findsOneWidget);
    expect(find.textContaining('元のTRAINING PLANは保持されます。'), findsOneWidget);
    expect(exercise.sets, hasLength(4));

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 1, 2, 3]);
    expect(changes, 0);
  });

  testWidgets('confirmed delete removes Actual and ADD SET restores its Plan', (
    tester,
  ) async {
    final exercise = _plannedExercise();
    addTearDown(exercise.dispose);
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SingleChildScrollView(
                child: TrainingSetV2Editor(
                  controller: exercise,
                  activeBase: Theme.of(context).colorScheme.primary,
                  onChanged: () => rebuild(() {}),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('v2-set-2-delete')));
    await tester.tap(find.byKey(const Key('v2-set-2-delete')));
    await tester.pumpAndSettle();
    expect(exercise.sets, hasLength(4));
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 1, 3]);
    expect(exercise.planSlots, hasLength(4));

    await tester.ensureVisible(find.text('ADD SET'));
    await tester.tap(find.text('ADD SET'));
    await tester.pumpAndSettle();
    expect(exercise.sets.map((set) => set.planSlotIndex), [0, 1, 2, 3]);
    expect(find.text('PLAN  70 kg'), findsNWidgets(2));
    expect(find.text('TARGET  8–10'), findsNWidgets(2));

    final weightAdjustments = find.byKey(
      const Key('v2-set-2-weight-adjustments'),
    );
    final repsAdjustments = find.byKey(const Key('v2-set-2-reps-adjustments'));
    await tester.tap(
      find.descendant(of: weightAdjustments, matching: find.text('+2.5')),
    );
    await tester.tap(
      find.descendant(of: repsAdjustments, matching: find.text('+1')),
    );
    expect(exercise.sets[2].weight.text, '72.5');
    expect(exercise.sets[2].reps.text, '9');
    expect(exercise.sets[2].plannedWeightKg, 70);
    expect(exercise.sets[2].targetMinReps, 8);
    expect(exercise.sets[2].targetMaxReps, 10);
  });

  for (final width in const [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets(
      'delete confirmation remains responsive at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final exercise = _singlePlannedExercise();
        addTearDown(exercise.dispose);
        await _pumpEditor(tester, exercise);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('v2-set-0-delete')));
        await tester.pumpAndSettle();

        expect(find.text('このSETを削除しますか？'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpEditor(
  WidgetTester tester,
  TrainingV2ExerciseFormController exercise, {
  VoidCallback? onChanged,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: TrainingSetV2Editor(
            controller: exercise,
            activeBase: Colors.blue,
            onChanged: onChanged ?? () {},
          ),
        ),
      ),
    ),
  ),
);

TrainingV2ExerciseFormController _plannedExercise() {
  final slots = <TrainingV2PlannedSetSlot>[
    const TrainingV2PlannedSetSlot(
      index: 0,
      setType: TrainingSetType.warmUp,
      plannedWeightKg: 20,
      targetMinReps: 10,
      targetMaxReps: 10,
      restAfterSeconds: 60,
    ),
    const TrainingV2PlannedSetSlot(
      index: 1,
      setType: TrainingSetType.warmUp,
      plannedWeightKg: 40,
      targetMinReps: 5,
      targetMaxReps: 5,
      restAfterSeconds: 60,
    ),
    const TrainingV2PlannedSetSlot(
      index: 2,
      setType: TrainingSetType.main,
      plannedWeightKg: 70,
      targetMinReps: 8,
      targetMaxReps: 10,
      restAfterSeconds: 90,
    ),
    const TrainingV2PlannedSetSlot(
      index: 3,
      setType: TrainingSetType.main,
      plannedWeightKg: 70,
      targetMinReps: 8,
      targetMaxReps: 10,
      restAfterSeconds: 90,
    ),
  ];
  final exercise = TrainingV2ExerciseFormController(planSlots: slots);
  for (final set in exercise.sets) {
    set.dispose();
  }
  exercise.sets
    ..clear()
    ..addAll(slots.map((slot) => slot.createExecution()));
  return exercise;
}

TrainingV2ExerciseFormController _singlePlannedExercise() {
  final exercise = _plannedExercise();
  final slot = exercise.planSlots.first;
  final result = TrainingV2ExerciseFormController(planSlots: [slot]);
  for (final set in result.sets) {
    set.dispose();
  }
  result.sets
    ..clear()
    ..add(slot.createExecution());
  exercise.dispose();
  return result;
}
