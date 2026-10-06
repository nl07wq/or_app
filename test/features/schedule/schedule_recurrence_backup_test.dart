import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_v14_transform.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/repository/indexed_db_schedule_repository.dart';
import 'package:or_app/features/schedule/services/schedule_recurrence_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'Backup and Device Transfer restore recurrence, exceptions, and split series',
    () async {
      final timestamp = DateTime.utc(2026, 1, 1, 12);
      final source = FakeIndexedDbDatabase();
      source.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-01-20'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      final schedules = IndexedDbScheduleRepository(
        source,
        now: () => timestamp,
      );
      await schedules.save(
        _record(
          id: 'series-old',
          date: '2026-01-05',
          title: 'Original',
          recurrence: ReminderRecurrence.weekly,
          recurrenceEnd: '2026-01-18',
        ),
      );
      await schedules.save(
        _record(
          id: 'series-old@2026-01-12',
          seriesId: 'series-old',
          occurrenceDate: '2026-01-12',
          date: '2026-01-13',
          title: 'Moved',
        ),
      );
      await schedules.save(
        _record(
          id: 'series-new',
          seriesId: 'series-new',
          date: '2026-01-19',
          title: 'Future',
          recurrence: ReminderRecurrence.weekly,
        ),
      );
      await schedules.save(
        _record(
          id: 'series-new@2026-01-26',
          seriesId: 'series-new',
          occurrenceDate: '2026-01-26',
          date: '2026-01-26',
          title: 'Future',
          occurrenceExcluded: true,
        ),
      );

      final sourceProjection = await _projection(schedules);
      final bundle = await BackupExportService(
        database: source,
        controller: AppInitializationController()..markReady(),
        clock: () => timestamp,
      ).createCurrentBundle();
      expect(bundle.normal.data[BackupSections.schedules], hasLength(4));

      // Device Transfer's formal full-data path is BACKUP & RESTORE. Hydrating
      // the transport bundle exercises the same export/import serialization.
      final target = FakeIndexedDbDatabase();
      final importer = BackupImportService(
        database: target,
        controller: AppInitializationController()..markReady(),
        restore: () async {},
      );
      final hydrated = BackupV14Transform.hydratePackage(
        bundle.normal,
        bundle.audit,
      );
      final result = await importer.execute(
        await importer.dryRun(hydrated, BackupImportMode.replaceAll),
      );
      expect(result.success, isTrue);

      final restored = IndexedDbScheduleRepository(target);
      expect(await _projection(restored), sourceProjection);
      final records = await restored.findAll();
      expect(
        records.singleWhere((value) => value.id == 'series-old').recurrenceEnd,
        '2026-01-18',
      );
      expect(
        records
            .singleWhere((value) => value.id == 'series-new@2026-01-26')
            .occurrenceExcluded,
        isTrue,
      );
    },
  );
}

Future<List<String>> _projection(IndexedDbScheduleRepository repository) async {
  final values = await ScheduleRecurrenceService(repository).inRange(
    DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
  );
  return values
      .map((value) => '${value.id}:${value.localDate}:${value.title}')
      .toList();
}

ScheduleRecord _record({
  required String id,
  String? seriesId,
  String? occurrenceDate,
  required String date,
  required String title,
  ReminderRecurrence recurrence = ReminderRecurrence.none,
  String? recurrenceEnd,
  bool occurrenceExcluded = false,
}) => ScheduleRecord(
  id: id,
  seriesId: seriesId,
  occurrenceDate: occurrenceDate,
  occurrenceExcluded: occurrenceExcluded,
  localDate: date,
  type: ScheduleType.personal,
  title: title,
  recurrence: recurrence,
  recurrenceEnd: recurrenceEnd,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
