import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_audit_package.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_v14_transform.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/daily_log_confirmation/models/daily_log_confirmation_lifecycle.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/system/models/profile_model.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  test(
    'v14 split preserves latest full revision and archives older bodies',
    () {
      final source = <String, List<Map<String, Object?>>>{
        for (final section in BackupSections.all)
          section: <Map<String, Object?>>[],
        BackupSections.dailyDebriefRecords: [
          {
            'localDate': '2026-08-31',
            'revision': 4,
            'previousRevisions': [_revision(1), _revision(2), _revision(3)],
          },
        ],
        BackupSections.reportSyncHistory: [
          {
            'exchangeId': 'exchange-1',
            'recordVersion': 3,
            'importedMealCount': 1,
            'importedMealSnapshots': [
              {'id': 'meal-1'},
            ],
          },
        ],
        BackupSections.operationSyncHistory: [
          {'operationId': 'operation-1'},
        ],
      };

      final split = BackupV14Transform.split(source);
      final record = split.normal[BackupSections.dailyDebriefRecords]!.single;
      expect(record['previousRevisions'], hasLength(1));
      expect((record['previousRevisions'] as List).single['revision'], 3);
      expect(record['archivedRevisions'], hasLength(2));
      expect(split.audit[BackupAuditSections.revisionBodies], hasLength(2));
      expect(
        split.normal.containsKey(BackupSections.operationSyncHistory),
        isFalse,
      );
      expect(
        split.audit[BackupAuditSections.operationSyncHistory],
        hasLength(1),
      );
      final report = split.normal[BackupSections.reportSyncHistory]!.single;
      expect(report['recordVersion'], 4);
      expect(report['detailsArchived'], isTrue);
      expect(report['importedMealSnapshots'], isEmpty);
    },
  );

  test('v14 matching audit hydrates complete history', () {
    final source = <String, List<Map<String, Object?>>>{
      for (final section in BackupSections.all)
        section: <Map<String, Object?>>[],
      BackupSections.dailyDebriefRecords: [
        {
          'localDate': '2026-08-31',
          'revision': 4,
          'previousRevisions': [_revision(1), _revision(2), _revision(3)],
        },
      ],
    };
    final split = BackupV14Transform.split(source);
    final normal = _normal(split.normal);
    final audit = _audit(normal, split.audit);

    final hydrated = BackupV14Transform.hydrate(normal, audit);
    expect(
      hydrated[BackupSections.dailyDebriefRecords]!.single['previousRevisions'],
      source[BackupSections.dailyDebriefRecords]!.single['previousRevisions'],
    );
    expect(
      hydrated[BackupSections.dailyDebriefRecords]!.single.containsKey(
        'archivedRevisions',
      ),
      isFalse,
    );
  });

  test('v14 rejects mismatched Normal and Audit packages', () {
    final normal = _normal({
      for (final section in BackupSections.schema14)
        section: <Map<String, Object?>>[],
    });
    final audit = _audit(normal, {
      for (final section in BackupAuditSections.all)
        section: <Map<String, Object?>>[],
    }, archiveId: 'wrong-archive');
    expect(
      () => BackupV14Transform.validatePair(normal, audit),
      throwsA(
        isA<BackupException>().having(
          (error) => error.code,
          'code',
          'audit_archive_mismatch',
        ),
      ),
    );
  });

  test(
    'v14 Normal-only restore reproduces current operational state',
    () async {
      final timestamp = DateTime.utc(2026, 8, 31, 12);
      final data = <String, List<Map<String, Object?>>>{
        for (final section in BackupSections.schema14)
          section: <Map<String, Object?>>[],
        BackupSections.operationState: [
          OperationState(
            operationDate: OperationLocalDate.parse('2026-08-31'),
            createdAt: timestamp,
            updatedAt: timestamp,
          ).toRecord(),
        ],
        BackupSections.profile: [const ProfileModel().toBackupRecord()],
      };
      final normal = BackupExportService.buildPackage(
        exportId: 'normal-restore',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        data: data,
        schemaVersion: 14,
        auditArchiveId: 'archive-restore',
      );
      final database = FakeIndexedDbDatabase();
      final service = BackupImportService(
        database: database,
        controller: AppInitializationController()..markReady(),
        restore: () async {},
      );
      final plan = await service.dryRun(normal, BackupImportMode.replaceAll);
      final result = await service.execute(plan);

      expect(result.success, isTrue);
      final restored = await database.findAll(
        IndexedDbStoreNames.operationState,
      );
      expect(restored, hasLength(1));
      expect(restored.single['operationDate'], '2026-08-31');
      expect(
        await database.findAll(IndexedDbStoreNames.operationSyncHistory),
        isEmpty,
      );
    },
  );

  test(
    'v14 Normal plus matching Audit restores through the same importer',
    () async {
      final timestamp = DateTime.utc(2026, 8, 31, 12);
      final data = <String, List<Map<String, Object?>>>{
        for (final section in BackupSections.schema14)
          section: <Map<String, Object?>>[],
        BackupSections.operationState: [
          OperationState(
            operationDate: OperationLocalDate.parse('2026-08-31'),
            createdAt: timestamp,
            updatedAt: timestamp,
          ).toRecord(),
        ],
        BackupSections.profile: [const ProfileModel().toBackupRecord()],
      };
      final normal = BackupExportService.buildPackage(
        exportId: 'normal-with-audit',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        data: data,
        schemaVersion: 14,
        auditArchiveId: 'archive-with-audit',
      );
      final audit = _audit(normal, {
        for (final section in BackupAuditSections.all)
          section: <Map<String, Object?>>[],
      }, archiveId: 'archive-with-audit');
      final hydrated = BackupV14Transform.hydratePackage(normal, audit);
      final database = FakeIndexedDbDatabase();
      final service = BackupImportService(
        database: database,
        controller: AppInitializationController()..markReady(),
        restore: () async {},
      );
      final plan = await service.dryRun(hydrated, BackupImportMode.replaceAll);

      expect((await service.execute(plan)).success, isTrue);
      expect(
        (await database.findAll(
          IndexedDbStoreNames.operationState,
        )).single['operationDate'],
        '2026-08-31',
      );
    },
  );

  test('v14 real export archives older Daily Log revision bodies', () async {
    final timestamp = DateTime.utc(2026, 8, 31, 12);
    final database = FakeIndexedDbDatabase();
    database.seed(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
      OperationState(
        operationDate: OperationLocalDate.parse('2026-08-31'),
        createdAt: timestamp,
        updatedAt: timestamp,
      ).toRecord(),
    );
    var confirmation = PersistedDailyLogConfirmationRecord.initialFinalizedV2(
      id: PersistedDailyLogConfirmationRecord.canonicalId('2026-08-31'),
      localDate: '2026-08-31',
      data: completeConfirmation(
        date: DateTime(2026, 8, 31),
        confirmedAt: timestamp,
      ),
      timestamp: timestamp,
    );
    for (var revision = 2; revision <= 3; revision++) {
      confirmation = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: confirmation,
        reopenedAt: timestamp.add(Duration(minutes: revision * 2 - 1)),
      );
      confirmation = PersistedDailyLogConfirmationRecord.refinalizedFrom(
        existing: confirmation,
        data: completeConfirmation(
          date: DateTime(2026, 8, 31),
          confirmedAt: timestamp.add(Duration(minutes: revision * 2)),
          trainingName: 'Revision $revision',
        ),
        sourceRecordVersions:
            const DailyLogConfirmationSourceRecordVersions.unknown(),
        refinalizedAt: timestamp.add(Duration(minutes: revision * 2)),
      );
    }
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      confirmation.id,
      confirmation.toRecord(),
    );
    final bundle = await BackupExportService(
      database: database,
      controller: AppInitializationController()..markReady(),
      clock: () => timestamp,
    ).createV14Bundle();

    final normalRecord =
        bundle.normal.data[BackupSections.confirmations]!.single;
    expect(normalRecord['archivedRevisions'], hasLength(1));
    expect(normalRecord['previousRevisions'], hasLength(1));
    expect(bundle.audit.data[BackupAuditSections.revisionBodies], hasLength(1));
    final hydrated = BackupV14Transform.hydrate(bundle.normal, bundle.audit);
    expect(
      hydrated[BackupSections.confirmations]!.single['previousRevisions'],
      hasLength(2),
    );
  });
}

