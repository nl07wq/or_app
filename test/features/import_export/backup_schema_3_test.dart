import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_canonical_codec.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
  });

  test('Schema 3.0 export requires canonical operation state', () async {
    await expectLater(
      BackupExportService(database: database, controller: controller).create(),
      throwsA(
        isA<BackupException>().having(
          (error) => error.code,
          'code',
          'invalid_operation_state_count',
        ),
      ),
    );
  });

  test('Schema 3.0 round trips operation state with package digests', () async {
    final state = _openState('2026-08-01');
    database.seed(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
      state.toRecord(),
    );
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();

    expect(package.schemaVersion, 4);
    expect(package.data[BackupSections.operationState], [state.toRecord()]);
    expect(package.recordCounts[BackupSections.operationState], 1);
    expect(package.digests.sections[BackupSections.operationState], isNotEmpty);
    expect(
      const BackupPackageCodec()
          .decode(BackupExportService.encode(package))
          .data,
      package.data,
    );
  });

  test(
    'Schema 3.0 MERGE skips identical state and blocks different state',
    () async {
      final state = _openState('2026-08-01');
      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        state.toRecord(),
      );
      final package = await BackupExportService(
        database: database,
        controller: controller,
      ).create();
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );

      final identical = await service.dryRun(package, BackupImportMode.merge);
      expect(identical.sections[BackupSections.operationState]!.skip, 1);
      expect(identical.hasConflicts, isFalse);

      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        _openState('2026-08-02').toRecord(),
      );
      final changed = await service.dryRun(package, BackupImportMode.merge);
      expect(changed.hasConflicts, isTrue);
      expect((await service.execute(changed)).errorCode, 'import_conflict');
    },
  );

  test('Schema 3.0 REPLACE ALL restores operation state atomically', () async {
    final incoming = _openState('2026-08-01');
    final package = _packageFor(incoming);
    database.seed(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
      _openState('2026-08-02').toRecord(),
    );
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );

    final plan = await service.dryRun(package, BackupImportMode.replaceAll);
    final result = await service.execute(plan);
    expect(result.success, isTrue);
    expect(result.operationStateRestored, isTrue);
    expect(result.recoveryRequired, isFalse);
    expect(
      await database.findById(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
      ),
      incoming.toRecord(),
    );
  });

  test(
    'Schema 3.0 REPLACE ALL rolls back operation state with other stores',
    () async {
      final original = _openState('2026-08-02');
      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        original.toRecord(),
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );
      final plan = await service.dryRun(
        _packageFor(_openState('2026-08-01')),
        BackupImportMode.replaceAll,
      );
      database.failNextTransactionWith = StateError('write failed');

      expect((await service.execute(plan)).success, isFalse);
      expect(
        await database.findById(
          IndexedDbStoreNames.operationState,
          OperationState.canonicalId,
        ),
        original.toRecord(),
      );
    },
  );

  test(
    'Schema 3.0 processing state blocks MERGE and permits exact REPLACE ALL',
    () async {
      final date = DateTime(2026, 7, 26);
      final confirmation = PersistedDailyLogConfirmationRecord(
        id: 'confirmation:2026-07-26',
        localDate: '2026-07-26',
        createdAt: DateTime.utc(2026, 7, 26, 12),
        updatedAt: DateTime.utc(2026, 7, 26, 12),
        data: completeConfirmation(date: date),
      );
      final digest = BackupCanonicalCodec.digest(confirmation.data.toJson());
      final timestamp = DateTime.utc(2026, 7, 26, 12);
      final state = OperationState(
        operationDate: OperationLocalDate.parse('2026-07-26'),
        phase: OperationPhase.finalizedPendingBackup,
        activeAttempt: OperationActiveAttempt(
          idempotencyKey: 'attempt-1',
          targetLocalDate: OperationLocalDate.parse('2026-07-26'),
          startedAt: timestamp,
          confirmationId: confirmation.id,
          confirmationDigest: digest,
        ),
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final package = _packageFor(state, confirmation: confirmation.toRecord());
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );

      expect(
        (await service.dryRun(package, BackupImportMode.merge)).hasConflicts,
        isTrue,
      );
      final replace = await service.dryRun(
        package,
        BackupImportMode.replaceAll,
      );
      expect((await service.execute(replace)).success, isTrue);
      final restored = OperationState.fromRecord(
        (await database.findById(
          IndexedDbStoreNames.operationState,
          OperationState.canonicalId,
        ))!,
      );
      expect(restored.requiresRecovery, isTrue);
    },
  );

  test('Schema 3.0 rejects operation state section and package tampering', () {
    final package = _packageFor(_openState('2026-08-01'));
    final json = jsonDecode(BackupExportService.encode(package)) as Map;
    (json['data'] as Map)[BackupSections.operationState] = <Object?>[];

    expect(
      () => const BackupPackageCodec().decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test(
    'Schema 3.0 keeps advancing backup audit digest without self-reference',
    () {
      final date = DateTime(2026, 7, 26);
      final confirmation = PersistedDailyLogConfirmationRecord(
        id: 'confirmation:2026-07-26',
        localDate: '2026-07-26',
        createdAt: DateTime.utc(2026, 7, 26, 12),
        updatedAt: DateTime.utc(2026, 7, 26, 12),
        data: completeConfirmation(date: date),
      );
      final timestamp = DateTime.utc(2026, 7, 26, 12);
      final state = OperationState(
        operationDate: OperationLocalDate.parse('2026-07-26'),
        phase: OperationPhase.advancing,
        activeAttempt: OperationActiveAttempt(
          idempotencyKey: 'attempt-2',
          targetLocalDate: OperationLocalDate.parse('2026-07-26'),
          startedAt: timestamp,
          confirmationId: confirmation.id,
          confirmationDigest: BackupCanonicalCodec.digest(
            confirmation.data.toJson(),
          ),
          backupPackageDigest: 'previous-export-audit-digest',
          backupGeneratedAt: timestamp,
        ),
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      final package = _packageFor(state, confirmation: confirmation.toRecord());

      expect(package.digests.package, isNot('previous-export-audit-digest'));
      expect(
        (package.data[BackupSections.operationState]!.single['activeAttempt']
            as Map)['backupPackageDigest'],
        'previous-export-audit-digest',
      );
    },
  );
}

OperationState _openState(String localDate) {
  final timestamp = DateTime.utc(2026, 8, 1);
  return OperationState(
    operationDate: OperationLocalDate.parse(localDate),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

BackupPackage _packageFor(
  OperationState state, {
  Map<String, Object?>? confirmation,
}) {
  return BackupExportService.buildPackage(
    schemaVersion: 3,
    exportId: 'schema-3-test',
    exportedAt: DateTime.utc(2026, 8, 1),
    source: const BackupSource(platform: 'test'),
    data: {
      for (final section in BackupSections.schema3)
        section: section == BackupSections.operationState
            ? [state.toRecord()]
            : section == BackupSections.confirmations && confirmation != null
            ? [confirmation]
            : [],
    },
  );
}
