import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/operation_date/repository/operation_state_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbOperationStateRepository repository;
  var now = DateTime.utc(2026, 7, 31, 1);

  setUp(() {
    database = FakeIndexedDbDatabase();
    now = DateTime.utc(2026, 7, 31, 1);
    repository = IndexedDbOperationStateRepository(database, now: () => now);
  });

  test('creates and verifies exactly one canonical initial record', () async {
    final created = await repository.createInitial(
      OperationLocalDate.parse('2026-07-31'),
    );

    expect(created.revision, 0);
    expect(created.phase, OperationPhase.open);
    expect((await repository.requireCurrent()).toRecord(), created.toRecord());
    expect(
      await database.findAll(IndexedDbStoreNames.operationState),
      hasLength(1),
    );
    await expectLater(
      repository.createInitial(OperationLocalDate.parse('2026-08-01')),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'revision guarded save increments revision and verifies read-back',
    () async {
      final current = await repository.createInitial(
        OperationLocalDate.parse('2026-07-31'),
      );
      now = DateTime.utc(2026, 7, 31, 2);
      final attempt = OperationActiveAttempt(
        idempotencyKey: 'attempt-1',
        targetLocalDate: current.operationDate,
        startedAt: now,
      );

      final saved = await repository.save(
        current.copyWith(
          phase: OperationPhase.finalizing,
          activeAttempt: attempt,
        ),
        expectedRevision: 0,
      );

      expect(saved.revision, 1);
      expect(saved.createdAt, current.createdAt);
      expect(saved.updatedAt, now);
      expect((await repository.validateCurrent()).toRecord(), saved.toRecord());
    },
  );

  test('rejects stale revisions without overwriting current state', () async {
    final current = await repository.createInitial(
      OperationLocalDate.parse('2026-07-31'),
    );
    final attempt = OperationActiveAttempt(
      idempotencyKey: 'attempt-1',
      targetLocalDate: current.operationDate,
      startedAt: now,
    );
    final changed = await repository.save(
      current.copyWith(
        phase: OperationPhase.finalizing,
        activeAttempt: attempt,
      ),
      expectedRevision: 0,
    );

    await expectLater(
      repository.save(current, expectedRevision: 0),
      throwsA(isA<OperationStateRevisionConflictException>()),
    );
    expect((await repository.requireCurrent()).toRecord(), changed.toRecord());
  });

  test('no-op save keeps revision and timestamps unchanged', () async {
    final current = await repository.createInitial(
      OperationLocalDate.parse('2026-07-31'),
    );
    now = DateTime.utc(2026, 7, 31, 4);

    final saved = await repository.compareAndSaveRevision(
      current,
      expectedRevision: 0,
    );

    expect(saved.revision, 0);
    expect(saved.updatedAt, current.updatedAt);
  });

  test('rejects non-canonical duplicate and corrupt records', () async {
    final valid = OperationState(
      operationDate: OperationLocalDate.parse('2026-07-31'),
      createdAt: now,
      updatedAt: now,
    ).toRecord();
    database.seed(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
      valid,
    );
    database.seed(IndexedDbStoreNames.operationState, 'extra', {
      ...valid,
      'id': 'extra',
    });

    await expectLater(repository.findCurrent(), throwsA(isA<Exception>()));
  });

  test('rolls back when read-back verification fails', () async {
    database.failOnTransactionNumber = 1;

    await expectLater(
      repository.createInitial(OperationLocalDate.parse('2026-07-31')),
      throwsA(isA<Exception>()),
    );
    expect(await database.findAll(IndexedDbStoreNames.operationState), isEmpty);
  });
}
