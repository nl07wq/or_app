import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/training/services/training_history_preview_service.dart';
import 'package:or_app/features/training/widgets/training_history_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'history service returns the latest matching exercise in set order',
    () async {
      await _saveSession(
        date: '2026-07-21T12:00:00.000',
        exerciseName: 'Bench Press',
        sets: const [TrainingSet(setNo: 1, weight: 50, reps: 12)],
      );
      await _saveSession(
        date: '2026-07-22T12:00:00.000',
        exerciseName: 'bench press',
        sets: const [
          TrainingSet(setNo: 2, weight: 60, reps: 14),
          TrainingSet(setNo: 1, weight: 60, reps: 10),
        ],
      );

      final sets = await TrainingHistoryPreviewService.load(' ベンチプレス ');

      expect(sets, hasLength(2));
      expect(sets!.map((set) => set.setNo), [1, 2]);
      expect(
        () => sets.add(const TrainingSet(setNo: 3, weight: 60, reps: 12)),
        throwsUnsupportedError,
      );
    },
  );

  testWidgets('preview refreshes when the selected exercise changes', (
    tester,
  ) async {
    await _saveSession(
      date: '2026-07-22T12:00:00.000',
      exerciseName: 'Bench Press',
      sets: const [
        TrainingSet(setNo: 1, weight: 60, reps: 10),
        TrainingSet(setNo: 2, weight: 60, reps: 14),
      ],
    );
    await _saveSession(
      date: '2026-07-21T12:00:00.000',
      exerciseName: 'Squat',
      sets: const [TrainingSet(setNo: 1, weight: 100.5, reps: 8)],
    );
    final controller = TextEditingController(text: 'Bench Press');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHistoryPreview(exerciseController: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('60kg × 10 / 60kg × 14'), findsOneWidget);

    controller.text = 'Squat';
    await tester.pumpAndSettle();

    expect(find.text('100.5kg × 8'), findsOneWidget);
    expect(find.text('60kg × 10 / 60kg × 14'), findsNothing);

    controller.text = 'Unknown Exercise';
    await tester.pumpAndSettle();

    expect(find.text('No previous record'), findsOneWidget);
  });
}

Future<void> _saveSession({
  required String date,
  required String exerciseName,
  required List<TrainingSet> sets,
}) {
  return TrainingRepository.save(
    TrainingSession(
      date: date,
      memo: '',
      exercises: [
        TrainingExercise(exerciseName: exerciseName, order: 1, sets: sets),
      ],
    ),
  );
}
