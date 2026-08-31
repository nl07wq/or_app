import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_id_generator.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';
import 'package:or_app/features/legacy_archive/models/dns_archive_models.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_state.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/system/models/profile_model.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 2);
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('Current schema exports all formal sections', () async {
    final database = FakeIndexedDbDatabase();
    final controller = AppInitializationController()..markReady();
    _seedOperationState(database, timestamp);
    database.seed(
      IndexedDbStoreNames.morningBriefRecords,
      '2026-08-02',
      _brief(timestamp, digest).toRecord(),
    );
    database.seed(
      IndexedDbStoreNames.legacyDailySummaryRecords,
      '2026-08-01',
      _legacy(timestamp, digest).toRecord(),
    );
    database.seed(
      IndexedDbStoreNames.reportSyncHistory,
      'exchange-1',
      _history(timestamp, digest).toRecord(),
    );
    final package = await BackupExportService(
      database: database,
      controller: controller,
      idGenerator: BackupIdGenerator(nextInt: (_) => 1),
      clock: () => timestamp,
    ).create();
    expect(package.schemaVersion, BackupPackage.currentSchemaVersion);
    expect(package.data.keys, BackupSections.schema14);
    expect(package.data, hasLength(BackupSections.schema14.length));
    expect(package.data[BackupSections.morningBriefRecords], hasLength(1));
    expect(package.data[BackupSections.dailyDebriefRecords], isEmpty);
    expect(package.data[BackupSections.reportSyncHistory], hasLength(1));
    expect(
      package.data[BackupSections.legacyDailySummaryRecords],
      hasLength(1),
    );
    final decoded = const BackupPackageCodec().decode(
      BackupExportService.encode(package),
    );
    expect(decoded.data, package.data);
    expect(decoded.digests.package, package.digests.package);
    expect(IndexedDbStoreNames.operationSyncState, isNot(contains('report')));
  });

  test('Schema 9 MERGE no-ops exact records and blocks differences', () async {
    final database = FakeIndexedDbDatabase();
    final controller = AppInitializationController()..markReady();
    _seedOperationState(database, timestamp);
    database.seed(
      IndexedDbStoreNames.morningBriefRecords,
      '2026-08-02',
      _brief(timestamp, digest).toRecord(),
    );
    final package = await _export(database, controller, timestamp);
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );
    final exact = await service.dryRun(package, BackupImportMode.merge);
    expect(exact.sections[BackupSections.morningBriefRecords]!.skip, 1);
    final changedData = _copy(package.data);
    changedData[BackupSections.morningBriefRecords]!.single['argoComment'] =
        'changed';
    final changed = BackupExportService.buildPackage(
      exportId: 'changed',
      exportedAt: timestamp,
      source: const BackupSource(platform: 'test'),
      data: changedData,
    );
    final conflict = await service.dryRun(changed, BackupImportMode.merge);
    expect(conflict.hasConflicts, isTrue);
    expect(conflict.sections[BackupSections.morningBriefRecords]!.conflicts, [
      'morningBriefRecords:2026-08-02',
    ]);
  });

  test('Schema 2 through 6 REPLACE ALL clears newer formal stores', () async {
    for (final schemaVersion in [2, 3, 4, 5, 6]) {
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      _seedOperationState(database, timestamp);
      database.seed(
        IndexedDbStoreNames.morningBriefRecords,
        '2026-08-02',
        _brief(timestamp, digest).toRecord(),
      );
      database.seed(
        IndexedDbStoreNames.legacyDailySummaryRecords,
        '2026-08-01',
        _legacy(timestamp, digest).toRecord(),
      );
      final sections = BackupSections.forSchema(schemaVersion);
      final data = <String, List<Map<String, Object?>>>{
        for (final section in sections) section: const [],
      };
      if (schemaVersion >= 3) {
        data[BackupSections.operationState] = [
          OperationState(
            operationDate: OperationLocalDate.parse('2026-08-02'),
            createdAt: timestamp,
            updatedAt: timestamp,
          ).toRecord(),
        ];
      }
      final package = BackupExportService.buildPackage(
        exportId: 'schema-$schemaVersion',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        data: data,
        schemaVersion: schemaVersion,
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      expect((await service.execute(plan)).success, isTrue);
      expect(
        await database.findAll(IndexedDbStoreNames.morningBriefRecords),
        isEmpty,
      );
      expect(
        await database.findAll(IndexedDbStoreNames.legacyDailySummaryRecords),
        isEmpty,
      );
    }
  });

  test(
    'Current schema REPLACE ALL applies all formal stores in one transaction',
    () async {
      final source = FakeIndexedDbDatabase();
      final sourceController = AppInitializationController()..markReady();
      _seedOperationState(source, timestamp);
      source.seed(
        IndexedDbStoreNames.morningBriefRecords,
        '2026-08-02',
        _brief(timestamp, digest).toRecord(),
      );
      final package = await _export(source, sourceController, timestamp);

      final target = FakeIndexedDbDatabase();
      final targetController = AppInitializationController()..markReady();
      _seedOperationState(target, timestamp);
      target.seed(
        IndexedDbStoreNames.operationSyncState,
        OperationSyncState.canonicalId,
        OperationSyncState(
          revision: 0,
          phase: OperationSyncPhase.idle,
          updatedAt: timestamp,
        ).toRecord(),
      );
      final service = BackupImportService(
        database: target,
        controller: targetController,
        restore: () async {},
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      final result = await service.execute(plan);
      expect(result.success, isTrue);
      expect(target.transactionCount, 1);
      expect(
        await target.findAll(IndexedDbStoreNames.morningBriefRecords),
        package.data[BackupSections.morningBriefRecords],
      );
      expect(
        await target.findAll(IndexedDbStoreNames.operationSyncState),
        hasLength(1),
      );
    },
  );

  test('Current schema preserves FOOD History version 2 meal counts', () async {
    final source = FakeIndexedDbDatabase();
    final sourceController = AppInitializationController()..markReady();
    _seedOperationState(source, timestamp);
    source.seed(
      IndexedDbStoreNames.reportSyncHistory,
      'food-history-v2',
      _foodHistory(timestamp, digest).toRecord(),
    );
    final package = await _export(source, sourceController, timestamp);
    final exported = package.data[BackupSections.reportSyncHistory]!.single;
    expect(exported['recordVersion'], 2);
    expect(exported['receivedMealCount'], 4);
    expect(exported['selectedMealCount'], 2);
    expect(exported['importedMealCount'], 2);
    expect(exported['conflictMealCount'], 1);
    expect(exported['excludedMealCount'], 2);

    final target = FakeIndexedDbDatabase();
    final targetController = AppInitializationController()..markReady();
    _seedOperationState(target, timestamp);
    final service = BackupImportService(
      database: target,
      controller: targetController,
      restore: () async {},
    );
    final plan = await service.dryRun(package, BackupImportMode.replaceAll);
    expect((await service.execute(plan)).success, isTrue);
    final record = (await target.findAll(
      IndexedDbStoreNames.reportSyncHistory,
    )).single;
    final restored = ReportSyncHistory.fromRecord(record);
    expect(restored.receivedMealCount, 4);
    expect(restored.selectedMealCount, 2);
    expect(restored.importedMealCount, 2);
    expect(restored.conflictMealCount, 1);
    expect(restored.excludedMealCount, 2);
  });

  test('Schema 8 restores History version 1 without inferred counts', () async {
    final source = FakeIndexedDbDatabase();
    final sourceController = AppInitializationController()..markReady();
    _seedOperationState(source, timestamp);
    source.seed(
      IndexedDbStoreNames.profileRecords,
      ProfileModel.recordId,
      ProfileModel.validated(userName: 'Legacy').toRecord(now: timestamp),
    );
    source.seed(
      IndexedDbStoreNames.reportSyncHistory,
      'food-history-v1',
      _foodHistory(timestamp, digest, recordVersion: 1).toRecord(),
    );
    final currentPackage = await BackupExportService(
      database: source,
      controller: sourceController,
      idGenerator: BackupIdGenerator(nextInt: (_) => 1),
      clock: () => timestamp,
    ).create();
    final package = BackupExportService.buildPackage(
      exportId: currentPackage.exportId,
      exportedAt: currentPackage.exportedAt,
      appVersion: currentPackage.appVersion,
      source: currentPackage.source,
      data: currentPackage.data,
      schemaVersion: 8,
    );
    expect(package.schemaVersion, 8);

    final target = FakeIndexedDbDatabase();
    final targetController = AppInitializationController()..markReady();
    _seedOperationState(target, timestamp);
    final service = BackupImportService(
      database: target,
      controller: targetController,
      restore: () async {},
    );
    final plan = await service.dryRun(package, BackupImportMode.replaceAll);
    expect((await service.execute(plan)).success, isTrue);
    final restored = ReportSyncHistory.fromRecord(
      (await target.findAll(IndexedDbStoreNames.reportSyncHistory)).single,
    );
    expect(restored.recordVersion, 1);
    expect(restored.receivedMealCount, isNull);
    expect(restored.selectedMealCount, isNull);
    expect(restored.importedMealCount, isNull);
    expect(restored.conflictMealCount, isNull);
    expect(restored.excludedMealCount, isNull);
  });

  test('Current schema rejects inconsistent FOOD History meal counts', () {
    final invalid = _foodHistory(timestamp, digest).toRecord()
      ..['excludedMealCount'] = 1;
    expect(
      () => BackupStoreRegistry.validateRecord(
        BackupSections.reportSyncHistory,
        invalid,
      ),
      throwsFormatException,
    );
  });
}

Future<BackupPackage> _export(
  FakeIndexedDbDatabase database,
  AppInitializationController controller,
  DateTime timestamp,
) => BackupExportService(
  database: database,
  controller: controller,
  idGenerator: BackupIdGenerator(nextInt: (_) => 1),
  clock: () => timestamp,
).create();

void _seedOperationState(FakeIndexedDbDatabase database, DateTime timestamp) {
  database.seed(
    IndexedDbStoreNames.operationState,
    OperationState.canonicalId,
    OperationState(
      operationDate: OperationLocalDate.parse('2026-08-02'),
      createdAt: timestamp,
      updatedAt: timestamp,
    ).toRecord(),
  );
}

MorningBriefRecord _brief(DateTime timestamp, String digest) =>
    MorningBriefRecord(
      localDate: '2026-08-02',
      requestId: 'request-1',
      requestDigest: digest,
      responseDigest: digest,
      generatedAt: timestamp,
      importedAt: timestamp,
      situationAnalysis: 'analysis',
      operationStatus: MorningBriefOperationStatus.green,
      commanderIntent: 'intent',
      argoComment: 'comment',
      strategicResourceDecision: 'decision',
      actions: const [],
      createdAt: timestamp,
      updatedAt: timestamp,
    );

ReportSyncHistory _history(DateTime timestamp, String digest) =>
    ReportSyncHistory(
      exchangeId: 'exchange-1',
      exchangeType: ReportSyncExchangeType.morningBrief,
      direction: ReportSyncDirection.response,
      operationDate: '2026-08-02',
      requestId: 'request-1',
      requestDigest: digest,
      responseDigest: digest,
      startedAt: timestamp,
      completedAt: timestamp,
      result: ReportSyncHistoryResult.success,
      packageDigest: digest,
    );

ReportSyncHistory _foodHistory(
  DateTime timestamp,
  String digest, {
  int recordVersion = 2,
}) => ReportSyncHistory(
  exchangeId: 'food-history-v$recordVersion',
  recordVersion: recordVersion,
  exchangeType: ReportSyncExchangeType.food,
  direction: ReportSyncDirection.response,
  operationDate: '2026-08-02',
  requestId: 'food-history-v$recordVersion',
  requestDigest: digest,
  responseDigest: digest,
  startedAt: timestamp,
  completedAt: timestamp,
  result: ReportSyncHistoryResult.success,
  packageDigest: digest,
  receivedMealCount: recordVersion == 1 ? null : 4,
  selectedMealCount: recordVersion == 1 ? null : 2,
  importedMealCount: recordVersion == 1 ? null : 2,
  conflictMealCount: recordVersion == 1 ? null : 1,
  excludedMealCount: recordVersion == 1 ? null : 2,
);

LegacyDailySummaryRecord _legacy(DateTime timestamp, String digest) =>
    LegacyDailySummaryRecord(
      localDate: '2026-08-01',
      sourceRecordId: 'dns-record-1',
      sourcePackageId: 'dns-package-1',
      warnings: const [],
      unmappedFragments: const [],
      sourceTextDigest: digest,
      createdAt: timestamp,
      importedAt: timestamp,
    );

Map<String, List<Map<String, Object?>>> _copy(
  Map<String, List<Map<String, Object?>>> source,
) => {
  for (final entry in source.entries)
    entry.key: [for (final record in entry.value) Map.of(record)],
};
