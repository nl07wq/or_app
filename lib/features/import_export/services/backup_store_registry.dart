import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../activity/models/persisted_activity_record.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../food/models/persisted_food_record.dart';
import '../../food/models/persisted_daily_meal_v2_record.dart';
import '../../food/models/food_catalog_models.dart';
import '../../food/models/recipe_models_v2.dart';
import '../../food/services/food_v2_canonical_service.dart';
import '../../status/models/persisted_status_record.dart';
import '../../training/models/persisted_custom_training_exercise_record.dart';
import '../../training/models/persisted_training_record.dart';
import '../../operation_date/models/operation_state.dart';
import '../../operation_sync/models/operation_sync_history.dart';
import '../models/backup_package.dart';
import 'backup_canonical_codec.dart';

abstract final class BackupStoreRegistry {
  static const stores = <String, String>{
    BackupSections.status: IndexedDbStoreNames.statusRecords,
    BackupSections.activity: IndexedDbStoreNames.activityRecords,
    BackupSections.food: IndexedDbStoreNames.foodRecords,
    BackupSections.training: IndexedDbStoreNames.trainingRecords,
    BackupSections.confirmations: IndexedDbStoreNames.dailyLogConfirmations,
    BackupSections.customExercises: IndexedDbStoreNames.customTrainingExercises,
    BackupSections.operationState: IndexedDbStoreNames.operationState,
    BackupSections.foodCatalog: IndexedDbStoreNames.foodCatalogRecords,
    BackupSections.foodRecipes: IndexedDbStoreNames.foodRecipeRecords,
    BackupSections.operationSyncHistory:
        IndexedDbStoreNames.operationSyncHistory,
  };

  static void validateRecord(String section, Map<String, Object?> record) {
    switch (section) {
      case BackupSections.status:
        PersistedStatusRecord.fromRecord(record);
      case BackupSections.activity:
        PersistedActivityRecord.fromRecord(record);
      case BackupSections.food:
        if (record['recordVersion'] == 2) {
          PersistedDailyMealV2Record.fromRecord(record);
        } else {
          PersistedFoodRecord.fromRecord(record);
        }
      case BackupSections.training:
        PersistedTrainingRecord.fromRecord(record);
      case BackupSections.confirmations:
        PersistedDailyLogConfirmationRecord.fromRecord(record);
      case BackupSections.customExercises:
        PersistedCustomTrainingExerciseRecord.fromRecord(record);
      case BackupSections.operationState:
        OperationState.fromRecord(record);
      case BackupSections.foodCatalog:
        FoodCatalogEntry.fromJson(record);
      case BackupSections.foodRecipes:
        FoodRecipeDefinition.fromJson(record);
      case BackupSections.operationSyncHistory:
        OperationSyncHistory.fromRecord(record);
      default:
        throw BackupException('unknown_section', 'Unknown section: $section.');
    }
  }

  static List<Map<String, Object?>> validateAndSort(
    String section,
    Iterable<Map<String, Object?>> records,
  ) {
    final result = <Map<String, Object?>>[];
    final ids = <String>{};
    final canonicalDates = <String>{};
    final normalizedNames = <String>{};
    for (final source in records) {
      final record = _deepCopyMap(source);
      validateRecord(section, record);
      final id = recordId(section, record);
      if (!ids.add(id)) {
        throw BackupException(
          'duplicate_id',
          '$section contains duplicate ID $id.',
        );
      }
      final canonicalDate = record['canonicalDate'];
      if ((section == BackupSections.status ||
              section == BackupSections.activity) &&
          canonicalDate is String) {
        if (!canonicalDates.add(canonicalDate)) {
          throw BackupException(
            'unique_index_conflict',
            '$section contains duplicate canonicalDate $canonicalDate.',
          );
        }
      }
      if (section == BackupSections.customExercises) {
        final normalizedName = record['normalizedName'] as String;
        if (!normalizedNames.add(normalizedName)) {
          throw BackupException(
            'unique_index_conflict',
            '$section contains duplicate normalizedName $normalizedName.',
          );
        }
      }
      result.add(record);
    }
    result.sort((a, b) => _sortKey(section, a).compareTo(_sortKey(section, b)));
    return List.unmodifiable(result);
  }

  static String _sortKey(String section, Map<String, Object?> record) {
    final id = recordId(section, record);
    return switch (section) {
      BackupSections.status || BackupSections.activity =>
        '${record['localDate']}\u0000'
            '${record['recordKind'] == 'canonical' ? '0' : '1'}\u0000$id',
      BackupSections.food =>
        '${record['localDate']}\u0000${record['createdAt']}\u0000$id',
      BackupSections.training =>
        '${record['localDate']}\u0000'
            '${(record['data'] as Map)['date']}\u0000$id',
      BackupSections.confirmations => '${record['localDate']}\u0000$id',
      BackupSections.customExercises => '${record['normalizedName']}\u0000$id',
      BackupSections.operationState => id.toString(),
      BackupSections.foodCatalog || BackupSections.foodRecipes => id,
      BackupSections.operationSyncHistory =>
        '${record['completedAt']}\u0000$id',
      _ => id.toString(),
    };
  }

  static bool envelopesEqual(
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) =>
      BackupCanonicalCodec.encode(first) == BackupCanonicalCodec.encode(second);

  static bool recordsEqual(
    String section,
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) {
    if (section == BackupSections.foodCatalog ||
        section == BackupSections.foodRecipes) {
      return FoodV2CanonicalService.digest(first) ==
          FoodV2CanonicalService.digest(second);
    }
    if (section == BackupSections.food &&
        first['recordVersion'] == 2 &&
        second['recordVersion'] == 2) {
      final firstData = first['data'];
      final secondData = second['data'];
      if (firstData is Map && secondData is Map) {
        return FoodV2CanonicalService.digest(
              Map<String, Object?>.from(firstData),
            ) ==
            FoodV2CanonicalService.digest(
              Map<String, Object?>.from(secondData),
            );
      }
    }
    return envelopesEqual(first, second);
  }

  static String recordId(String section, Map<String, Object?> record) {
    final key = switch (section) {
      BackupSections.foodCatalog => 'foodId',
      BackupSections.foodRecipes => 'recipeId',
      BackupSections.operationSyncHistory => 'operationId',
      _ => 'id',
    };
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw BackupException('invalid_record', '$section has an invalid ID.');
    }
    return value;
  }

  static Map<String, Object?> _deepCopyMap(Map source) => {
    for (final entry in source.entries)
      entry.key.toString(): _deepCopyValue(entry.value),
  };

  static Object? _deepCopyValue(Object? value) {
    if (value is Map) return _deepCopyMap(value);
    if (value is Iterable) {
      return [for (final item in value) _deepCopyValue(item)];
    }
    return value;
  }
}
