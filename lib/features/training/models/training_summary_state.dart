import 'package:flutter/foundation.dart';

import '../../../core/engine/training_summary.dart';
import '../../../core/repositories/training_repository.dart';
import '../services/training_daily_summary_service.dart';
import '../services/training_summary_service.dart';

final ValueNotifier<TrainingSummary?> trainingSummaryNotifier =
    ValueNotifier<TrainingSummary?>(null);
final ValueNotifier<double> trainingCardioCaloriesNotifier = ValueNotifier(0);

Future<void> refreshTrainingSummary() async {
  final records = await TrainingRepository.getReadModels();
  final calculationSessions = await TrainingRepository.getAll();
  final now = DateTime.now();
  final localDate =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  trainingSummaryNotifier.value = TrainingDailySummaryService.calculate(
    preferredRecords: records,
    localDate: localDate,
  ).toDashboardSummary();
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
