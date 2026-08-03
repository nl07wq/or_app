import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 2, 12);
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    database.seed(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
      _operationState(timestamp),
    );
    database.seed(
      IndexedDbStoreNames.operationSyncState,
      OperationSyncState.canonicalId,
      OperationSyncState(
        revision: 0,
        phase: OperationSyncPhase.idle,
        updatedAt: timestamp,
      ).toRecord(),
    );
    database.seed(
      IndexedDbStoreNames.operationSyncHistory,
      'operation-1',
      _history('operation-1', timestamp).toRecord(),
    );
  });

  test(
    'Schema 9 exports fifteen sections and excludes active sync state',
    () async {
      final package = await _export(database, controller, timestamp);
      expect(package.schemaVersion, BackupPackage.currentSchemaVersion);
      expect(package.data.keys, BackupSections.schema8);
      expect(package.data, hasLength(15));
      expect(package.data[BackupSections.operationSyncHistory], hasLength(1));
      expect(package.data, isNot(contains('operationSyncState')));

      final decoded = const BackupPackageCodec().decode(
        BackupExportService.encode(package),
      );
      expect(decoded.schemaVersion, BackupPackage.currentSchemaVersion);
      expect(decoded.digests.sections, hasLength(15));
    },
  );

  test('Schema 9 MERGE no-ops exact history and blocks differences', () async {
    final package = await _export(database, controller, timestamp);
    final service = _service(database, controller);
    final noOp = await service.dryRun(package, BackupImportMode.merge);
    expect(noOp.hasConflicts, isFalse);
    expect(noOp.sections[BackupSections.operationSyncHistory]!.skip, 1);

    final data = _copyData(package.data);
    data[BackupSections.operationSyncHistory]!.single['createCount'] = 99;
    final changed = BackupExportService.buildPackage(
      exportId: 'changed-history',
      exportedAt: timestamp,
      source: const BackupSource(platform: 'test'),
      data: data,
    );
    final conflict = await service.dryRun(changed, BackupImportMode.merge);
    expect(conflict.hasConflicts, isTrue);
    expect(conflict.sections[BackupSections.operationSyncHistory]!.conflicts, [
      'operationSyncHistory:operation-1',
    ]);
  });

  test(
    'Schema 9 REPLACE ALL replaces history and preserves sync state',
    () async {
      final package = await _export(database, controller, timestamp);
      final data = _copyData(package.data);
      data[BackupSections.operationSyncHistory] = [
        _history('operation-2', timestamp).toRecord(),
      ];
      final replacement = BackupExportService.buildPackage(
        exportId: 'replacement',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        data: data,
      );
      final service = _service(database, controller);
      final plan = await service.dryRun(
        replacement,
        BackupImportMode.replaceAll,
      );
      expect((await service.execute(plan)).success, isTrue);
      expect(
        await database.findById(
          IndexedDbStoreNames.operationSyncHistory,
          'operation-1',
        ),
        isNull,
      );
      expect(
        await database.findById(
          IndexedDbStoreNames.operationSyncHistory,
          'operation-2',
        ),
        isNotNull,
      );
      expect(
        await database.findById(
          IndexedDbStoreNames.operationSyncState,
          OperationSyncState.canonicalId,
        ),
        isNotNull,
      );
    },
  );

  for (final schemaVersion in [2, 3, 4]) {
    test(
      'Schema $schemaVersion REPLACE ALL preserves both sync stores',
      () async {
        final sections = BackupSections.forSchema(schemaVersion);
        final data = <String, List<Map<String, Object?>>>{
          for (final section in sections) section: [],
        };
        if (schemaVersion >= 3) {
          data[BackupSections.operationState] = [_operationState(timestamp)];
        }
        final package = BackupExportService.buildPackage(
          exportId: 'schema-$schemaVersion',
          exportedAt: timestamp,
          source: const BackupSource(platform: 'test'),
          schemaVersion: schemaVersion,
          data: data,
        );
        final service = _service(database, controller);
        final plan = await service.dryRun(package, BackupImportMode.replaceAll);
        expect((await service.execute(plan)).success, isTrue);
        expect(
          await database.findAll(IndexedDbStoreNames.operationSyncState),
          hasLength(1),
        );
        expect(
          await database.findAll(IndexedDbStoreNames.operationSyncHistory),
          hasLength(1),
        );
      },
    );
  }
}

Future<BackupPackage> _export(
  FakeIndexedDbDatabase database,
  AppInitializationController controller,
  DateTime timestamp,
) {
  return BackupExportService(
    database: database,
    controller: controller,
    clock: () => timestamp,
  ).create();
}

BackupImportService _service(
  FakeIndexedDbDatabase database,
  AppInitializationController controller,
) {
  return BackupImportService(
    database: database,
    controller: controller,
    restore: () async {},
  );
}

Map<String, List<Map<String, Object?>>> _copyData(
  Map<String, List<Map<String, Object?>>> source,
) {
  return {
    for (final entry in source.entries)
      entry.key: [for (final record in entry.value) Map.of(record)],
  };
}

Map<String, Object?> _operationState(DateTime timestamp) => OperationState(
  operationDate: OperationLocalDate.parse('2026-08-02'),
  createdAt: timestamp,
  updatedAt: timestamp,
).toRecord();

OperationSyncHistory _history(String id, DateTime timestamp) {
  return OperationSyncHistory(
    operationId: id,
    packageId: '11111111-1111-4111-8111-111111111111',
    packageDigest: 'a' * 64,
    sourceType: 'currentAppTransfer',
    transferMode: 'fullTransfer',
    startedAt: timestamp.subtract(const Duration(minutes: 5)),
    completedAt: timestamp,
    moduleIds: const ['fixture'],
    recordCount: 1,
    createCount: 1,
    noChangeCount: 0,
    conflictCount: 0,
    quarantineCount: 0,
    result: OperationSyncHistoryResult.success,
    isRecoveryExecution: false,
  );
}
