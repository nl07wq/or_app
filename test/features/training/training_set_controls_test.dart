import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/models/training_exercise_controller.dart';
import 'package:or_app/features/training/models/training_set_controller.dart';
import 'package:or_app/features/training/widgets/training_exercise_card.dart';
import 'package:or_app/features/training/widgets/training_set_list.dart';
import 'package:or_app/features/training/widgets/training_set_row.dart';

void main() {
  testWidgets('compact rep buttons adjust reps and clamp at zero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final weightController = TextEditingController();
    final repsController = TextEditingController(text: '10');
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
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ActionChip), findsNWidgets(6));
    expect(tester.getSize(find.byType(ActionChip).first), const Size(40, 36));

    final minusTen = tester.getRect(find.text('-10'));
    final minusFive = tester.getRect(find.text('-5'));
    final minusOne = tester.getRect(find.text('-1'));
    final plusOne = tester.getRect(find.text('+1'));
    final normalGap = minusFive.left - minusTen.right;
    final centerGap = plusOne.left - minusOne.right;
    expect(centerGap, greaterThan(normalGap));

    final firstButton = tester.getRect(find.byType(ActionChip).first);
    final lastButton = tester.getRect(find.byType(ActionChip).last);
    final buttonRowCenter = (firstButton.left + lastButton.right) / 2;
    final weightField = tester.getRect(
      find.widgetWithText(TextField, 'Weight'),
    );
    final repsField = tester.getRect(find.widgetWithText(TextField, 'Reps'));
    final fieldRowCenter = (weightField.left + repsField.right) / 2;
    expect(weightField.center.dy, closeTo(repsField.center.dy, 0.1));
    expect(firstButton.top, greaterThan(repsField.bottom));
    expect(buttonRowCenter, closeTo(fieldRowCenter, 0.1));

    await tester.tap(find.text('+5'));
    expect(repsController.text, '15');

    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '3');
    await tester.tap(find.text('+1'));
    expect(repsController.text, '4');

    await tester.tap(find.text('+10'));
    expect(repsController.text, '14');

    await tester.tap(find.text('-10'));
    expect(repsController.text, '4');

    await tester.tap(find.text('-5'));
    expect(repsController.text, '0');

    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '20');
    await tester.tap(find.text('-1'));
    expect(repsController.text, '19');
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
          ),
        ),
      ),
    );

    expect(find.byTooltip('Delete exercise'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete exercise'));
    expect(deleted, isTrue);
  });
}
