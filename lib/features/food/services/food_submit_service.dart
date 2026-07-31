import '../../../core/models/meal_data.dart';
import '../../../core/repositories/food_repository.dart';
import '../../../core/services/daily_log_mutation_guard.dart';
import '../../operation_date/services/operation_date_service.dart';

import '../models/food_summary_state.dart';

class FoodSubmitService {
  const FoodSubmitService._();

  static Future<void> save(
    MealData data, {
    OperationDateService? operationDateService,
    String? operationLocalDate,
  }) async {
    final localDate =
        operationLocalDate ??
        (await (operationDateService ?? const OperationDateService()).current())
            .value;
    final operationRecord = _withLocalDate(data, localDate);
    await DailyLogMutationGuard.assertDateMutable(
      DateTime.parse(operationRecord.date),
    );
    await FoodRepository.save(operationRecord);
    await refreshFoodSummary(localDate: localDate);
  }

  static Future<void> update(MealData data) async {
    await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date));
    await FoodRepository.update(data);
    await refreshFoodSummary();
  }

  static Future<void> delete(MealData data) async {
    await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date));
    await FoodRepository.remove(data);
    await refreshFoodSummary();
  }

  static MealData _withLocalDate(MealData data, String localDate) => MealData(
    date: localDate,
    mealType: data.mealType,
    items: data.items,
    memo: data.memo,
    id: data.id,
    waterMl: data.waterMl,
  );
}
