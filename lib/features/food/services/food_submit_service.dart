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
    final date = DateTime.parse(data.date);
    await DailyLogMutationGuard.assertDateMutable(date);
    await FoodRepository.update(data);
    final records = await FoodRepository.getAll();
    final readBack = records.where((record) => record.id == data.id);
    if (readBack.length != 1 ||
        readBack.single.date.substring(0, 10) != data.date.substring(0, 10) ||
        readBack.single.toJson().toString() != data.toJson().toString()) {
      throw StateError('targetRecordReadBackFailed');
    }
    await refreshFoodSummary(localDate: data.date.substring(0, 10));
  }

  static Future<void> delete(MealData data) async {
    await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date));
    await FoodRepository.remove(data);
    final readBack = await FoodRepository.getAll();
    if (readBack.any((record) => record.id == data.id)) {
      throw StateError('targetRecordDeleteReadBackFailed');
    }
    await refreshFoodSummary(localDate: data.date.substring(0, 10));
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
