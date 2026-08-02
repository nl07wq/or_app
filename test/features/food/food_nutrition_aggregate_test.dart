import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_nutrition_aggregate.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';

void main() {
  test('complete aggregate counts explicit zero as known', () {
    final result = FoodNutritionAggregate.fromSnapshots([
      NutritionSnapshot(calories: 0, protein: 10, fat: 2, carbohydrate: 5),
      NutritionSnapshot(calories: 100, protein: 0, fat: 3, carbohydrate: 10),
    ]);

    expect(result.calories.knownTotal, 100);
    expect(result.calories.knownItemCount, 2);
    expect(result.calories.unknownItemCount, 0);
    expect(result.calories.completeness, FoodNutritionCompleteness.complete);
  });

  test('partial aggregate retains known total and unknown count', () {
    final result = FoodNutritionAggregate.fromSnapshots([
      NutritionSnapshot(calories: 500),
      NutritionSnapshot(),
    ]);

    expect(result.calories.knownTotal, 500);
    expect(result.calories.knownItemCount, 1);
    expect(result.calories.unknownItemCount, 1);
    expect(result.calories.completeness, FoodNutritionCompleteness.partial);
  });

  test('unknown aggregate is distinct from a known zero', () {
    final unknown = FoodNutritionAggregate.fromSnapshots([NutritionSnapshot()]);
    final zero = FoodNutritionAggregate.fromSnapshots([
      NutritionSnapshot(calories: 0),
    ]);

    expect(unknown.calories.completeness, FoodNutritionCompleteness.unknown);
    expect(unknown.calories.knownItemCount, 0);
    expect(zero.calories.completeness, FoodNutritionCompleteness.complete);
    expect(zero.calories.knownTotal, 0);
  });

  test('combining meal aggregates preserves partial day completeness', () {
    final result = FoodNutritionAggregate.combine([
      FoodNutritionAggregate.fromSnapshots([NutritionSnapshot(calories: 200)]),
      FoodNutritionAggregate.fromSnapshots([NutritionSnapshot()]),
    ]);

    expect(result.calories.knownTotal, 200);
    expect(result.calories.completeness, FoodNutritionCompleteness.partial);
  });
}
