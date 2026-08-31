import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/services/persistence_access.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_audit_package_codec.dart';
import 'package:or_app/features/import_export/services/backup_file_export_service.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway_stub.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;
  late _RecordingGateway gateway;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    gateway = _RecordingGateway();
    final timestamp = DateTime.utc(2026, 8, 1);
    final state = OperationState(
      operationDate: OperationLocalDate.parse('2026-08-01'),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    database.seed(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
      state.toRecord(),
    );
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  test('exports current UTF-8 JSON with the fixed file name', () async {
    final result = await _service(
      database: database,
      controller: controller,
      gateway: gateway,
      clock: () => DateTime(2026, 7, 27, 21, 35),
    ).export();

    expect(result.delivery, BackupFileDelivery.shared);
    expect(result.fileName, 'operation_reboot_backup.json');
    expect(gateway.fileName, result.fileName);
    expect(utf8.decode(utf8.encode(gateway.content!)), gateway.content);

    final package = const BackupPackageCodec().decode(gateway.content!);
    expect(package.schemaVersion, BackupPackage.currentSchemaVersion);
    expect(package.data.keys, containsAll(BackupSections.schema14));
    expect(
      package.data.keys,
      isNot(contains(BackupSections.operationSyncHistory)),
    );
    expect(package.data, isNot(contains('activity_drafts')));
    expect(package.data, isNot(contains('migration_metadata')));
    expect(package.data, isNot(contains('migration_quarantine')));
    expect(database.transactionCount, 1);
  });

  test(
    'reports share cancellation without changing the exported package',
    () async {
      gateway.delivery = BackupFileDelivery.cancelled;

      final result = await _service(
        database: database,
        controller: controller,
        gateway: gateway,
      ).export();

      expect(result.delivery, BackupFileDelivery.cancelled);
      expect(result.package.schemaVersion, BackupPackage.currentSchemaVersion);
      expect(database.transactionCount, 1);
    },
  );

  test(
    'exports matched v14 Normal and Audit files from one snapshot',
    () async {
      final result = await _service(
        database: database,
        controller: controller,
        gateway: gateway,
        clock: () => DateTime.utc(2026, 8, 31),
      ).exportV14Bundle();

      expect(result.normalDelivery, BackupFileDelivery.shared);
      expect(result.auditDelivery, BackupFileDelivery.shared);
      final normal = const BackupPackageCodec().decode(
        gateway.writes[BackupFileExportService.normalFileName]!,
      );
      final audit = const BackupAuditPackageCodec().decode(
        gateway.writes[BackupFileExportService.auditFileName]!,
      );
      expect(normal.schemaVersion, 14);
      expect(normal.auditArchiveId, audit.archiveId);
      expect(audit.normalExportId, normal.exportId);
      expect(audit.normalPackageDigest, normal.digests.package);
      expect(database.transactionCount, 1);

      final tampered = Map<String, Object?>.from(
        jsonDecode(gateway.writes[BackupFileExportService.auditFileName]!)
            as Map,
      )..['archiveId'] = 'tampered';
      expect(
        () => const BackupAuditPackageCodec().decode(jsonEncode(tampered)),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            'package_digest_mismatch',
          ),
        ),
      );
    },
  );

  test('propagates gateway failure after package generation', () async {
    gateway.failure = StateError('share failed');

    await expectLater(
      _service(
        database: database,
        controller: controller,
        gateway: gateway,
      ).export(),
      throwsStateError,
    );
    expect(database.transactionCount, 1);
  });

  test('canonical read-only allows export and rejects import', () async {
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    controller.markLegacyReadOnly(
      message: 'Canonical data is available in read-only recovery mode.',
    );
    final operationStateBefore = await database.findById(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
    );

    final result = await _service(
      database: database,
      controller: controller,
      gateway: gateway,
    ).export();

    expect(result.delivery, BackupFileDelivery.shared);
    expect(PersistenceAccess.canReadIndexedDb, isTrue);
    expect(PersistenceAccess.canWriteIndexedDb, isFalse);
    expect(
      () => BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      ).dryRun(result.package, BackupImportMode.merge),
      throwsA(isA<BackupException>()),
    );
    expect(
      await database.findById(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
      ),
      operationStateBefore,
    );
  });

  test(
    'file name is fixed while package metadata keeps its timestamp',
    () async {
      final result = await _service(
        database: database,
        controller: controller,
        gateway: gateway,
        clock: () => DateTime.utc(2026, 12, 3, 4, 5, 6),
      ).export();

      expect(result.fileName, BackupFileExportService.fileName);
      expect(result.fileName, 'operation_reboot_backup.json');
      expect(result.package.exportedAt, DateTime.utc(2026, 12, 3, 4, 5, 6));
    },
  );

  test('unsupported platform reports export as unavailable safely', () async {
    final gateway = UnsupportedBackupFileGateway();

    expect(
      () => gateway.shareOrSave(fileName: 'backup.json', content: '{}'),
      throwsUnsupportedError,
    );
  });
}

BackupFileExportService _service({
  required FakeIndexedDbDatabase database,
  required AppInitializationController controller,
  required BackupFileGateway gateway,
  DateTime Function()? clock,
}) {
  return BackupFileExportService(
    exportService: BackupExportService(
      database: database,
      controller: controller,
      clock: clock,
    ),
    fileGateway: gateway,
  );
}

class _RecordingGateway implements BackupFileGateway {
  BackupFileDelivery delivery = BackupFileDelivery.shared;
  Object? failure;
  String? fileName;
  String? content;
  final Map<String, String> writes = {};

  @override
  String get origin => 'https://example.test';

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async {
    this.fileName = fileName;
    this.content = content;
    writes[fileName] = content;
    final failure = this.failure;
    if (failure != null) throw failure;
    return delivery;
  }

  @override
  Future<BackupSelectedFile?> selectJson() async => null;
}
