import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/services/food_v2_canonical_service.dart';

void main() {
  group('strict serialization', () {
    test('rejects unknown, missing, and mistyped fields without defaults', () {
      final json = _catalog().toJson();
      expect(
        () => FoodCatalogEntry.fromJson({...json, 'future': true}),
        throwsFormatException,
      );
      final missing = Map<String, Object?>.from(json)..remove('brand');
      expect(() => FoodCatalogEntry.fromJson(missing), throwsFormatException);
      expect(
        () => FoodCatalogEntry.fromJson({...json, 'recordVersion': '1'}),
        throwsFormatException,
      );
      expect(
        () => FoodCatalogEntry.fromJson({...json, 'createdAt': null}),
        throwsFormatException,
      );
    });

    test('preserves null, zero, and item list order', () {
      final first = _item(_itemId1, 7);
      final second = _item(_itemId2, 2);
      final meal = DailyMealV2(
        mealId: _mealId,
        localDate: '2026-08-02',
        mealType: DailyMealTypeV2.lunch,
        items: [first, second],
        memo: null,
        waterMl: null,
        createdAt: _createdAt,
        updatedAt: _updatedAt,
      );
      final restored = DailyMealV2.fromJson(meal.toJson());

      expect(restored.items.map((value) => value.mealItemId), [
        _itemId1,
        _itemId2,
      ]);
      expect(restored.items.first.nutritionConsumed.calories, 0);
      expect(restored.items.first.nutritionConsumed.fat, isNull);
      expect(restored.memo, isNull);
    });
  });

  group('canonical representation', () {
    test('excludes record timestamps but includes domain snapshots', () {
      final first = _catalog().toJson();
      final second = {
        ...first,
        'createdAt': DateTime.utc(2026, 8, 3).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 8, 4).toIso8601String(),
      };

      expect(
        FoodV2CanonicalService.digest(first),
        FoodV2CanonicalService.digest(second),
      );
      expect(FoodV2CanonicalService.value(first), isNot(contains('createdAt')));
      expect(FoodV2CanonicalService.value(first), isNot(contains('updatedAt')));
      expect(FoodV2CanonicalService.value(first), contains('provenance'));
    });

    test('fixes map key order while retaining list order, null, and zero', () {
      final first = <String, Object?>{
        'recordVersion': 2,
        'mealId': _mealId,
        'items': [
          {'value': 0, 'reference': null},
          {'value': 1, 'reference': _foodId},
        ],
        'createdAt': _createdAt.toIso8601String(),
        'updatedAt': _updatedAt.toIso8601String(),
      };
      final reordered = <String, Object?>{
        'updatedAt': _updatedAt.toIso8601String(),
        'items': first['items'],
        'mealId': _mealId,
        'createdAt': _createdAt.toIso8601String(),
        'recordVersion': 2,
      };
      final reversedList = {
        ...first,
        'items': (first['items'] as List).reversed.toList(),
      };

      expect(
        FoodV2CanonicalService.encode(first),
        FoodV2CanonicalService.encode(reordered),
      );
      expect(
        FoodV2CanonicalService.digest(first),
        isNot(FoodV2CanonicalService.digest(reversedList)),
      );
      expect(FoodV2CanonicalService.encode(first), contains('null'));
      expect(FoodV2CanonicalService.encode(first), contains('0'));
    });
  });
}

const _foodId = '11111111-1111-4111-8111-111111111111';
const _mealId = '44444444-4444-4444-8444-444444444444';
const _itemId1 = '55555555-5555-4555-8555-555555555551';
const _itemId2 = '55555555-5555-4555-8555-555555555552';
final _createdAt = DateTime.utc(2026, 8, 2, 9);
final _updatedAt = DateTime.utc(2026, 8, 2, 10);

FoodDataProvenance _provenance() => FoodDataProvenance(
  sourceType: FoodProvenanceSourceType.userInput,
  sourceName: null,
  sourceReference: null,
  capturedAt: _createdAt,
  sourceUpdatedAt: null,
  notes: null,
);

FoodCatalogEntry _catalog() => FoodCatalogEntry(
  foodId: _foodId,
  name: 'Rice',
  category: FoodCatalogCategory.ingredient,
  brand: null,
  baseQuantity: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
  nutrition: NutritionSnapshot(calories: 156, carbohydrate: 35.6),
  nutritionStatus: NutritionStatus.declared,
  provenance: _provenance(),
  isArchived: false,
  memo: null,
  createdAt: _createdAt,
  updatedAt: _updatedAt,
);

DailyMealItemSnapshot _item(String id, int order) => DailyMealItemSnapshot(
  mealItemId: id,
  nameSnapshot: 'Rice',
  category: null,
  quantity: FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.serving),
  nutritionPerBase: NutritionSnapshot(calories: 0),
  nutritionConsumed: NutritionSnapshot(calories: 0),
  provenanceSnapshot: _provenance(),
  nutritionStatusSnapshot: NutritionStatus.declared,
  sortOrder: order,
);
