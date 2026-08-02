import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../food/models/persisted_daily_meal_v2_record.dart';
import '../../food/models/recipe_models_v2.dart';
import '../../import_export/models/backup_package.dart';
import '../models/operation_sync_issue.dart';
import '../services/operation_sync_module_adapter.dart';
import '../services/operation_sync_validator.dart';

class FoodOperationSyncAdapter extends IndexedDbOperationTransferModuleAdapter {
  static const _legacyType = 'foodRecord';
  static const _mealType = 'dailyMealV2';
  static const _catalogType = 'foodCatalog';
  static const _recipeType = 'foodRecipe';

  FoodOperationSyncAdapter(IndexedDbDatabase database)
    : super(
        database: database,
        policies: [
          OperationSyncRecordPolicy(
            recordType: _catalogType,
            storeName: IndexedDbStoreNames.foodCatalogRecords,
            backupSection: BackupSections.foodCatalog,
            recordVersions: const {1},
            dateBound: false,
            matches: (record) => record['recordVersion'] == 1,
          ),
          OperationSyncRecordPolicy(
            recordType: _recipeType,
            storeName: IndexedDbStoreNames.foodRecipeRecords,
            backupSection: BackupSections.foodRecipes,
            recordVersions: const {1},
            dateBound: false,
            matches: (record) => record['recordVersion'] == 1,
          ),
          OperationSyncRecordPolicy(
            recordType: _legacyType,
            storeName: IndexedDbStoreNames.foodRecords,
            backupSection: BackupSections.food,
            recordVersions: const {1},
            dateBound: true,
            matches: (record) => record['recordVersion'] == 1,
          ),
          OperationSyncRecordPolicy(
            recordType: _mealType,
            storeName: IndexedDbStoreNames.foodRecords,
            backupSection: BackupSections.food,
            recordVersions: const {2},
            dateBound: true,
            matches: (record) => record['recordVersion'] == 2,
          ),
        ],
      );

  @override
  String get module => 'food';

  @override
  String get schemaVersion => '1.0';

  @override
  Future<List<OperationSyncIssue>> inspectReferences(
    OperationSyncParsedRecord record,
    OperationSyncInspectionContext context,
  ) async {
    final missing = <String>{};
    for (final reference in _references(record)) {
      if (context.containsRecord(
            module: module,
            recordType: reference.recordType,
            recordId: reference.recordId,
          ) ||
          await database.findById(reference.storeName, reference.recordId) !=
              null) {
        continue;
      }
      missing.add('${reference.recordType}:${reference.recordId}');
    }
    return [
      for (final reference in missing)
        OperationSyncIssue(
          level: OperationSyncIssueLevel.blocking,
          code: OperationSyncIssueCode.referenceConflict,
          message: 'FOOD reference is unavailable: $reference.',
          module: module,
          recordId: record.source.recordId,
        ),
    ];
  }

  @override
  Future<void> validateReferencesInTransaction(
    OperationSyncParsedRecord record,
    IndexedDbTransaction transaction,
    OperationSyncInspectionContext context,
  ) async {
    for (final reference in _references(record)) {
      if (await transaction.findById(reference.storeName, reference.recordId) ==
          null) {
        throw const OperationSyncException(
          OperationSyncIssueCode.referenceConflict,
          'FOOD reference is unavailable.',
        );
      }
    }
  }

  Iterable<_FoodReference> _references(OperationSyncParsedRecord record) sync* {
    if (record.envelope.recordType == _recipeType) {
      final recipe = FoodRecipeDefinition.fromJson(record.envelope.record);
      for (final ingredient in recipe.ingredients) {
        final id = ingredient.foodReferenceId;
        if (id != null) {
          yield _FoodReference(
            recordType: _catalogType,
            recordId: id,
            storeName: IndexedDbStoreNames.foodCatalogRecords,
          );
        }
      }
      return;
    }
    if (record.envelope.recordType != _mealType) return;
    final meal = PersistedDailyMealV2Record.fromRecord(
      record.envelope.record,
    ).data;
    for (final item in meal.items) {
      final foodId = item.foodReferenceId;
      if (foodId != null) {
        yield _FoodReference(
          recordType: _catalogType,
          recordId: foodId,
          storeName: IndexedDbStoreNames.foodCatalogRecords,
        );
      }
      final recipeId = item.recipeReferenceId;
      if (recipeId != null) {
        yield _FoodReference(
          recordType: _recipeType,
          recordId: recipeId,
          storeName: IndexedDbStoreNames.foodRecipeRecords,
        );
      }
    }
  }
}

class _FoodReference {
  final String recordType;
  final String recordId;
  final String storeName;

  const _FoodReference({
    required this.recordType,
    required this.recordId,
    required this.storeName,
  });
}
