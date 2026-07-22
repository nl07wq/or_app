import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/training/models/training_set_controller.dart';
import 'package:or_app/features/training/services/exercise_catalog_service.dart';
import 'package:or_app/features/training/widgets/exercise_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('catalog lists recently used exercises newest first', () async {
    await TrainingRepository.save(
      TrainingSession(
        date: '2026-07-21T12:00:00.000',
        memo: '',
        exercises: const [
          TrainingExercise(exerciseName: 'Lat Pulldown', order: 1, sets: []),
        ],
      ),
    );
    await TrainingRepository.save(
      TrainingSession(
        date: '2026-07-22T12:00:00.000',
        memo: '',
        exercises: const [
          TrainingExercise(exerciseName: 'Bench Press', order: 1, sets: []),
        ],
      ),
    );

    final catalog = await ExerciseCatalogService.load();

    expect(catalog.recent, ['Bench Press', 'Lat Pulldown']);
    expect(catalog.all, containsAll(['Bench Press', 'Lat Pulldown']));
  });

  testWidgets('selector changes only the exercise name', (tester) async {
    await TrainingRepository.save(
      TrainingSession(
        date: '2026-07-22T12:00:00.000',
        memo: '',
        exercises: const [
          TrainingExercise(exerciseName: 'Bench Press', order: 1, sets: []),
        ],
      ),
    );
    final exerciseController = TextEditingController();
    final setController = TrainingSetController(
      weightController: TextEditingController(text: '80'),
      repsController: TextEditingController(text: '8'),
    );
    addTearDown(exerciseController.dispose);
    addTearDown(setController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseSelector(controller: exerciseController)),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('exercise-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('All Exercises'), findsOneWidget);
    await tester.tap(find.text('Bench Press').first);
    await tester.pumpAndSettle();

    expect(exerciseController.text, 'Bench Press');
    expect(setController.weightController.text, '80');
    expect(setController.repsController.text, '8');
  });

  testWidgets('custom exercise is registered and immediately selected', (
    tester,
  ) async {
    final exerciseController = TextEditingController();
    addTearDown(exerciseController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseSelector(controller: exerciseController)),
      ),
    );

    await tester.tap(find.byKey(const Key('exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Custom Exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cable Fly');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(exerciseController.text, 'Cable Fly');
    expect((await ExerciseCatalogService.load()).all, contains('Cable Fly'));

    exerciseController.clear();
    await tester.tap(find.byKey(const Key('exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cable Fly'));
    await tester.pumpAndSettle();
    expect(exerciseController.text, 'Cable Fly');
  });
}
