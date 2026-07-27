import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/training/models/progression_result.dart';
import 'package:or_app/features/training/models/training_set_controller.dart';
import 'package:or_app/features/training/services/progression_service.dart';
import 'package:or_app/features/training/widgets/training_summary_section.dart';
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
    final setController = TrainingSetController();
    addTearDown(exerciseController.dispose);
    addTearDown(equipmentController.dispose);
    addTearDown(setController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingSummarySection(
            exerciseController: exerciseController,
            equipmentController: equipmentController,
            sets: [setController],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PROGRESSION'), findsOneWidget);
    expect(find.text('Progression'), findsNothing);
    expect(find.text('前回'), findsOneWidget);
    expect(find.text('今回'), findsOneWidget);
    expect(find.text('理由'), findsOneWidget);
    expect(find.text('65kg ×10'), findsOneWidget);
    expect(find.text('67.5kg ×8〜10'), findsOneWidget);
    expect(find.text('前回目標達成済みのため'), findsOneWidget);
    expect(find.text('Last'), findsNothing);
    expect(find.text('Suggested'), findsNothing);
    expect(find.textContaining('Reason'), findsNothing);

    equipmentController.value = 'smith_machine';
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('progression-empty')),
        matching: find.text('記録なし'),
      ),
      findsOneWidget,
    );
    expect(find.text('提案なし'), findsOneWidget);
    expect(find.text('比較できる前回記録がありません'), findsOneWidget);
    expect(exerciseController.text, 'BenchPress');
    expect(equipmentController.value, 'smith_machine');
  });

  testWidgets('progression localization does not overflow at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exerciseController = TextEditingController(text: 'No History');
    final equipmentController = ValueNotifier<String?>(null);
    final setController = TrainingSetController();
    addTearDown(exerciseController.dispose);
    addTearDown(equipmentController.dispose);
    addTearDown(setController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingSummarySection(
            exerciseController: exerciseController,
            equipmentController: equipmentController,
            sets: [setController],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PROGRESSION'), findsOneWidget);
    expect(find.text('比較できる前回記録がありません'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