Map<String, Object?> _revision(int revision) => {
  'revision': revision,
  'responseDigest': '${revision}0000000',
  'createdAt': '2026-08-${revision.toString().padLeft(2, '0')}T00:00:00.000Z',
  'analysis': {'body': 'revision-$revision'},
};

BackupPackage _normal(Map<String, List<Map<String, Object?>>> data) =>
    BackupPackage(
      schemaVersion: 14,
      exportId: 'normal-1',
      exportedAt: DateTime.utc(2026, 8, 31),
      databaseVersion: 14,
      source: const BackupSource(platform: 'test'),
      recordCounts: BackupRecordCounts({
        for (final entry in data.entries) entry.key: entry.value.length,
      }),
      digests: BackupDigests(package: 'normal-digest', sections: const {}),
      data: data,
      auditArchiveId: 'archive-1',
    );

BackupAuditPackage _audit(
  BackupPackage normal,
  Map<String, List<Map<String, Object?>>> data, {
  String archiveId = 'archive-1',
}) => BackupAuditPackage(
  archiveId: archiveId,
  normalExportId: normal.exportId,
  normalPackageDigest: normal.digests.package,
  exportedAt: normal.exportedAt,
  source: normal.source,
  archiveComplete: true,
  digests: BackupDigests(package: 'audit-digest', sections: const {}),
  data: data,
);
