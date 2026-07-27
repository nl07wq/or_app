import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/training/models/personal_record_result.dart';
import 'package:or_app/features/training/models/training_set_controller.dart';
import 'package:or_app/features/training/services/personal_record_service.dart';
import 'package:or_app/features/training/services/statistics_service.dart';
import 'package:or_app/features/training/widgets/training_metric_format.dart';
import 'package:or_app/features/training/widgets/training_summary_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('statistics service calculates factual set metrics', () {
    final result = StatisticsService.calculate(const [
      TrainingSet(setNo: 1, weight: 50, reps: 10),
      TrainingSet(setNo: 2, weight: 60, reps: 8),
      TrainingSet(setNo: 3, weight: 60, reps: 12),
    ]);

    expect(result.totalVolume, 1700);
    expect(result.workingSets, 3);
    expect(result.totalRepetitions, 30);
    expect(result.averageWeight, closeTo(56.6667, 0.0001));
    expect(result.heaviestSet?.weight, 60);
    expect(result.heaviestSet?.reps, 12);
    expect(formatTrainingNumberWithThousands(12480), '12,480');
  });

  test('personal records match exercise and equipment independently', () async {
    await _saveHistoricalResult(
      date: '2026-07-20T12:00:00.000',
      equipmentId: 'power_rack',
      set: const TrainingSet(setNo: 1, weight: 85, reps: 8),
    );
    await _saveHistoricalResult(
      date: '2026-07-21T12:00:00.000',
      equipmentId: 'power_rack',
      set: const TrainingSet(setNo: 1, weight: 80, reps: 12),
    );
    await _saveHistoricalResult(
      date: '2026-07-22T12:00:00.000',
      equipmentId: 'smith_machine',
      set: const TrainingSet(setNo: 1, weight: 100, reps: 5),
    );

    final newRecord = await PersonalRecordService.load(
      exerciseName: 'ベンチプレス',
      equipmentId: 'power_rack',
      currentSets: const [TrainingSet(setNo: 1, weight: 85, reps: 9)],
    );
    final currentRecord = await PersonalRecordService.load(
      exerciseName: 'BenchPress',
      equipmentId: 'power_rack',
      currentSets: const [TrainingSet(setNo: 1, weight: 80, reps: 20)],
    );
    final noRecord = await PersonalRecordService.load(
      exerciseName: 'InclineBenchPress',
      equipmentId: 'power_rack',
      currentSets: const [],
    );

    expect(newRecord?.highestWeight, 85);
    expect(newRecord?.highestRepetitions, 9);
    expect(newRecord?.status, PersonalRecordStatus.newRecord);
    expect(currentRecord?.highestWeight, 85);
    expect(currentRecord?.highestRepetitions, 8);
    expect(currentRecord?.status, PersonalRecordStatus.currentRecord);
    expect(noRecord, isNull);
  });

  testWidgets('statistics and PR cards react to current sets', (tester) async {
    await _saveHistoricalResult(
      date: '2026-07-20T12:00:00.000',
      equipmentId: 'power_rack',
      set: const TrainingSet(setNo: 1, weight: 80, reps: 8),
    );
    final exerciseController = TextEditingController(text: 'BenchPress');
    final equipmentController = ValueNotifier<String?>('power_rack');
    final setController = TrainingSetController(
      weightController: TextEditingController(text: '80'),
      repsController: TextEditingController(text: '9'),
    );
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

    expect(find.text('STATISTICS'), findsOneWidget);
    expect(find.text('Statistics'), findsNothing);
    expect(find.text('総重量'), findsOneWidget);
    expect(find.text('セット数'), findsOneWidget);
    expect(find.text('総レップ数'), findsOneWidget);
    expect(find.text('平均重量'), findsOneWidget);
    expect(find.text('最高重量'), findsOneWidget);
    expect(find.text('PERSONAL RECORD'), findsOneWidget);
    expect(find.text('自己ベスト'), findsOneWidget);
    expect(find.text('720 kg'), findsOneWidget);
    expect(find.text('New PR'), findsNothing);
    expect(find.text('Current PR'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('personal-record-result')),
        matching: find.text('80 kg ×9'),
      ),
      findsOneWidget,
    );

    setController.repsController.text = '7';
    await tester.pumpAndSettle();

    expect(find.text('560 kg'), findsOneWidget);
    expect(find.text('自己ベスト'), findsOneWidget);
    expect(find.text('Current PR'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('personal-record-result')),
        matching: find.text('80 kg ×8'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty localized statistics and PR fit at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
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
          body: SingleChildScrollView(
            child: TrainingSummarySection(
              exerciseController: exerciseController,
              equipmentController: equipmentController,
              sets: [setController],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STATISTICS'), findsOneWidget);
    expect(find.text('PERSONAL RECORD'), findsOneWidget);
    expect(find.text('自己ベスト'), findsOneWidget);
    expect(find.text('記録なし'), findsNWidgets(2));
    expect(find.text('Volume'), findsNothing);
    expect(find.text('Working Sets'), findsNothing);
    expect(find.text('Total Reps'), findsNothing);
    expect(find.text('Average Weight'), findsNothing);
    expect(find.text('Heaviest'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _saveHistoricalResult({
  required String date,
  required String? equipmentId,
  required TrainingSet set,
}) {
  return TrainingRepository.save(
    TrainingSession(
      date: date,
      memo: '',
      exercises: [
        TrainingExercise(
          exerciseName: 'BenchPress',
          order: 1,
          sets: [set],
          equipmentId: equipmentId,
        ),
      ],
    ),
  );
}
