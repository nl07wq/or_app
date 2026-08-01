import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';

void main() {
  group('quantity definition', () {
    test('supports the five formal units without inferred conversion', () {
      final values = [
        FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
        FoodQuantityDefinition(value: 300, unit: FoodQuantityUnit.milliliter),
        FoodQuantityDefinition(
          value: 1,
          unit: FoodQuantityUnit.piece,
          basisValue: 50,
          basisUnit: FoodQuantityUnit.gram,
        ),
        FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.pack),
        FoodQuantityDefinition(value: 1.5, unit: FoodQuantityUnit.serving),
      ];

      for (final value in values) {
        expect(
          FoodQuantityDefinition.fromJson(value.toJson()).toJson(),
          value.toJson(),
        );
      }
      expect(values[3].basisValue, isNull);
      expect(values[4].value, 1.5);
    });

    test('rejects invalid units, values, and basis combinations', () {
      expect(
        () => FoodQuantityDefinition(value: 0, unit: FoodQuantityUnit.gram),
        throwsArgumentError,
      );
      expect(
        () => FoodQuantityDefinition(
          value: 1,
          unit: FoodQuantityUnit.piece,
          basisValue: 50,
        ),
        throwsArgumentError,
      );
      expect(
        () => FoodQuantityDefinition(
          value: 1,
          unit: FoodQuantityUnit.pack,
          basisValue: 1,
          basisUnit: FoodQuantityUnit.serving,
        ),
        throwsArgumentError,
      );
      expect(
        () => FoodQuantityDefinition.fromJson({
          'value': 1,
          'unit': 'weight',
          'basisValue': null,
          'basisUnit': null,
        }),
        throwsFormatException,
      );
    });
  });

  group('nutrition and provenance', () {
    test('preserves null, explicit zero, partial values, and precision', () {
      final empty = NutritionSnapshot();
      final partial = NutritionSnapshot(calories: 0, protein: 1.23456789);

      expect(NutritionSnapshot.fromJson(empty.toJson()).isEmpty, isTrue);
      final restored = NutritionSnapshot.fromJson(partial.toJson());
      expect(restored.calories, 0);
      expect(restored.fat, isNull);
      expect(restored.protein, 1.23456789);
      expect(
        () => validateNutritionStatus(empty, NutritionStatus.estimated),
        throwsArgumentError,
      );
      expect(
        () => validateNutritionStatus(partial, NutritionStatus.declared),
        returnsNormally,
      );
    });

    test('rejects negative, NaN, and infinite nutrition', () {
      expect(() => NutritionSnapshot(calories: -1), throwsArgumentError);
      expect(() => NutritionSnapshot(protein: double.nan), throwsArgumentError);
      expect(
        () => NutritionSnapshot(fat: double.infinity),
        throwsArgumentError,
      );
    });

    test('uses every formal status and provenance stable ID', () {
      expect(NutritionStatus.values.map((value) => value.stableId), [
        'verified',
        'declared',
        'calculated',
        'estimated',
        'unknown',
      ]);
      expect(FoodProvenanceSourceType.values.map((value) => value.stableId), [
        'manufacturerLabel',
        'manufacturerWebsite',
        'publicDatabase',
        'recipeCalculation',
        'userInput',
        'chatGptEstimate',
        'migration',
        'unknown',
      ]);
      final restored = FoodDataProvenance.fromJson(_provenance().toJson());
      expect(restored.sourceUpdatedAt, _updatedAt);
      expect(restored.toJson(), _provenance().toJson());
      expect(
        () => FoodProvenanceSourceType.fromStableId('api'),
        throwsFormatException,
      );
    });
  });

  group('food catalog and recipe', () {
    test('catalog round trip contains only formal initial fields', () {
      final json = _catalog().toJson();
      final restored = FoodCatalogEntry.fromJson(json);

      expect(restored.toJson(), json);
      expect(json['category'], 'ingredient');
      expect(json['isArchived'], isFalse);
      expect(json, isNot(contains('manufacturer')));
      expect(json, isNot(contains('servingLabel')));
      expect(
        () => FoodCatalogEntry.fromJson({...json, 'barcode': '123'}),
        throwsFormatException,
      );
      expect(
        () => FoodCatalogEntry.fromJson({...json, 'recordVersion': 2}),
        throwsArgumentError,
      );
      expect(
        () => FoodCatalogEntry.fromJson({...json, 'foodId': 'Rice'}),
        throwsArgumentError,
      );
      expect(
        () => FoodCatalogEntry.fromJson({...json, 'foodId': ' $_foodId '}),
        throwsArgumentError,
      );
    });

    test('recipe permits snapshot-only ingredient and keeps list order', () {
      final first = _ingredient(id: _ingredientId1, order: 4);
      final second = _ingredient(
        id: _ingredientId2,
        order: 2,
        foodReferenceId: _foodId,
      );
      final recipe = _recipe(ingredients: [first, second]);
      final restored = FoodRecipeDefinition.fromJson(recipe.toJson());

      expect(restored.ingredients.map((value) => value.ingredientId), [
        _ingredientId1,
        _ingredientId2,
      ]);
      expect(restored.ingredients.first.foodReferenceId, isNull);
      expect(restored.toJson(), recipe.toJson());
      expect(
        () => FoodRecipeDefinition.fromJson({
          ...recipe.toJson(),
          'recordVersion': 2,
        }),
        throwsArgumentError,
      );
    });

    test('recipe rejects empty and duplicate ingredient identities/order', () {
      expect(() => _recipe(ingredients: const []), throwsArgumentError);
      expect(
        () => _recipe(
          ingredients: [
            _ingredient(id: _ingredientId1, order: 0),
            _ingredient(id: _ingredientId1, order: 1),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => _recipe(
          ingredients: [
            _ingredient(id: _ingredientId1, order: 0),
            _ingredient(id: _ingredientId2, order: 0),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('daily meal v2', () {
    test('allows food, recipe, and snapshot-only item references', () {
      final items = [
        _mealItem(id: _mealItemId1, order: 2, foodReferenceId: _foodId),
        _mealItem(id: _mealItemId2, order: 0, recipeReferenceId: _recipeId),
        _mealItem(id: _mealItemId3, order: 1),
      ];
      final meal = _meal(items: items);
      final restored = DailyMealV2.fromJson(meal.toJson());

      expect(restored.items.map((value) => value.mealItemId), [
        _mealItemId1,
        _mealItemId2,
        _mealItemId3,
      ]);
      expect(restored.items[2].foodReferenceId, isNull);
      expect(restored.items[2].recipeReferenceId, isNull);
      expect(restored.items.first.nutritionPerBase.calories, 100);
      expect(restored.items.first.nutritionConsumed.calories, 50);
      expect(
        () => DailyMealV2.fromJson({...meal.toJson(), 'recordVersion': 1}),
        throwsArgumentError,
      );
    });

    test('rejects simultaneous references and duplicate identity/order', () {
      expect(
        () => _mealItem(
          id: _mealItemId1,
          order: 0,
          foodReferenceId: _foodId,
          recipeReferenceId: _recipeId,
        ),
        throwsArgumentError,
      );
      expect(
        () => _meal(
          items: [
            _mealItem(id: _mealItemId1, order: 0),
            _mealItem(id: _mealItemId1, order: 1),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => _meal(
          items: [
            _mealItem(id: _mealItemId1, order: 0),
            _mealItem(id: _mealItemId2, order: 0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('enforces the formal water meal contract', () {
      final water = _meal(
        mealType: DailyMealTypeV2.water,
        items: const [],
        waterMl: 350,
      );
      expect(DailyMealV2.fromJson(water.toJson()).waterMl, 350);
      expect(
        () =>
            _meal(mealType: DailyMealTypeV2.water, items: const [], waterMl: 0),
        throwsArgumentError,
      );
      expect(
        () => _meal(
          mealType: DailyMealTypeV2.water,
          items: [_mealItem(id: _mealItemId1, order: 0)],
          waterMl: 100,
        ),
        throwsArgumentError,
      );
      expect(() => _meal(items: const []), throwsArgumentError);
      expect(() => _meal(waterMl: 250), returnsNormally);
    });

    test('meal type uses six lowercase stable IDs', () {
      expect(DailyMealTypeV2.values.map((value) => value.stableId), [
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'training',
        'water',
      ]);
      expect(
        () => DailyMealTypeV2.fromStableId('Water'),
        throwsFormatException,
      );
    });
  });
}

const _foodId = '11111111-1111-4111-8111-111111111111';
const _recipeId = '22222222-2222-4222-8222-222222222222';
const _ingredientId1 = '33333333-3333-4333-8333-333333333331';
const _ingredientId2 = '33333333-3333-4333-8333-333333333332';
const _mealId = '44444444-4444-4444-8444-444444444444';
const _mealItemId1 = '55555555-5555-4555-8555-555555555551';
const _mealItemId2 = '55555555-5555-4555-8555-555555555552';
const _mealItemId3 = '55555555-5555-4555-8555-555555555553';
final _createdAt = DateTime.utc(2026, 8, 2, 9);
final _updatedAt = DateTime.utc(2026, 8, 2, 10);

FoodDataProvenance _provenance() => FoodDataProvenance(
  sourceType: FoodProvenanceSourceType.userInput,
  sourceName: 'User',
  sourceReference: null,
  capturedAt: _createdAt,
  sourceUpdatedAt: _updatedAt,
  notes: 'Entered manually',
);

NutritionSnapshot _nutrition({double calories = 100}) => NutritionSnapshot(
  calories: calories,
  protein: 10,
  fat: 2.5,
  carbohydrate: 12.25,
);

FoodCatalogEntry _catalog() => FoodCatalogEntry(
  foodId: _foodId,
  name: 'Chicken Breast',
  category: FoodCatalogCategory.ingredient,
  brand: null,
  baseQuantity: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
  nutrition: _nutrition(),
  nutritionStatus: NutritionStatus.declared,
  provenance: _provenance(),
  isArchived: false,
  memo: null,
  createdAt: _createdAt,
  updatedAt: _updatedAt,
);

RecipeIngredientV2 _ingredient({
  required String id,
  required int order,
  String? foodReferenceId,
}) => RecipeIngredientV2(
  ingredientId: id,
  foodReferenceId: foodReferenceId,
  nameSnapshot: 'Chicken Breast',
  quantity: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
  nutritionSnapshot: _nutrition(),
  nutritionStatus: NutritionStatus.declared,
  provenanceSnapshot: _provenance(),
  sortOrder: order,
);

FoodRecipeDefinition _recipe({required List<RecipeIngredientV2> ingredients}) =>
    FoodRecipeDefinition(
      recipeId: _recipeId,
      name: 'Chicken Plate',
      ingredients: ingredients,
      yieldQuantity: FoodQuantityDefinition(
        value: 1,
        unit: FoodQuantityUnit.serving,
      ),
      servingCount: 1,
      nutrition: _nutrition(),
      nutritionStatus: NutritionStatus.calculated,
      provenance: FoodDataProvenance(
        sourceType: FoodProvenanceSourceType.recipeCalculation,
        capturedAt: _createdAt,
      ),
      isArchived: false,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
    );

DailyMealItemSnapshot _mealItem({
  required String id,
  required int order,
  String? foodReferenceId,
  String? recipeReferenceId,
}) => DailyMealItemSnapshot(
  mealItemId: id,
  foodReferenceId: foodReferenceId,
  recipeReferenceId: recipeReferenceId,
  nameSnapshot: 'Chicken Breast',
  category: FoodCatalogCategory.ingredient,
  quantity: FoodQuantityDefinition(value: 50, unit: FoodQuantityUnit.gram),
  nutritionPerBase: _nutrition(),
  nutritionConsumed: _nutrition(calories: 50),
  provenanceSnapshot: _provenance(),
  nutritionStatusSnapshot: NutritionStatus.declared,
  sortOrder: order,
);

DailyMealV2 _meal({
  DailyMealTypeV2 mealType = DailyMealTypeV2.breakfast,
  List<DailyMealItemSnapshot>? items,
  double? waterMl,
}) => DailyMealV2(
  mealId: _mealId,
  localDate: '2026-08-02',
  mealType: mealType,
  items: items ?? [_mealItem(id: _mealItemId1, order: 0)],
  waterMl: waterMl,
  createdAt: _createdAt,
  updatedAt: _updatedAt,
);
