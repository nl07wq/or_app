import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../models/nutrition_history_models.dart';

class NutritionHistorySourceResolver {
  final DailyAggregateRepository _repository;

  const NutritionHistorySourceResolver({
    required DailyAggregateRepository dailyAggregateRepository,
  }) : _repository = dailyAggregateRepository;

  Future<List<NutritionHistoryDataPoint>> resolve({
    required String startDate,
    required String endDate,
  }) async {
    final records = await _repository.getRange(startDate, endDate);
    return List.unmodifiable(
      [
        for (final record in records)
          NutritionHistoryDataPoint(
            operationDate: record.operationDate,
            intakeCaloriesKcal: record.intakeCaloriesKcal,
            estimatedExpenditureKcal: record.estimatedExpenditureKcal,
            estimatedCalorieBalanceKcal: record.estimatedCalorieBalanceKcal,
          ),
      ]..sort((a, b) => a.operationDate.compareTo(b.operationDate)),
    );
  }
}
