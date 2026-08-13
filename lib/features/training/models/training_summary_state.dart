import 'package:flutter/foundation.dart';

import '../../../core/engine/training_summary.dart';
import '../../../core/repositories/training_repository.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../services/training_daily_summary_service.dart';

final ValueNotifier<TrainingSummary?> trainingSummaryNotifier =
    ValueNotifier<TrainingSummary?>(null);

Future<void> refreshTrainingSummary({String? localDate}) async {
  trainingSummaryNotifier.value = await loadTrainingSummary(
    localDate: localDate,
  );
}

Future<TrainingSummary?> loadTrainingSummary({String? localDate}) async {
  final records = await TrainingRepository.getReadModels();
  final targetLocalDate =
      localDate ?? (await const OperationDateService().current()).value;
  return TrainingDailySummaryService.calculate(
    preferredRecords: records,
    localDate: targetLocalDate,
  ).toDashboardSummary();
}
