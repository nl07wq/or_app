import 'package:flutter/foundation.dart';

import '../../../core/engine/food_summary.dart';
import '../../../core/repositories/food_repository.dart';
import '../services/food_summary_service.dart';

final ValueNotifier<FoodSummary?> foodSummaryNotifier =
    ValueNotifier<FoodSummary?>(null);

Future<void> refreshFoodSummary() async {
  final records = await FoodRepository.getAll();
  foodSummaryNotifier.value = FoodSummaryService.today(records);
}
