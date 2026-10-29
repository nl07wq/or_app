import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../reminders/models/reminder_definition.dart';
import '../../schedule/models/schedule_record.dart';
import '../models/notification_time_zone.dart';

class NotificationTimeZoneNormalizationResult {
  const NotificationTimeZoneNormalizationResult({
    required this.alreadyCompleted,
    required this.scheduleSourceTimeZones,
    required this.reminderSourceTimeZones,
    required this.changedScheduleCount,
    required this.changedReminderCount,
  });

  final bool alreadyCompleted;
  final Map<String, int> scheduleSourceTimeZones;
  final Map<String, int> reminderSourceTimeZones;
  final int changedScheduleCount;
  final int changedReminderCount;
}

/// Re-pins local notification records to Tokyo without changing wall-clock
/// fields. The three-store transaction means an interrupted run leaves both
/// record stores unchanged; metadata records completion only after verification.
class NotificationTimeZoneNormalizationService {
  static const migrationId = 'notification_timezone_etc_utc_to_asia_tokyo_v1';

  NotificationTimeZoneNormalizationService(
    this._database, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  Future<NotificationTimeZoneNormalizationResult> migrate() async {
    final completed = await _database.findById(
      IndexedDbStoreNames.migrationMetadata,
      migrationId,
    );
    if (completed != null) {
      final metadata = IndexedDbMigrationMetadata.fromRecord(completed);
      if (metadata.status == IndexedDbMigrationStatus.completed) {
        return NotificationTimeZoneNormalizationResult(
          alreadyCompleted: true,
          scheduleSourceTimeZones: _readZoneCounts(
            metadata.sourceCounts,
            'schedule',
          ),
          reminderSourceTimeZones: _readZoneCounts(
            metadata.sourceCounts,
            'reminder',
          ),
          changedScheduleCount: metadata.validCounts['scheduleChanged'] ?? 0,
          changedReminderCount: metadata.validCounts['reminderChanged'] ?? 0,
        );
      }
    }

    return _database.runTransaction(
      storeNames: const [
        IndexedDbStoreNames.scheduleRecords,
        IndexedDbStoreNames.reminderDefinitions,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final schedules = await transaction.findAll(
          IndexedDbStoreNames.scheduleRecords,
        );
        final reminders = await transaction.findAll(
          IndexedDbStoreNames.reminderDefinitions,
        );

        // Validate every source before writing a single replacement record.
        for (final record in schedules) {
          ScheduleRecord.fromRecord(record);
        }
        for (final record in reminders) {
          ReminderDefinition.fromRecord(record);
        }

        final scheduleCounts = _zoneCounts(schedules);
        final reminderCounts = _zoneCounts(reminders);
        final changedSchedules = schedules
            .where(
              (record) =>
                  record['notificationTimeZone'] !=
                  notificationTimeZoneAsiaTokyo,
            )
            .toList();
        final changedReminders = reminders
            .where(
              (record) =>
                  record['notificationTimeZone'] !=
                  notificationTimeZoneAsiaTokyo,
            )
            .toList();

        for (final record in changedSchedules) {
          await transaction.put(
            IndexedDbStoreNames.scheduleRecords,
            normalizeNotificationTimeZoneRecord(record),
          );
        }
        for (final record in changedReminders) {
          await transaction.put(
            IndexedDbStoreNames.reminderDefinitions,
            normalizeNotificationTimeZoneRecord(record),
          );
        }

        final storedSchedules = await transaction.findAll(
          IndexedDbStoreNames.scheduleRecords,
        );
        final storedReminders = await transaction.findAll(
          IndexedDbStoreNames.reminderDefinitions,
        );
        _verify(schedules, storedSchedules);
        _verify(reminders, storedReminders);

        final timestamp = _now().toUtc();
        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.completed,
          source: 'notification_timezone_normalization',
          targetDatabaseVersion: IndexedDbSchema.databaseVersion,
          attempt: 1,
          startedAt: timestamp,
          updatedAt: timestamp,
          completedAt: timestamp,
          sourceCounts: {
            for (final entry in scheduleCounts.entries)
              'schedule:${entry.key}': entry.value,
            for (final entry in reminderCounts.entries)
              'reminder:${entry.key}': entry.value,
          },
          validCounts: {
            'scheduleRecords': schedules.length,
            'reminderDefinitions': reminders.length,
            'scheduleChanged': changedSchedules.length,
            'reminderChanged': changedReminders.length,
          },
          expectedRecordIds: {
            IndexedDbStoreNames.scheduleRecords: [
              for (final record in schedules) record['id'] as String,
            ]..sort(),
            IndexedDbStoreNames.reminderDefinitions: [
              for (final record in reminders) record['id'] as String,
            ]..sort(),
          },
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          metadata.toRecord(),
        );
        return NotificationTimeZoneNormalizationResult(
          alreadyCompleted: false,
          scheduleSourceTimeZones: scheduleCounts,
          reminderSourceTimeZones: reminderCounts,
          changedScheduleCount: changedSchedules.length,
          changedReminderCount: changedReminders.length,
        );
      },
    );
  }

  static Map<String, int> _zoneCounts(Iterable<Map<String, Object?>> records) {
    final result = <String, int>{};
    for (final record in records) {
      final zone = record['notificationTimeZone'] as String? ?? '<missing>';
      result[zone] = (result[zone] ?? 0) + 1;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, int> _readZoneCounts(
    Map<String, int> source,
    String type,
  ) => Map.unmodifiable({
    for (final entry in source.entries)
      if (entry.key.startsWith('$type:'))
        entry.key.substring(type.length + 1): entry.value,
  });

  static void _verify(
    List<Map<String, Object?>> before,
    List<Map<String, Object?>> after,
  ) {
    final afterById = {
      for (final record in after) record['id'] as String: record,
    };
    if (afterById.length != before.length) {
      throw const FormatException(
        'Notification timezone migration changed record count.',
      );
    }
    for (final record in before) {
      final id = record['id'] as String;
      final restored = afterById[id];
      if (restored == null ||
          restored['notificationTimeZone'] != notificationTimeZoneAsiaTokyo) {
        throw const FormatException(
          'Notification timezone migration verification failed.',
        );
      }
      final expected = normalizeNotificationTimeZoneRecord(record);
      if (!_sameRecord(expected, restored)) {
        throw const FormatException(
          'Notification timezone migration altered a protected field.',
        );
      }
    }
  }

  static bool _sameRecord(
    Map<String, Object?> first,
    Map<String, Object?> second,
  ) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      final value = second[entry.key];
      if (entry.value is List && value is List) {
        if (!_sameList(entry.value as List, value)) return false;
      } else if (entry.value != value) {
        return false;
      }
    }
    return true;
  }

  static bool _sameList(List first, List second) =>
      first.length == second.length &&
      List.generate(
        first.length,
        (index) => index,
      ).every((index) => first[index] == second[index]);
}
