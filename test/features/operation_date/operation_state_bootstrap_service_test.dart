import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/features/daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/operation_date/services/operation_state_bootstrap_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'seeds once from the device local date when confirmations are empty',
    () async {
      final repository = IndexedDbOperationStateRepository(
        FakeIndexedDbDatabase(),
        now: () => DateTime.utc(2026, 7, 31, 1),
      );
      final service = OperationStateBootstrapService(
        repository,
        _ConfirmationStore(),
        now: () => DateTime.parse('2026-07-31T10:00:00+09:00'),
      );

      final result = await service.bootstrap();

      expect(result.created, isTrue);
      expect(result.state.operationDate.value, '2026-07-31');
      expect(result.state.revision, 0);
    },
  );

  test('seeds from latest valid confirmation plus one day', () async {
    final repository = IndexedDbOperationStateRepository(
      FakeIndexedDbDatabase(),
      now: () => DateTime.utc(2026, 8, 1),
    );
    final service = OperationStateBootstrapService(
      repository,
      _ConfirmationStore(
        values: [
          _confirmation(2026, 7, 28),
          _confirmation(2026, 7, 30),
          _confirmation(2026, 7, 29),
        ],
      ),
    );

    expect((await service.bootstrap()).state.operationDate.value, '2026-07-31');
  });

  test(
    'existing state is never overwritten by device date or confirmations',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbOperationStateRepository(
        database,
        now: () => DateTime.utc(2026, 7, 20),
      );
      final created = await repository.createInitial(
        OperationLocalDate.parse('2026-07-20'),
      );

      final result = await OperationStateBootstrapService(
        repository,
        _ConfirmationStore(values: [_confirmation(2026, 8, 10)]),
        now: () => DateTime.parse('2030-01-01T00:00:00-08:00'),
      ).bootstrap();

      expect(result.created, isFalse);
      expect(result.state.toRecord(), created.toRecord());
    },
  );

  test(
    'reports non-open phase as recovery required without mutating it',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbOperationStateRepository(
        database,
        now: () => DateTime.utc(2026, 7, 31, 1),
      );
      final initial = await repository.createInitial(
        OperationLocalDate.parse('2026-07-31'),
      );
      final attempt = OperationActiveAttempt(
        idempotencyKey: 'attempt-1',
        targetLocalDate: initial.operationDate,
        startedAt: DateTime.utc(2026, 7, 31, 2),
      );
      final finalizing = await repository.save(
        initial.copyWith(
          phase: OperationPhase.finalizing,
          activeAttempt: attempt,
        ),
        expectedRevision: 0,
      );

      final result = await OperationStateBootstrapService(
        repository,
        _ConfirmationStore(),
      ).bootstrap();

      expect(result.recoveryRequired, isTrue);
      expect(result.state.toRecord(), finalizing.toRecord());
    },
  );

  test('does not fall back when confirmation validation fails', () async {
    final repository = IndexedDbOperationStateRepository(
      FakeIndexedDbDatabase(),
    );

    await expectLater(
      OperationStateBootstrapService(
        repository,
        _ConfirmationStore(failure: StateError('corrupt confirmation')),
      ).bootstrap(),
      throwsStateError,
    );
    expect(await repository.findCurrent(), isNull);
  });

  test(
    'timezone changes after creation do not change operation date',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbOperationStateRepository(database);
      final first = await OperationStateBootstrapService(
        repository,
        _ConfirmationStore(),
        now: () => DateTime.parse('2026-07-31T23:30:00+09:00'),
      ).bootstrap();
      final second = await OperationStateBootstrapService(
        repository,
        _ConfirmationStore(),
        now: () => DateTime.parse('2026-07-31T23:30:00-08:00'),
      ).bootstrap();

      expect(second.state.operationDate, first.state.operationDate);
    },
  );
}

DailyLogConfirmation _confirmation(int year, int month, int day) {
  return DailyLogConfirmation(
    date: DateTime(year, month, day),
    confirmedAt: DateTime.utc(year, month, day, 23),
    morning: null,
    food: null,
    activity: null,
    training: null,
  );
}

class _ConfirmationStore implements DailyLogConfirmationStore {
  final List<DailyLogConfirmation> values;
  final Object? failure;

  _ConfirmationStore({this.values = const [], this.failure});

  @override
  Future<List<DailyLogConfirmation>> findAll() async {
    if (failure != null) throw failure!;
    return values;
  }

  @override
  Future<void> clear() => throw UnimplementedError();

  @override
  Future<void> deleteByLocalDate(String localDate) =>
      throw UnimplementedError();

  @override
  Future<DailyLogConfirmation?> findByLocalDate(String localDate) =>
      throw UnimplementedError();

  @override
  Future<DailyLogConfirmation?> findLatest() => throw UnimplementedError();

  @override
  Future<bool> isConfirmed(String localDate) => throw UnimplementedError();

  @override
  Future<void> save(DailyLogConfirmation confirmation) =>
      throw UnimplementedError();
}
