import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_v14_transform.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/models/reminder_occurrence.dart';
import 'package:or_app/features/reminders/repository/indexed_db_reminder_repository.dart';
import 'package:or_app/features/reminders/services/reminder_occurrence_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'v18 export and import preserve definition, boundary, completion, and SKIPPED',
    () async {
      final timestamp = DateTime.utc(2026, 10, 4, 12);
      final definition = ReminderDefinition(
        id: 'daily',
        title: 'Daily',
        startDate: '2026-10-01',
        allDay: true,
        recurrence: ReminderRecurrence.daily,
        recurrenceEnd: '2026-10-05',
        active: true,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final completed = ReminderOccurrenceState(
        id: 'daily@2026-10-02',
        definitionId: 'daily',
        localDate: '2026-10-02',
        status: ReminderOccurrenceStatus.completed,
        updatedAt: timestamp,
        completedAt: timestamp,
      );
      final skipped = ReminderOccurrenceState(
        id: 'daily@2026-10-03',
        definitionId: 'daily',
        localDate: '2026-10-03',
        status: ReminderOccurrenceStatus.skipped,
        updatedAt: timestamp,
      );
      final source = FakeIndexedDbDatabase();
      source.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-10-04'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      source.seed(
        IndexedDbStoreNames.reminderDefinitions,
        definition.id,
        definition.toRecord(),
      );
      source.seed(
        IndexedDbStoreNames.reminderOccurrenceStates,
        completed.id,
        completed.toRecord(),
      );
      source.seed(
        IndexedDbStoreNames.reminderOccurrenceStates,
        skipped.id,
        skipped.toRecord(),
      );

      final bundle = await BackupExportService(
        database: source,
        controller: AppInitializationController()..markReady(),
        clock: () => timestamp,
      ).createCurrentBundle();
      expect(bundle.normal.schemaVersion, 18);
      expect(bundle.normal.databaseVersion, IndexedDbSchema.databaseVersion);
      expect(bundle.normal.data[BackupSections.reminderDefinitions], [
        definition.toRecord(),
      ]);
      expect(bundle.normal.data[BackupSections.reminderOccurrenceStates], [
        completed.toRecord(),
        skipped.toRecord(),
      ]);

      final hydrated = BackupV14Transform.hydratePackage(
        bundle.normal,
        bundle.audit,
      );
      final target = FakeIndexedDbDatabase();
      final importer = BackupImportService(
        database: target,
        controller: AppInitializationController()..markReady(),
        restore: () async {},
      );
      final result = await importer.execute(
        await importer.dryRun(hydrated, BackupImportMode.replaceAll),
      );
      expect(result.success, isTrue);
      final repository = IndexedDbReminderRepository(target);
      expect(
        (await repository.findDefinitions()).single.recurrenceEnd,
        '2026-10-05',
      );
      expect((await repository.findStates()).map((value) => value.status), [
        ReminderOccurrenceStatus.completed,
        ReminderOccurrenceStatus.skipped,
      ]);

      final projection = await ReminderOccurrenceService(repository).inRange(
        DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 7)),
      );
      expect(projection.map((value) => value.localDate), [
        '2026-10-01',
        '2026-10-02',
        '2026-10-04',
        '2026-10-05',
      ]);
      expect(
        projection
            .singleWhere((value) => value.localDate == '2026-10-02')
            .status,
        ReminderOccurrenceStatus.completed,
      );
    },
  );
}
