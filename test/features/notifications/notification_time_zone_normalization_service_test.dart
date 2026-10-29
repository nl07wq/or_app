import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/notifications/models/notification_time_zone.dart';
import 'package:or_app/features/notifications/models/notification_configuration.dart';
import 'package:or_app/features/notifications/services/notification_projection.dart';
import 'package:or_app/features/notifications/services/notification_profile_controller.dart';
import 'package:or_app/features/notifications/services/notification_time_zone_normalization_service.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/repository/indexed_db_reminder_repository.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  group('notification timezone normalization', () {
    test('new notification configuration is pinned to Asia/Tokyo', () {
      expect(
        NotificationProfileController().timeZone,
        notificationTimeZoneAsiaTokyo,
      );
    });

    test('new reminder saves are pinned to Asia/Tokyo', () async {
      final database = FakeIndexedDbDatabase();
      await IndexedDbReminderRepository(database).saveDefinition(
        _reminder(id: 'new-reminder', zone: 'Etc/UTC'),
      );
      expect(
        database.rawRecord(
          IndexedDbStoreNames.reminderDefinitions,
          'new-reminder',
        )?['notificationTimeZone'],
        notificationTimeZoneAsiaTokyo,
      );
    });

    test(
      'migrates legacy, missing, recurring, historical and inactive records atomically',
      () async {
        final database = FakeIndexedDbDatabase();
        final legacySchedule = _schedule(
          id: 'series',
          zone: 'Etc/UTC',
          recurrence: ReminderRecurrence.weekly,
        ).toRecord();
        final missingSchedule =
            _schedule(id: 'completed', zone: null).toRecord()
              ..remove('notificationTimeZone')
              ..['completed'] = true;
        final legacyReminder = _reminder(
          id: 'inactive',
          zone: 'Etc/UTC',
          active: false,
        ).toRecord();
        final tokyoReminder = _reminder(
          id: 'tokyo',
          zone: notificationTimeZoneAsiaTokyo,
        ).toRecord();
        database.seed(
          IndexedDbStoreNames.scheduleRecords,
          'series',
          legacySchedule,
        );
        database.seed(
          IndexedDbStoreNames.scheduleRecords,
          'completed',
          missingSchedule,
        );
        database.seed(
          IndexedDbStoreNames.reminderDefinitions,
          'inactive',
          legacyReminder,
        );
        database.seed(
          IndexedDbStoreNames.reminderDefinitions,
          'tokyo',
          tokyoReminder,
        );

        final result = await NotificationTimeZoneNormalizationService(
          database,
          now: () => DateTime.utc(2026, 10, 1),
        ).migrate();

        expect(result.alreadyCompleted, isFalse);
        expect(result.scheduleSourceTimeZones, {'Etc/UTC': 1, '<missing>': 1});
        expect(result.reminderSourceTimeZones, {
          'Etc/UTC': 1,
          notificationTimeZoneAsiaTokyo: 1,
        });
        expect(result.changedScheduleCount, 2);
        expect(result.changedReminderCount, 1);
        for (final id in ['series', 'completed']) {
          expect(
            database.rawRecord(
              IndexedDbStoreNames.scheduleRecords,
              id,
            )?['notificationTimeZone'],
            notificationTimeZoneAsiaTokyo,
          );
        }
        for (final id in ['inactive', 'tokyo']) {
          expect(
            database.rawRecord(
              IndexedDbStoreNames.reminderDefinitions,
              id,
            )?['notificationTimeZone'],
            notificationTimeZoneAsiaTokyo,
          );
        }
        expect(
          database.rawRecord(
            IndexedDbStoreNames.scheduleRecords,
            'series',
          )?['startTime'],
          '15:15',
        );
        expect(
          database.rawRecord(
            IndexedDbStoreNames.scheduleRecords,
            'completed',
          )?['completed'],
          isTrue,
        );

        final rerun = await NotificationTimeZoneNormalizationService(
          database,
        ).migrate();
        expect(rerun.alreadyCompleted, isTrue);
        expect(rerun.changedScheduleCount, 2);
      },
    );

    test(
      'a write failure rolls back both stores and does not claim completion',
      () async {
        final database = FakeIndexedDbDatabase()
          ..failNextPutForStore = IndexedDbStoreNames.reminderDefinitions;
        database.seed(
          IndexedDbStoreNames.scheduleRecords,
          'schedule',
          _schedule(id: 'schedule', zone: 'Etc/UTC').toRecord(),
        );
        database.seed(
          IndexedDbStoreNames.reminderDefinitions,
          'reminder',
          _reminder(id: 'reminder', zone: 'Etc/UTC').toRecord(),
        );

        await expectLater(
          NotificationTimeZoneNormalizationService(database).migrate(),
          throwsA(isA<Object>()),
        );

        expect(
          database.rawRecord(
            IndexedDbStoreNames.scheduleRecords,
            'schedule',
          )?['notificationTimeZone'],
          'Etc/UTC',
        );
        expect(
          database.rawRecord(
            IndexedDbStoreNames.reminderDefinitions,
            'reminder',
          )?['notificationTimeZone'],
          'Etc/UTC',
        );
        expect(
          database.rawRecord(
            IndexedDbStoreNames.migrationMetadata,
            NotificationTimeZoneNormalizationService.migrationId,
          ),
          isNull,
        );
      },
    );

    test(
      'Tokyo wall-time projection keeps 15:15 and fires fifteen minutes earlier',
      () {
        int resolve(String date, String time, String zone) {
          expect(zone, notificationTimeZoneAsiaTokyo);
          return DateTime.parse(
            '$date'
            'T$time:00+09:00',
          ).millisecondsSinceEpoch;
        }

        final projections = NotificationProjectionPlanner(resolve).project(
          const [
            NotificationSourceOccurrence(
              entityType: 'schedule',
              entityId: 'appointment',
              localDate: '2026-10-08',
              allDay: false,
              startTime: '15:15',
              timeZone: notificationTimeZoneAsiaTokyo,
              offsetsMinutes: [15],
              title: 'appointment',
            ),
          ],
          privacyMode: NotificationPrivacyMode.titleVisible,
          now: DateTime.utc(2026, 10, 1),
        );

        expect(projections.single.triggerAt, DateTime.utc(2026, 10, 8, 6));
      },
    );

    test(
      'backup restoration normalizes timezone without changing wall time',
      () {
        final source = _schedule(id: 'backup', zone: 'Etc/UTC').toRecord();
        final restored = BackupStoreRegistry.normalizeForImport(
          BackupSections.schedules,
          source,
        );
        expect(restored['notificationTimeZone'], notificationTimeZoneAsiaTokyo);
        expect(restored['localDate'], '2026-10-08');
        expect(restored['startTime'], '15:15');
        expect(restored['createdAt'], source['createdAt']);
        expect(restored['updatedAt'], source['updatedAt']);
      },
    );
  });
}

ScheduleRecord _schedule({
  required String id,
  required String? zone,
  ReminderRecurrence recurrence = ReminderRecurrence.none,
}) => ScheduleRecord(
  id: id,
  localDate: '2026-10-08',
  type: ScheduleType.appointment,
  title: 'appointment',
  startTime: '15:15',
  recurrence: recurrence,
  notificationOffsetsMinutes: const [15],
  notificationTimeZone: zone ?? notificationTimeZoneAsiaTokyo,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 2),
);

ReminderDefinition _reminder({
  required String id,
  required String zone,
  bool active = true,
}) => ReminderDefinition(
  id: id,
  title: 'reminder',
  startDate: '2026-10-08',
  allDay: false,
  time: '15:15',
  recurrence: ReminderRecurrence.daily,
  notificationOffsetsMinutes: const [15],
  notificationTimeZone: zone,
  active: active,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 2),
);
