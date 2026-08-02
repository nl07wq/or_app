import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_state.dart';
import 'package:or_app/features/operation_sync/models/operation_transfer_package.dart';
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_history_repository.dart';
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_state_repository.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_core_service.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_validator.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_codec.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import 'operation_transfer_test_fixture.dart';

void main() {
  test('production preview blocks every unregistered module', () async {
    final preview = await OperationSyncValidator(
      OperationTransferAdapterRegistry(),
    ).preview(fixturePackage());

    expect(preview.canApply, isFalse);
    expect(preview.blockingIssueCount, 1);
    expect(
      preview.issues.single.code,
      OperationSyncIssueCode.adapterUnavailable,
    );
  });

  test('fixture preview classifies create, no-change, and conflict', () async {
    final adapter = _FixtureAdapter({
      'no-change': OperationSyncRecordDisposition.noChange,
      'conflict': OperationSyncRecordDisposition.conflict,
    });
    final package = fixturePackage(
      sections: [
        fixtureSection(
          records: [
            fixtureRecord(recordId: 'create'),
            fixtureRecord(recordId: 'no-change'),
            fixtureRecord(recordId: 'conflict'),
          ],
        ),
      ],
    );
    final preview = await OperationSyncValidator(
      OperationTransferAdapterRegistry(adapters: [adapter]),
    ).preview(package);

    expect(preview.createCount, 1);
    expect(preview.noChangeCount, 1);
    expect(preview.conflictCount, 1);
    expect(preview.informationCount, 1);
    expect(preview.blockingIssueCount, 1);
    expect(preview.canApply, isFalse);
  });

  test(
    'fixture core moves through preview, apply, verify, and history',
    () async {
      final database = FakeIndexedDbDatabase();
      final stateRepository = IndexedDbOperationSyncStateRepository(
        database,
        clock: () => DateTime.utc(2026, 8, 2, 9),
      );
      final historyRepository = IndexedDbOperationSyncHistoryRepository(
        database,
      );
      final adapter = _FixtureAdapter({});
      final registry = OperationTransferAdapterRegistry(adapters: [adapter]);
      final service = OperationSyncCoreService(
        codec: const OperationTransferCodec(),
        validator: OperationSyncValidator(registry),
        stateRepository: stateRepository,
        historyRepository: historyRepository,
        database: database,
        clock: () => DateTime.utc(2026, 8, 2, 10),
      );
      final package = fixturePackage();
      final preview = await service.preview(
        const OperationTransferCodec().encode(package),
      );

      expect(
        (await stateRepository.requireCurrent()).phase,
        OperationSyncPhase.previewReady,
      );
      expect(preview.canApply, isTrue);
      await service.apply(package: package, preview: preview);
      expect(
        (await stateRepository.requireCurrent()).phase,
        OperationSyncPhase.completed,
      );
      expect(await historyRepository.list(), hasLength(1));
      expect(adapter.appliedIds, ['record-1']);
    },
  );
}

class _FixtureAdapter implements OperationTransferModuleAdapter {
  final Map<String, OperationSyncRecordDisposition> dispositions;
  final List<String> appliedIds = [];

  _FixtureAdapter(this.dispositions);

  @override
  String get module => 'fixture';

  @override
  String get schemaVersion => '1.0';

  @override
  Set<int> get supportedRecordVersions => const {1};

  @override
  Set<String> get storeNames => const {IndexedDbStoreNames.statusRecords};

  @override
  Future<List<OperationTransferRecord>> exportRecords() async => const [];

  @override
  Future<OperationSyncRecordInspection> inspect(
    OperationTransferRecord record,
    OperationSyncInspectionContext context,
  ) async {
    final disposition =
        dispositions[record.recordId] ?? OperationSyncRecordDisposition.create;
    return OperationSyncRecordInspection(disposition: disposition);
  }

  @override
  bool isDateBound(OperationTransferRecord record) => true;

  @override
  Future<bool> hasTargetRecords() async => false;

  @override
  Future<OperationSyncApplyCounts> apply(
    IndexedDbTransaction transaction,
    List<OperationTransferRecord> records,
    OperationSyncInspectionContext context,
  ) async {
    for (final record in records) {
      appliedIds.add(record.recordId);
      await transaction.put(IndexedDbStoreNames.statusRecords, {
        'id': record.recordId,
        'digest': record.recordDigest,
      });
    }
    return OperationSyncApplyCounts(created: records.length, noChanges: 0);
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
