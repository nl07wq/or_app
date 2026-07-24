import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/features/training/models/personal_record_result.dart';
import 'package:or_app/features/training/services/training_summary_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'summary engine aggregates existing read-only service outputs',
    () async {
      await TrainingRepository.save(
        TrainingSession(
          date: '2026-07-22T12:00:00.000',
          memo: '',
          exercises: const [
            TrainingExercise(
              exerciseName: 'BenchPress',
              order: 1,
              equipmentId: 'power_rack',
              sets: [TrainingSet(setNo: 1, weight: 80, reps: 10)],
            ),
          ],
        ),
      );

      final summary = await TrainingSummaryEngine.summarize(
        exerciseName: 'ベンチプレス',
        equipmentId: 'power_rack',
        currentSets: const [TrainingSet(setNo: 1, weight: 82.5, reps: 8)],
      );

      expect(summary.historySummary?.sets.single.weight, 80);
      expect(summary.progressionResult?.lastWeight, 80);
      expect(summary.progressionResult?.suggestedWeight, 82.5);
      expect(summary.statisticsResult.totalVolume, 660);
      expect(summary.statisticsResult.workingSets, 1);
      expect(summary.personalRecordResult?.highestWeight, 82.5);
      expect(
        summary.personalRecordResult?.status,
        PersonalRecordStatus.newRecord,
      );
      expect(
        () => summary.historySummary?.sets.add(
          const TrainingSet(setNo: 2, weight: 80, reps: 8),
        ),
        throwsUnsupportedError,
      );

      final storedSessions = await TrainingRepository.getAll();
      expect(storedSessions, hasLength(1));
      expect(storedSessions.single.exercises.single.sets.single.weight, 80);
    },
  );
}
