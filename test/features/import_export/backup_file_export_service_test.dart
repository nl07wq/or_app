import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_file_export_service.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway_stub.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
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

  test(
    'exports Schema 9.0 UTF-8 JSON through the shared file gateway',
    () async {
      final result = await _service(
        database: database,
        controller: controller,
        gateway: gateway,
        clock: () => DateTime(2026, 7, 27, 21, 35),
      ).export();

      expect(result.delivery, BackupFileDelivery.shared);
      expect(result.fileName, 'operation_reboot_backup_2026-07-27_213500.json');
      expect(gateway.fileName, result.fileName);
      expect(utf8.decode(utf8.encode(gateway.content!)), gateway.content);

      final package = const BackupPackageCodec().decode(gateway.content!);
      expect(package.schemaVersion, BackupPackage.currentSchemaVersion);
      expect(package.data.keys, containsAll(BackupSections.all));
      expect(package.data, isNot(contains('activity_drafts')));
      expect(package.data, isNot(contains('migration_metadata')));
      expect(package.data, isNot(contains('migration_quarantine')));
      expect(database.transactionCount, 1);
    },
  );

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

  test('file name uses local timestamp and contains only safe characters', () {
    final fileName = BackupFileExportService.fileNameFor(
      DateTime(2026, 12, 3, 4, 5, 6),
    );

    expect(fileName, 'operation_reboot_backup_2026-12-03_040506.json');
    expect(fileName, matches(RegExp(r'^[a-z0-9_-]+\.json$')));
  });

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

  @override
  String get origin => 'https://example.test';

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async {
    this.fileName = fileName;
    this.content = content;
    final failure = this.failure;
    if (failure != null) throw failure;
    return delivery;
  }

  @override
  Future<BackupSelectedFile?> selectJson() async => null;
}
