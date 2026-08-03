import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/models/daily_log_confirmation_lifecycle.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 4, 12);

  test('Schema 10 restores mixed Confirmation v1 and reopened v2', () async {
    final source = FakeIndexedDbDatabase();
    source.seed(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
      OperationState(
        operationDate: OperationLocalDate.parse('2026-08-04'),
        createdAt: timestamp,
        updatedAt: timestamp,
      ).toRecord(),
    );
    final v1 = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-08-01',
      localDate: '2026-08-01',
      createdAt: DateTime.utc(2026, 8, 1, 22),
      updatedAt: DateTime.utc(2026, 8, 1, 22),
      data: completeConfirmation(
        date: DateTime(2026, 8, 1),
        confirmedAt: DateTime.utc(2026, 8, 1, 22),
      ),
    ).toRecord();
    final snapshot = completeConfirmation(
      date: DateTime(2026, 8, 2),
      confirmedAt: DateTime.utc(2026, 8, 2, 22),
    );
    final digest = PersistedDailyLogConfirmationRecord.digestSnapshot(snapshot);
    final v2 = PersistedDailyLogConfirmationRecord.v2(
      id: 'confirmation:2026-08-02',
      localDate: '2026-08-02',
      lifecycleStatus: DailyLogConfirmationLifecycleStatus.reopened,
      revision: 1,
      data: snapshot,
      snapshotDigest: digest,
      originalSnapshotDigest: digest,
      finalizedAt: snapshot.confirmedAt,
      reopenedAt: DateTime.utc(2026, 8, 3),
      lastRefinalizedAt: null,
      reopenReason: DailyLogConfirmationReopenReason.userCorrection,
      sourceRecordVersions:
          const DailyLogConfirmationSourceRecordVersions.unknown(),
      previousRevisions: const [],
      createdAt: DateTime.utc(2026, 8, 2, 22),
      updatedAt: DateTime.utc(2026, 8, 3),
    ).toRecord();
    source.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      v1['id']! as String,
      v1,
    );
    source.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      v2['id']! as String,
      v2,
    );
    final controller = AppInitializationController()..markReady();
    final exported = await BackupExportService(
      database: source,
      controller: controller,
      clock: () => timestamp,
    ).create();
    final decoded = const BackupPackageCodec().decode(
      BackupExportService.encode(exported),
    );

    expect(decoded.schemaVersion, 10);
    expect(decoded.data.keys, hasLength(15));
    expect(IndexedDbSchema.databaseVersion, 10);
    expect(
      decoded.data[BackupSections.confirmations]!.map(
        (record) => record['recordVersion'],
      ),
      [1, 2],
    );

    final target = FakeIndexedDbDatabase();
    final targetController = AppInitializationController()..markReady();
    final importService = BackupImportService(
      database: target,
      controller: targetController,
      restore: () async {},
    );
    final plan = await importService.dryRun(
      decoded,
      BackupImportMode.replaceAll,
    );
    expect((await importService.execute(plan)).success, isTrue);
    final restoredV2 = PersistedDailyLogConfirmationRecord.fromRecord(
      (await target.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        'confirmation:2026-08-02',
      ))!,
    );
    expect(
      restoredV2.lifecycleStatus,
      DailyLogConfirmationLifecycleStatus.reopened,
    );
    expect(restoredV2.revision, 1);
    expect(restoredV2.snapshotDigest, digest);
    expect(restoredV2.reopenedAt, DateTime.utc(2026, 8, 3));
  });

  test('Schema 9 accepts v1 and rejects a disguised v2 Confirmation', () {
    final v1 = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-08-01',
      localDate: '2026-08-01',
      createdAt: DateTime.utc(2026, 8, 1, 22),
      updatedAt: DateTime.utc(2026, 8, 1, 22),
      data: completeConfirmation(date: DateTime(2026, 8, 1)),
    ).toRecord();
    final data = _schemaData(timestamp, confirmations: [v1]);
    final package = BackupExportService.buildPackage(
      exportId: 'schema-9-v1',
      exportedAt: timestamp,
      source: const BackupSource(platform: 'test'),
      schemaVersion: 9,
      data: data,
    );
    expect(
      const BackupPackageCodec()
          .decode(BackupExportService.encode(package))
          .schemaVersion,
      9,
    );

    final v2 = PersistedDailyLogConfirmationRecord.initialFinalizedV2(
      id: 'confirmation:2026-08-02',
      localDate: '2026-08-02',
      data: completeConfirmation(date: DateTime(2026, 8, 2)),
      timestamp: timestamp,
    ).toRecord();
    expect(
      () => BackupExportService.buildPackage(
        exportId: 'schema-9-disguised-v2',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        schemaVersion: 9,
        data: _schemaData(timestamp, confirmations: [v2]),
      ),
      throwsA(isA<BackupException>()),
    );
  });
}

Map<String, List<Map<String, Object?>>> _schemaData(
  DateTime timestamp, {
  required List<Map<String, Object?>> confirmations,
}) => {
  for (final section in BackupSections.schema9)
    section: section == BackupSections.confirmations
        ? confirmations
        : section == BackupSections.operationState
        ? [
            OperationState(
              operationDate: OperationLocalDate.parse('2026-08-04'),
              createdAt: timestamp,
              updatedAt: timestamp,
            ).toRecord(),
          ]
        : section == BackupSections.profile
        ? [
            {
              'version': 1,
              'userName': null,
              'heightCm': null,
              'gender': null,
              'nationality': null,
            },
          ]
        : <Map<String, Object?>>[],
};
