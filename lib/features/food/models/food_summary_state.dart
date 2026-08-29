import 'package:flutter/foundation.dart';

import '../../../core/repositories/food_repository.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../services/food_summary_service.dart';
import '../../repositories/app_repository_container.dart';
import 'food_unified_read_model.dart';
import '../../../core/engine/food_summary.dart';

final ValueNotifier<FoodSummary?> foodSummaryNotifier =
    ValueNotifier<FoodSummary?>(null);

Future<void> refreshFoodSummary({String? localDate}) async {
  foodSummaryNotifier.value = await loadFoodSummary(localDate: localDate);
}

Future<FoodSummary?> loadFoodSummary({String? localDate}) async {
  final targetLocalDate =
      localDate ?? (await const OperationDateService().current()).value;
  if (AppRepositoryRegistry.hasContainer) {
    final records = await AppRepositoryRegistry.container.foodMixedRead
        .readForLocalDate(targetLocalDate);
    final mixed = FoodMixedDaySummary.fromRecords(records);
    return FoodSummary(
      calories: mixed.nutrition.calories.knownTotal,
      protein: mixed.nutrition.protein.knownTotal,
      fat: mixed.nutrition.fat.knownTotal,
      carbohydrates: mixed.nutrition.carbohydrate.knownTotal,
      hydrationMl: mixed.hydrationMl,
      mealCount: mixed.mealCount,
      waterRecorded: records.any((record) => record.waterMl != null),
    );
  }
  final records = await FoodRepository.getAll();
  return FoodSummaryService.forLocalDate(records, targetLocalDate);
}
