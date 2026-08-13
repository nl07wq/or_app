import 'package:flutter/foundation.dart';

import '../../../core/engine/food_summary.dart';
import '../../../core/repositories/food_repository.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../services/food_summary_service.dart';

final ValueNotifier<FoodSummary?> foodSummaryNotifier =
    ValueNotifier<FoodSummary?>(null);

Future<void> refreshFoodSummary({String? localDate}) async {
  foodSummaryNotifier.value = await loadFoodSummary(localDate: localDate);
}

Future<FoodSummary?> loadFoodSummary({String? localDate}) async {
  final targetLocalDate =
      localDate ?? (await const OperationDateService().current()).value;
  final records = await FoodRepository.getAll();
  return FoodSummaryService.forLocalDate(records, targetLocalDate);
}
