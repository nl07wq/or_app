import '../../../core/models/food_item.dart' as legacy;
import '../../repositories/repository_exception.dart';
import '../models/daily_meal_v2_models.dart';
import '../models/food_nutrition_aggregate.dart';
import '../models/food_quantity_models.dart';
import '../models/food_unified_read_model.dart';
import '../models/nutrition_models.dart';
import '../models/persisted_food_record.dart';
import '../repository/daily_meal_v2_repository.dart';
import '../repository/indexed_db_food_repository.dart';

class FoodMixedReadService {
  final FoodAuditRepository _legacyRepository;
  final DailyMealV2Repository _v2Repository;

  const FoodMixedReadService({
    required FoodAuditRepository legacyRepository,
    required DailyMealV2Repository v2Repository,
  }) : this._(legacyRepository, v2Repository);

  const FoodMixedReadService._(this._legacyRepository, this._v2Repository);

  Future<List<FoodUnifiedReadModel>> readForLocalDate(String localDate) async {
    final legacyRecords = await _readLegacy();
    final v2Records = await _v2Repository.readForLocalDate(localDate);
    return _validateAndSort([
      ...legacyRecords
          .where((value) => value.localDate == localDate)
          .map(_projectV1),
      ...v2Records.map(_projectV2),
    ], history: false);
  }

  Future<List<FoodUnifiedReadModel>> readHistory() async {
    final legacyRecords = await _readLegacy();
    final v2Records = await _v2Repository.findAll();
    return _validateAndSort([
      ...legacyRecords.map(_projectV1),
      ...v2Records.map(_projectV2),
    ], history: true);
  }

  Future<List<FoodUnifiedReadModel>> readRecent(int limit) async {
    if (limit < 0) throw ArgumentError.value(limit, 'limit');
    final history = await readHistory();
    return List.unmodifiable(history.take(limit));
  }

  Future<FoodUnifiedReadModel?> readByIdentity(
    FoodRecordIdentity identity,
  ) async {
    switch (identity.recordKind) {
      case FoodRecordKind.legacyV1:
        final matches = (await _readLegacy())
            .where((record) => record.data.id == identity.recordId)
            .toList();
        if (matches.length > 1) _duplicate(identity);
        return matches.isEmpty ? null : _projectV1(matches.single);
      case FoodRecordKind.dailyMealV2:
        final meal = await _v2Repository.readById(identity.recordId);
        return meal == null ? null : _projectV2(meal);
    }
  }

  Future<List<PersistedFoodRecord>> _readLegacy() async {
    final result = await _legacyRepository.findAllWithIssues();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'foodMixedRead.legacy',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return result.records;
  }

  static FoodUnifiedReadModel _projectV1(PersistedFoodRecord record) {
    final meal = record.data;
    final items = <FoodUnifiedItemReadModel>[
      for (var index = 0; index < meal.items.length; index++)
        _projectV1Item(meal.id, index, meal.items[index]),
    ];
    return FoodUnifiedReadModel(
      identity: FoodRecordIdentity(FoodRecordKind.legacyV1, meal.id),
      localDate: record.localDate,
      mealType: meal.mealType,
      displayName: _displayName(items, meal.waterMl),
      items: items,
      memo: meal.memo.isEmpty ? null : meal.memo,
      waterMl: meal.waterMl,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      nutritionAggregate: FoodNutritionAggregate.fromSnapshots(
        items.map((value) => value.nutrition),
      ),
    );
  }

  static FoodUnifiedItemReadModel _projectV1Item(
    String recordId,
    int index,
    legacy.FoodItem item,
  ) => FoodUnifiedItemReadModel(
    temporaryKey: '$recordId:$index',
    displayName: item.name,
    quantityLabel: item.hasMeasuredAmount
        ? item.amountMode == legacy.FoodAmountMode.baseMultiplier
              ? 'AMOUNT ${_number(item.amount!)} '
                    '(${_number(item.physicalAmount!)}${item.baseUnit!.label})'
              : '${_number(item.physicalAmount!)}${item.baseUnit!.label}'
        : item.quantity == 1
        ? ''
        : '${item.quantity}',
    nutrition: NutritionSnapshot(
      calories: item.totalCalories,
      protein: item.totalProtein,
      fat: item.totalFat,
      carbohydrate: item.totalCarbohydrate,
    ),
    sourceKind: FoodReadItemSourceKind.legacyV1,
  );

  static FoodUnifiedReadModel _projectV2(DailyMealV2 meal) {
    final items = [
      for (final item in meal.items)
        FoodUnifiedItemReadModel(
          temporaryKey: item.mealItemId,
          displayName: item.nameSnapshot,
          quantityLabel: _quantity(item.quantity),
          nutrition: item.nutritionConsumed,
          catalogReferenceId: item.foodReferenceId,
          recipeReferenceId: item.recipeReferenceId,
          provenance: item.provenanceSnapshot,
          nutritionStatus: item.nutritionStatusSnapshot,
          sourceKind: item.foodReferenceId != null
              ? FoodReadItemSourceKind.foodCatalog
              : item.recipeReferenceId != null
              ? FoodReadItemSourceKind.recipe
              : FoodReadItemSourceKind.snapshotOnly,
        ),
    ];
    return FoodUnifiedReadModel(
      identity: FoodRecordIdentity(FoodRecordKind.dailyMealV2, meal.mealId),
      localDate: meal.localDate,
      mealType: meal.mealType.stableId,
      displayName: _displayName(items, meal.waterMl),
      items: items,
      memo: meal.memo,
      waterMl: meal.waterMl,
      createdAt: meal.createdAt,
      updatedAt: meal.updatedAt,
      nutritionAggregate: FoodNutritionAggregate.fromSnapshots(
        items.map((value) => value.nutrition),
      ),
    );
  }

  static List<FoodUnifiedReadModel> _validateAndSort(
    Iterable<FoodUnifiedReadModel> source, {
    required bool history,
  }) {
    final values = source.toList();
    final identities = <FoodRecordIdentity>{};
    for (final value in values) {
      if (!identities.add(value.identity)) _duplicate(value.identity);
    }
    values.sort((first, second) {
      final byDate = first.localDate.compareTo(second.localDate);
      if (byDate != 0) return history ? -byDate : byDate;
      final byCreated = first.createdAt.compareTo(second.createdAt);
      if (byCreated != 0) return history ? -byCreated : byCreated;
      final byKind = first.identity.recordKind.index.compareTo(
        second.identity.recordKind.index,
      );
      if (byKind != 0) return byKind;
      return first.identity.recordId.compareTo(second.identity.recordId);
    });
    return List.unmodifiable(values);
  }

  static Never _duplicate(FoodRecordIdentity identity) {
    throw RepositoryException(
      operation: 'foodMixedRead.identity',
      code: RepositoryErrorCode.invalidRecord,
      cause: StateError(
        'Duplicate FOOD identity: '
        '${identity.recordKind.name}:${identity.recordId}.',
      ),
    );
  }

  static String _displayName(
    List<FoodUnifiedItemReadModel> items,
    double? waterMl,
  ) => waterMl != null
      ? 'Water'
      : items.map((value) => value.displayName).join(', ');

  static String _quantity(FoodQuantityDefinition quantity) {
    final unit = quantity.unit.stableId;
    return '${_number(quantity.value)} $unit';
  }

  static String _number(num value) {
    final number = value.toDouble();
    return number == number.roundToDouble()
        ? number.round().toString()
        : number.toString();
  }
}
