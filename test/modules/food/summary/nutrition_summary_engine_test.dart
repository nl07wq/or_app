import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/food/services/food_summary_service.dart';
import 'package:or_app/modules/food/summary/nutrition_summary.dart';
import 'package:or_app/modules/food/summary/nutrition_summary_engine.dart';

void main() {
  const engine = NutritionSummaryEngine();

  test('returns zero totals for no Food records', () {
    final summary = engine.generate(const <MealData>[]);

    expect(
      summary,
      isA<NutritionSummary>()
          .having((value) => value.calories, 'calories', 0)
          .having((value) => value.protein, 'protein', 0)
          .having((value) => value.fat, 'fat', 0)
          .having((value) => value.carbs, 'carbs', 0),
    );
  });

  test('aggregates calories and macronutrients from Food records', () {
    final records = [
      _meal(
        id: 'breakfast',
        items: const [
          FoodItem(
            name: 'Egg',
            calories: 80,
            protein: 7,
            fat: 5,
            carbohydrate: 1,
            quantity: 2,
          ),
        ],
      ),
      _meal(
        id: 'lunch',
        items: const [
          FoodItem(
            name: 'Rice',
            calories: 250,
            protein: 4.5,
            fat: 0.5,
            carbohydrate: 55,
          ),
        ],
      ),
    ];

    final summary = engine.generate(records);

    expect(summary.calories, 410);
    expect(summary.protein, 18.5);
    expect(summary.fat, 10.5);
    expect(summary.carbs, 57);
  });

  test(
    'FoodSummaryService delegates nutrition totals without behavior changes',
    () {
      final today = DateTime.now().toIso8601String().split('T').first;
      final records = [
        _meal(
          id: 'today-meal',
          date: today,
          items: const [
            FoodItem(
              name: 'Meal',
              calories: 500,
              protein: 30,
              fat: 15,
              carbohydrate: 60,
            ),
          ],
        ),
        _meal(id: 'today-water', date: today, waterMl: 350, items: const []),
        _meal(
          id: 'other-day',
          date: '2000-01-01',
          items: const [
            FoodItem(
              name: 'Old meal',
              calories: 999,
              protein: 99,
              fat: 99,
              carbohydrate: 99,
            ),
          ],
        ),
      ];

      final summary = FoodSummaryService.today(records);

      expect(summary.calories, 500);
      expect(summary.protein, 30);
      expect(summary.fat, 15);
      expect(summary.carbohydrates, 60);
      expect(summary.hydrationMl, 350);
      expect(summary.mealCount, 1);
    },
  );
}

MealData _meal({
  required String id,
  String date = '2026-07-22',
  required List<FoodItem> items,
  double? waterMl,
}) {
  return MealData(
    date: date,
    mealType: 'test',
    items: items,
    memo: '',
    id: id,
    waterMl: waterMl,
  );
}
