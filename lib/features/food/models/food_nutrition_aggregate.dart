import 'nutrition_models.dart';

enum FoodNutritionCompleteness {
  complete,
  partial,
  unknown;

  String get stableId => name;
}

class FoodNutritionValueAggregate {
  final double knownTotal;
  final int knownItemCount;
  final int unknownItemCount;

  const FoodNutritionValueAggregate({
    required this.knownTotal,
    required this.knownItemCount,
    required this.unknownItemCount,
  });

  FoodNutritionCompleteness get completeness {
    if (knownItemCount == 0) return FoodNutritionCompleteness.unknown;
    if (unknownItemCount != 0) return FoodNutritionCompleteness.partial;
    return FoodNutritionCompleteness.complete;
  }
}

class FoodNutritionAggregate {
  final FoodNutritionValueAggregate calories;
  final FoodNutritionValueAggregate protein;
  final FoodNutritionValueAggregate fat;
  final FoodNutritionValueAggregate carbohydrate;

  const FoodNutritionAggregate({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrate,
  });

  factory FoodNutritionAggregate.fromSnapshots(
    Iterable<NutritionSnapshot> snapshots,
  ) {
    final values = snapshots.toList(growable: false);
    return FoodNutritionAggregate(
      calories: _aggregate(values.map((value) => value.calories)),
      protein: _aggregate(values.map((value) => value.protein)),
      fat: _aggregate(values.map((value) => value.fat)),
      carbohydrate: _aggregate(values.map((value) => value.carbohydrate)),
    );
  }

  factory FoodNutritionAggregate.combine(
    Iterable<FoodNutritionAggregate> values,
  ) {
    final aggregates = values.toList(growable: false);
    return FoodNutritionAggregate(
      calories: _combine(aggregates.map((value) => value.calories)),
      protein: _combine(aggregates.map((value) => value.protein)),
      fat: _combine(aggregates.map((value) => value.fat)),
      carbohydrate: _combine(aggregates.map((value) => value.carbohydrate)),
    );
  }

  static FoodNutritionValueAggregate _aggregate(Iterable<double?> values) {
    var total = 0.0;
    var known = 0;
    var unknown = 0;
    for (final value in values) {
      if (value == null) {
        unknown++;
      } else {
        total += value;
        known++;
      }
    }
    return FoodNutritionValueAggregate(
      knownTotal: total,
      knownItemCount: known,
      unknownItemCount: unknown,
    );
  }

  static FoodNutritionValueAggregate _combine(
    Iterable<FoodNutritionValueAggregate> values,
  ) => FoodNutritionValueAggregate(
    knownTotal: values.fold(0, (sum, value) => sum + value.knownTotal),
    knownItemCount: values.fold(0, (sum, value) => sum + value.knownItemCount),
    unknownItemCount: values.fold(
      0,
      (sum, value) => sum + value.unknownItemCount,
    ),
  );
}
