import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../activity/models/persisted_activity_record.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../food/models/persisted_food_record.dart';
import '../../status/models/persisted_status_record.dart';
import '../../training/models/persisted_custom_training_exercise_record.dart';
import '../../training/models/persisted_training_record.dart';
import '../../operation_date/models/operation_state.dart';
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
  };

  static void validateRecord(String section, Map<String, Object?> record) {
    switch (section) {
      case BackupSections.status:
        PersistedStatusRecord.fromRecord(record);
      case BackupSections.activity:
        PersistedActivityRecord.fromRecord(record);
      case BackupSections.food:
        PersistedFoodRecord.fromRecord(record);
      case BackupSections.training:
        PersistedTrainingRecord.fromRecord(record);
      case BackupSections.confirmations:
        PersistedDailyLogConfirmationRecord.fromRecord(record);
      case BackupSections.customExercises:
        PersistedCustomTrainingExerciseRecord.fromRecord(record);
      case BackupSections.operationState:
        OperationState.fromRecord(record);
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
      final id = record['id'] as String;
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
    final id = record['id'];
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
      _ => id.toString(),
    };
  }

  static bool envelopesEqual(
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) =>
      BackupCanonicalCodec.encode(first) == BackupCanonicalCodec.encode(second);

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
