import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/models/training_exercise_controller.dart';
import 'package:or_app/features/training/models/training_set_controller.dart';
import 'package:or_app/features/training/widgets/training_exercise_card.dart';
import 'package:or_app/features/training/widgets/training_exercise_list.dart';
import 'package:or_app/features/training/widgets/training_set_list.dart';
import 'package:or_app/features/training/widgets/training_set_row.dart';

void main() {
  testWidgets('context controls adjust weight and reps', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final weightController = TextEditingController(text: '80');
    final repsController = TextEditingController(text: '10');
    var activations = 0;
    addTearDown(weightController.dispose);
    addTearDown(repsController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: TrainingSetRow(
              setNo: 1,
              weightController: weightController,
              repsController: repsController,
              isActive: true,
              onActivated: () => activations++,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsNWidgets(12));
    expect(
      tester.getSize(find.byType(OutlinedButton).first),
      const Size(50, 42),
    );

    final weightButton = tester.getRect(
      find.byKey(const ValueKey('weight-adjust--10.0')),
    );
    final repButton = tester.getRect(
      find.byKey(const ValueKey('reps-adjust--10')),
    );
    final weightField = tester.getRect(
      find.widgetWithText(TextField, 'Weight'),
    );
    final repsField = tester.getRect(find.widgetWithText(TextField, 'Reps'));
    expect(weightField.center.dy, closeTo(repsField.center.dy, 0.1));
    expect(weightButton.top, greaterThan(weightField.bottom));
    expect(weightButton.right, lessThan(repButton.left));

    await tester.tap(find.byKey(const ValueKey('weight-adjust-2.5')));
    expect(weightController.text, '82.5');
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '81.25');
    await tester.tap(find.byKey(const ValueKey('weight-adjust--2.5')));
    expect(weightController.text, '78.75');

    await tester.tap(find.byKey(const ValueKey('reps-adjust-5')));
    expect(repsController.text, '15');

    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '3');
    await tester.tap(find.byKey(const ValueKey('reps-adjust-1')));
    expect(repsController.text, '4');

    await tester.tap(find.byKey(const ValueKey('reps-adjust-10')));
    expect(repsController.text, '14');

    await tester.tap(find.byKey(const ValueKey('reps-adjust--10')));
    expect(repsController.text, '4');

    await tester.tap(find.byKey(const ValueKey('reps-adjust--5')));
    expect(repsController.text, '0');

    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '20');
    await tester.tap(find.byKey(const ValueKey('reps-adjust--1')));
    expect(repsController.text, '19');
    expect(activations, greaterThan(0));
  });

  testWidgets('context controls move to the focused set', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TrainingExerciseController(
      sets: [TrainingSetController(), TrainingSetController()],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingExerciseList(
            exercises: [controller],
            isEditMode: false,
            onCopy: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsNothing);

    final repsFields = find.widgetWithText(TextField, 'Reps');
    await tester.tap(repsFields.first);
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsNWidgets(12));
    var activeButton = tester.getRect(
      find.byKey(const ValueKey('reps-adjust-1')),
    );
    expect(
      activeButton.top,
      greaterThan(tester.getRect(repsFields.first).bottom),
    );
    expect(activeButton.bottom, lessThan(tester.getRect(repsFields.last).top));

    await tester.tap(repsFields.last);
    await tester.pumpAndSettle();

    expect(find.byType(OutlinedButton), findsNWidgets(12));
    activeButton = tester.getRect(find.byKey(const ValueKey('reps-adjust-1')));
    expect(
      activeButton.top,
      greaterThan(tester.getRect(repsFields.last).bottom),
    );
  });

  testWidgets('previous set values can be copied outside Edit Mode', (
    tester,
  ) async {
    int? deletedIndex;
    final sets = [
      TrainingSetController(
        weightController: TextEditingController(text: '80.5'),
        repsController: TextEditingController(text: '8'),
      ),
      TrainingSetController(),
    ];
    addTearDown(() {
      for (final set in sets) {
        set.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingSetList(
            sets: sets,
            isEditMode: false,
            activeSet: null,
            onSetActivated: (_) {},
            onCopy: (_) {},
            onDelete: (index) => deletedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Copy previous weight'));
    await tester.tap(find.byTooltip('Copy previous reps'));

    expect(sets[1].weightController.text, '80.5');
    expect(sets[1].repsController.text, '8');
    expect(find.byTooltip('Delete set'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Delete set').last);
    expect(deletedIndex, 1);
  });

  testWidgets('exercise delete stays visible outside Edit Mode', (
    tester,
  ) async {
    final controller = TrainingExerciseController();
    addTearDown(controller.dispose);
    var deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingExerciseCard(
            controller: controller,
            onCopy: () {},
            onDelete: () => deleted = true,
            canDelete: true,
            isEditMode: false,
            index: 0,
            activeSet: null,
            onSetActivated: (_) {},
          ),
        ),
      ),
    );

    final selectorHeight = tester
        .getSize(find.byKey(const Key('exercise-selector')))
        .height;
    final weightFieldHeight = tester
        .getSize(find.widgetWithText(TextField, 'Weight'))
        .height;
    final repsFieldHeight = tester
        .getSize(find.widgetWithText(TextField, 'Reps'))
        .height;
    final addSetButtonHeight = tester
        .getSize(find.widgetWithText(ElevatedButton, 'Add Set'))
        .height;
    expect(selectorHeight, weightFieldHeight);
    expect(selectorHeight, repsFieldHeight);
    expect(selectorHeight, addSetButtonHeight);

    expect(find.byTooltip('Delete exercise'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete exercise'));
    expect(deleted, isTrue);
  });
}
