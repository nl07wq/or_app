import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/training/models/progression_result.dart';
import 'package:or_app/features/training/services/progression_service.dart';
import 'package:or_app/features/training/widgets/training_progression_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('v1 rules increase, maintain, or repeat weight', () {
    final increase = ProgressionService.evaluate(
      const TrainingSet(setNo: 1, weight: 65, reps: 10),
    );
    final maintain = ProgressionService.evaluate(
      const TrainingSet(setNo: 1, weight: 65, reps: 9),
    );
    final repeat = ProgressionService.evaluate(
      const TrainingSet(setNo: 1, weight: 65, reps: 7),
    );

    expect(increase.suggestedWeight, 67.5);
    expect(increase.recommendation, ProgressionRecommendation.increaseWeight);
    expect(maintain.suggestedWeight, 65);
    expect(maintain.recommendation, ProgressionRecommendation.maintainWeight);
    expect(repeat.suggestedWeight, 65);
    expect(repeat.recommendation, ProgressionRecommendation.repeatWeight);
  });

  test('latest result matches both exercise and equipment', () async {
    await _saveResult(
      date: '2026-07-20T12:00:00.000',
      equipmentId: null,
      sets: const [TrainingSet(setNo: 1, weight: 40, reps: 9)],
    );
    await _saveResult(
      date: '2026-07-21T12:00:00.000',
      equipmentId: 'power_rack',
      sets: const [TrainingSet(setNo: 1, weight: 62.5, reps: 12)],
    );
    await _saveResult(
      date: '2026-07-22T12:00:00.000',
      equipmentId: 'power_rack',
      sets: const [
        TrainingSet(setNo: 1, weight: 60, reps: 12),
        TrainingSet(setNo: 2, weight: 65, reps: 10),
      ],
    );
    await _saveResult(
      date: '2026-07-23T12:00:00.000',
      equipmentId: 'smith_machine',
      sets: const [TrainingSet(setNo: 1, weight: 100, reps: 12)],
    );

    final powerRack = await ProgressionService.loadLatest(
      exerciseName: 'ベンチプレス',
      equipmentId: 'power_rack',
    );
    final noEquipment = await ProgressionService.loadLatest(
      exerciseName: 'BenchPress',
      equipmentId: null,
    );
    final noMatch = await ProgressionService.loadLatest(
      exerciseName: 'InclineBenchPress',
      equipmentId: 'power_rack',
    );

    expect(powerRack?.lastWeight, 65);
    expect(powerRack?.lastReps, 10);
    expect(powerRack?.suggestedWeight, 67.5);
    expect(noEquipment?.lastWeight, 40);
    expect(noEquipment?.suggestedWeight, 40);
    expect(noMatch, isNull);
  });

  testWidgets('progression card refreshes when equipment changes', (
    tester,
  ) async {
    await _saveResult(
      date: '2026-07-22T12:00:00.000',
      equipmentId: 'power_rack',
      sets: const [TrainingSet(setNo: 1, weight: 65, reps: 10)],
    );
    final exerciseController = TextEditingController(text: 'BenchPress');
    final equipmentController = ValueNotifier<String?>('power_rack');
    addTearDown(exerciseController.dispose);
    addTearDown(equipmentController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingProgressionCard(
            exerciseController: exerciseController,
            equipmentController: equipmentController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('65kg ×10'), findsOneWidget);
    expect(find.text('67.5kg ×8〜10'), findsOneWidget);
    expect(find.text('Reason  Previous target achieved.'), findsOneWidget);

    equipmentController.value = 'smith_machine';
    await tester.pumpAndSettle();

    expect(find.text('No previous progression data.'), findsOneWidget);
    expect(exerciseController.text, 'BenchPress');
    expect(equipmentController.value, 'smith_machine');
  });
}

Future<void> _saveResult({
  required String date,
  required String? equipmentId,
  required List<TrainingSet> sets,
}) {
  return TrainingRepository.save(
    TrainingSession(
      date: date,
      memo: '',
      exercises: [
        TrainingExercise(
          exerciseName: 'BenchPress',
          order: 1,
          sets: sets,
          equipmentId: equipmentId,
        ),
      ],
    ),
  );
}
