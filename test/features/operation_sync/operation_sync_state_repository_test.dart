import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_state.dart';
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_state_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final initialTime = DateTime.utc(2026, 8, 2, 10);
  late FakeIndexedDbDatabase database;
  late IndexedDbOperationSyncStateRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    repository = IndexedDbOperationSyncStateRepository(
      database,
      clock: () => initialTime,
    );
  });

  test('initializes canonical current record at revision zero', () async {
    final state = await repository.initializeIfAbsent();
    expect(state.id, OperationSyncState.canonicalId);
    expect(state.recordVersion, 1);
    expect(state.revision, 0);
    expect(state.phase, OperationSyncPhase.idle);
    expect(await repository.requireCurrent(), isA<OperationSyncState>());
  });

  test('guarded update increments revision and verifies checkpoint', () async {
    final current = await repository.initializeIfAbsent();
    final checkpoint = OperationSyncCheckpoint(
      validatedPackageDigest: 'a' * 64,
      expectedSectionDigests: {'fixture': 'b' * 64},
      expectedRecordDigests: ['c' * 64],
      appliedSectionIds: const [],
      verificationStatus: 'validated',
    );
    final updated = await repository.guardedUpdate(
      expectedRevision: 0,
      next: current.copyWith(
        phase: OperationSyncPhase.validating,
        operationId: 'operation-1',
        checkpoint: checkpoint,
        updatedAt: initialTime.add(const Duration(seconds: 1)),
      ),
    );

    expect(updated.revision, 1);
    expect(updated.checkpoint?.validatedPackageDigest, 'a' * 64);
    expect(
      (await repository.requireCurrent()).phase,
      OperationSyncPhase.validating,
    );
  });

  test(
    'same-content update is no-op and preserves revision and updatedAt',
    () async {
      final current = await repository.initializeIfAbsent();
      final noOp = await repository.guardedUpdate(
        expectedRevision: current.revision,
        next: current.copyWith(
          updatedAt: initialTime.add(const Duration(hours: 1)),
        ),
      );

      expect(noOp.revision, 0);
      expect(noOp.updatedAt, initialTime);
    },
  );

  test('revision conflict blocks update', () async {
    final current = await repository.initializeIfAbsent();
    await expectLater(
      repository.guardedUpdate(
        expectedRevision: 99,
        next: current.copyWith(phase: OperationSyncPhase.reading),
      ),
      throwsA(
        isA<OperationSyncException>().having(
          (error) => error.code,
          'code',
          OperationSyncIssueCode.operationStateConflict,
        ),
      ),
    );
  });

  test(
    'state persistence contains no raw package or clipboard fields',
    () async {
      await repository.initializeIfAbsent();
      final raw = database.rawRecord(
        IndexedDbStoreNames.operationSyncState,
        OperationSyncState.canonicalId,
      )!;
      expect(raw, isNot(contains('rawPackage')));
      expect(raw, isNot(contains('clipboard')));
    },
  );
}
