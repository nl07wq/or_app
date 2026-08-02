import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/operation_state_repository.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart';
import 'package:or_app/features/operation_sync/models/operation_transfer_package.dart';
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_history_repository.dart';
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_state_repository.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_core_service.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_transfer_coordinator.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_validator.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_codec.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_export_service.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_id_generator.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import 'operation_transfer_test_fixture.dart';

void main() {
  test(
    'file workflow exports, selects, previews, applies, and reads history',
    () async {
      final database = FakeIndexedDbDatabase();
      final adapter = _TransferAdapter();
      final registry = OperationTransferAdapterRegistry(adapters: [adapter]);
      final operationState = _FixedOperationStateRepository();
      final stateRepository = IndexedDbOperationSyncStateRepository(database);
      final historyRepository = IndexedDbOperationSyncHistoryRepository(
        database,
      );
      final codec = const OperationTransferCodec();
      final core = OperationSyncCoreService(
        codec: codec,
        validator: OperationSyncValidator(registry),
        stateRepository: stateRepository,
        historyRepository: historyRepository,
        database: database,
      );
      final gateway = _MemoryFileGateway();
      final coordinator = OperationSyncTransferCoordinator(
        exportService: OperationTransferExportService(
          registry: registry,
          operationStateRepository: operationState,
          clock: () => DateTime.utc(2026, 8, 2, 12),
        ),
        codec: codec,
        core: core,
        stateRepository: stateRepository,
        historyRepository: historyRepository,
        fileGateway: gateway,
        idGenerator: OperationTransferIdGenerator(nextInt: (_) => 0),
      );

      final exported = await coordinator.exportPackage();
      expect(exported.delivery, BackupFileDelivery.downloaded);
      expect(
        exported.fileName,
        OperationSyncTransferCoordinator.fileNameFor(
          exported.package.createdAt.toLocal(),
        ),
      );
      expect(gateway.savedContent, isNotNull);
      expect(
        codec.decode(gateway.savedContent!).packageDigest,
        exported.package.packageDigest,
      );

      gateway.selected = BackupSelectedFile(
        name: exported.fileName,
        bytes: gateway.savedContent!.codeUnits,
      );
      final selection = await coordinator.selectAndPreview();
      expect(selection, isNotNull);
      expect(selection!.preview.canApply, isTrue);
      expect(selection.preview.createCount, 1);

      await coordinator.apply(selection);
      final workspace = await coordinator.load();
      expect(workspace.history, hasLength(1));
      expect(
        workspace.history.single.result,
        OperationSyncHistoryResult.success,
      );
      expect(workspace.history.single.recordCount, 1);
      expect(adapter.storedIds, ['record-1']);
    },
  );

  test('cancelled file selection does not start validation', () async {
    final coordinator = _coordinatorWithGateway(_MemoryFileGateway());

    expect(await coordinator.selectAndPreview(), isNull);
    expect((await coordinator.load()).history, isEmpty);
  });
}

OperationSyncTransferCoordinator _coordinatorWithGateway(
  BackupFileGateway gateway,
) {
  final database = FakeIndexedDbDatabase();
  final adapter = _TransferAdapter();
  final registry = OperationTransferAdapterRegistry(adapters: [adapter]);
  final stateRepository = IndexedDbOperationSyncStateRepository(database);
  final historyRepository = IndexedDbOperationSyncHistoryRepository(database);
  const codec = OperationTransferCodec();
  return OperationSyncTransferCoordinator(
    exportService: OperationTransferExportService(
      registry: registry,
      operationStateRepository: _FixedOperationStateRepository(),
    ),
    codec: codec,
    core: OperationSyncCoreService(
      codec: codec,
      validator: OperationSyncValidator(registry),
      stateRepository: stateRepository,
      historyRepository: historyRepository,
      database: database,
    ),
    stateRepository: stateRepository,
    historyRepository: historyRepository,
    fileGateway: gateway,
  );
}

class _MemoryFileGateway implements BackupFileGateway {
  BackupSelectedFile? selected;
  String? savedContent;

  @override
  String? get origin => 'https://example.test';

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async {
    savedContent = content;
    return BackupFileDelivery.downloaded;
  }

  @override
  Future<BackupSelectedFile?> selectJson() async => selected;
}

class _TransferAdapter implements OperationTransferModuleAdapter {
  final List<String> storedIds = [];

  @override
  String get module => 'fixture';

  @override
  String get schemaVersion => '1.0';

  @override
  Set<int> get supportedRecordVersions => const {1};

  @override
  Set<String> get storeNames => const {IndexedDbStoreNames.statusRecords};

  @override
  Future<List<OperationTransferRecord>> exportRecords() async => [
    fixtureRecord(),
  ];

  @override
  Future<OperationSyncRecordInspection> inspect(
    OperationTransferRecord record,
    OperationSyncInspectionContext context,
  ) async => storedIds.contains(record.recordId)
      ? const OperationSyncRecordInspection.noChange()
      : const OperationSyncRecordInspection.create();

  @override
  bool isDateBound(OperationTransferRecord record) => true;

  @override
  Future<bool> hasTargetRecords() async => storedIds.isNotEmpty;

  @override
  Future<OperationSyncApplyCounts> apply(
    IndexedDbTransaction transaction,
    List<OperationTransferRecord> records,
    OperationSyncInspectionContext context,
  ) async {
    var created = 0;
    var noChanges = 0;
    for (final record in records) {
      final existing = await transaction.findById(
        IndexedDbStoreNames.statusRecords,
        record.recordId,
      );
      if (existing != null) {
        noChanges++;
        continue;
      }
      await transaction.put(IndexedDbStoreNames.statusRecords, {
        'id': record.recordId,
        'digest': record.recordDigest,
      });
      storedIds.add(record.recordId);
      created++;
    }
    return OperationSyncApplyCounts(created: created, noChanges: noChanges);
  }

  @override
  Future<bool> verify(
    IndexedDbTransaction transaction,
    List<OperationTransferRecord> records,
  ) async {
    for (final record in records) {
      final stored = await transaction.findById(
        IndexedDbStoreNames.statusRecords,
        record.recordId,
      );
      if (stored?['digest'] != record.recordDigest) return false;
    }
    return true;
  }
}

class _FixedOperationStateRepository implements OperationStateRepository {
  final OperationState state = OperationState(
    operationDate: OperationLocalDate.parse('2026-08-02'),
    lastFinalizedDate: OperationLocalDate.parse('2026-08-01'),
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 2),
  );

  @override
  Future<OperationState?> findCurrent() async => state;

  @override
  Future<OperationState> requireCurrent() async => state;

  @override
  Future<OperationState> createInitial(OperationLocalDate operationDate) =>
      throw UnimplementedError();

  @override
  Future<OperationState> save(
    OperationState state, {
    required int expectedRevision,
  }) => throw UnimplementedError();

  @override
  Future<OperationState> compareAndSaveRevision(
    OperationState state, {
    required int expectedRevision,
  }) => throw UnimplementedError();

  @override
  Future<OperationState> validateCurrent() async => state;
}
