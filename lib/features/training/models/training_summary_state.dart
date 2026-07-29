import 'package:flutter/foundation.dart';

import '../../../core/engine/training_summary.dart';
import '../../../core/repositories/training_repository.dart';
import '../services/training_summary_service.dart';

final ValueNotifier<TrainingSummary?> trainingSummaryNotifier =
    ValueNotifier<TrainingSummary?>(null);
final ValueNotifier<double> trainingCardioCaloriesNotifier = ValueNotifier(0);

Future<void> refreshTrainingSummary() async {
  final records = await TrainingRepository.getReadModels();
  final calculationSessions = await TrainingRepository.getAll();
  final now = DateTime.now();
  final dailyRecords = records
      .where((record) {
        final date = DateTime.parse(record.sessionDate).toLocal();
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      })
      .toList(growable: false);
  trainingSummaryNotifier.value = dailyRecords.isEmpty
      ? null
      : TrainingSummary(
          completed: true,
          exerciseCount: dailyRecords.fold(
            0,
            (sum, record) => sum + record.exerciseCount,
          ),
          setCount: dailyRecords.fold(
            0,
            (sum, record) => sum + record.setCount,
          ),
          duration: null,
          sessionName:
              dailyRecords.last.displaySessionName ??
              (dailyRecords.last.memo.isNotEmpty
                  ? dailyRecords.last.memo
                  : dailyRecords.last.v1Data?.exercises.isNotEmpty == true
                  ? dailyRecords.last.v1Data!.exercises.first.exerciseName
                  : null),
        );
  final sessions = calculationSessions
      .where((session) {
        final date = DateTime.parse(session.date).toLocal();
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      })
      .toList(growable: false);
  trainingCardioCaloriesNotifier.value =
      TrainingSummaryService.todayCardioCalories(sessions);
}
