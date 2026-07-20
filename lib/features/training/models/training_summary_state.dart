import 'package:flutter/foundation.dart';

import '../../../core/engine/training_summary.dart';
import '../../../core/repositories/training_repository.dart';
import '../services/training_summary_service.dart';

final ValueNotifier<TrainingSummary?> trainingSummaryNotifier =
    ValueNotifier<TrainingSummary?>(null);

Future<void> refreshTrainingSummary() async {
  final sessions = await TrainingRepository.getAll();
  trainingSummaryNotifier.value = TrainingSummaryService.today(sessions);
}
