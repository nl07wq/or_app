import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/daily_nutrition_analysis_page.dart';
import 'package:or_app/features/food/models/food_nutrition_aggregate.dart';
import 'package:or_app/features/food/models/food_unified_read_model.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';

void main() {
  final meals = [
    _meal('Breakfast', [
      _item('鶏そぼろおにぎり', calories: 276.1, protein: 20, fat: 4, carb: 35),
    ]),
    _meal('Training', [
      _item('鶏そぼろおにぎり', calories: 405.3, protein: 12, fat: 8, carb: 60),
    ]),
    _meal('Dinner', [
      _item('鶏そぼろおにぎり', calories: 190, protein: 9, fat: 15, carb: 20),
    ]),
  ];

  test('same-name foods in separate meals remain independent candidates', () {
    final entries = dailyNutritionContributorEntries(meals);
    final topCalories = dailyNutritionTopContributor(
      entries,
      (nutrition) => nutrition.calories,
    );

    expect(entries, hasLength(3));
    expect(topCalories?.item.displayName, '鶏そぼろおにぎり');
    expect(topCalories?.mealType, 'Training');
    expect(topCalories?.item.nutrition.calories, 405.3);
    expect(topCalories?.item.nutrition.calories, isNot(681.4));
  });

  test('each nutrient ranks a single recorded entry independently', () {
    final entries = dailyNutritionContributorEntries(meals);

    expect(
      dailyNutritionTopContributor(
        entries,
        (nutrition) => nutrition.calories,
      )?.mealType,
      'Training',
    );
    expect(
      dailyNutritionTopContributor(
        entries,
        (nutrition) => nutrition.protein,
      )?.mealType,
      'Breakfast',
    );
    expect(
      dailyNutritionTopContributor(
        entries,
        (nutrition) => nutrition.fat,
      )?.mealType,
      'Dinner',
    );
    expect(
      dailyNutritionTopContributor(
        entries,
        (nutrition) => nutrition.carbohydrate,
      )?.mealType,
      'Training',
    );
  });

  test('percentage numerator contains only the selected entry', () {
    expect(dailyNutritionContributorSharePercent(405.3, 871.4), 47);
    expect(dailyNutritionContributorSharePercent(681.4, 871.4), 78);
  });

  test(
    'ties preserve recorded entry order, including same-meal duplicates',
    () {
      final entries = dailyNutritionContributorEntries([
        _meal('Breakfast', [
          _item('same', calories: 100),
          _item('same', calories: 100),
        ]),
      ]);

      final top = dailyNutritionTopContributor(
        entries,
        (nutrition) => nutrition.calories,
      );
      expect(top, same(entries.first));
    },
  );
}

FoodUnifiedReadModel _meal(
  String mealType,
  List<FoodUnifiedItemReadModel> items,
) {
  return FoodUnifiedReadModel(
    identity: FoodRecordIdentity(FoodRecordKind.dailyMealV2, mealType),
    localDate: '2026-10-04',
    mealType: mealType,
    displayName: mealType,
    items: items,
    createdAt: DateTime.utc(2026, 10, 4),
    updatedAt: DateTime.utc(2026, 10, 4),
    nutritionAggregate: FoodNutritionAggregate.fromSnapshots(
      items.map((item) => item.nutrition),
    ),
  );
}

FoodUnifiedItemReadModel _item(
  String name, {
  double? calories,
  double? protein,
  double? fat,
  double? carb,
}) => FoodUnifiedItemReadModel(
  temporaryKey:
      '$name-${calories ?? 0}-${protein ?? 0}-${fat ?? 0}-${carb ?? 0}',
  displayName: name,
  quantityLabel: '1 serving',
  nutrition: NutritionSnapshot(
    calories: calories,
    protein: protein,
    fat: fat,
    carbohydrate: carb,
  ),
  sourceKind: FoodReadItemSourceKind.snapshotOnly,
);
