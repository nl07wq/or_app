import 'food_nutrition_aggregate.dart';
import 'food_provenance_models.dart';
import 'nutrition_models.dart';

enum FoodRecordKind { legacyV1, dailyMealV2 }

enum FoodReadItemSourceKind { legacyV1, foodCatalog, recipe, snapshotOnly }

class FoodRecordIdentity {
  final FoodRecordKind recordKind;
  final String recordId;

  const FoodRecordIdentity(this.recordKind, this.recordId);

  @override
  bool operator ==(Object other) =>
      other is FoodRecordIdentity &&
      other.recordKind == recordKind &&
      other.recordId == recordId;

  @override
  int get hashCode => Object.hash(recordKind, recordId);
}

class FoodUnifiedItemReadModel {
  final String temporaryKey;
  final String displayName;
  final String quantityLabel;
  final NutritionSnapshot nutrition;
  final String? catalogReferenceId;
  final String? recipeReferenceId;
  final FoodDataProvenance? provenance;
  final NutritionStatus? nutritionStatus;
  final FoodReadItemSourceKind sourceKind;

  const FoodUnifiedItemReadModel({
    required this.temporaryKey,
    required this.displayName,
    required this.quantityLabel,
    required this.nutrition,
    this.catalogReferenceId,
    this.recipeReferenceId,
    this.provenance,
    this.nutritionStatus,
    required this.sourceKind,
  });
}

class FoodUnifiedReadModel {
  final FoodRecordIdentity identity;
  final String localDate;
  final String mealType;
  final String displayName;
  final List<FoodUnifiedItemReadModel> items;
  final String? memo;
  final double? waterMl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FoodNutritionAggregate nutritionAggregate;

  FoodUnifiedReadModel({
    required this.identity,
    required this.localDate,
    required this.mealType,
    required this.displayName,
    required List<FoodUnifiedItemReadModel> items,
    this.memo,
    this.waterMl,
    required this.createdAt,
    required this.updatedAt,
    required this.nutritionAggregate,
  }) : items = List.unmodifiable(items);

  FoodNutritionCompleteness get nutritionCompleteness {
    final states = [
      nutritionAggregate.calories.completeness,
      nutritionAggregate.protein.completeness,
      nutritionAggregate.fat.completeness,
      nutritionAggregate.carbohydrate.completeness,
    ];
    if (states.every((value) => value == FoodNutritionCompleteness.complete)) {
      return FoodNutritionCompleteness.complete;
    }
    if (states.every((value) => value == FoodNutritionCompleteness.unknown)) {
      return FoodNutritionCompleteness.unknown;
    }
    return FoodNutritionCompleteness.partial;
  }
}

class FoodMixedDaySummary {
  final int mealCount;
  final double hydrationMl;
  final FoodNutritionAggregate nutrition;

  const FoodMixedDaySummary({
    required this.mealCount,
    required this.hydrationMl,
    required this.nutrition,
  });

  factory FoodMixedDaySummary.fromRecords(
    Iterable<FoodUnifiedReadModel> records,
  ) {
    final values = records.toList(growable: false);
    final meals = values.where((value) => value.waterMl == null).toList();
    return FoodMixedDaySummary(
      mealCount: meals.length,
      hydrationMl: values.fold(0, (sum, value) => sum + (value.waterMl ?? 0)),
      nutrition: FoodNutritionAggregate.combine(
        meals.map((value) => value.nutritionAggregate),
      ),
    );
  }
}
