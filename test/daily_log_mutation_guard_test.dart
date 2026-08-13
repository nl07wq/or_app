import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/daily_log_mutation_guard.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import 'repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  for (final label in ['STATUS', 'FOOD', 'ACTIVITY', 'TRAINING']) {
    test('$label normal save remains allowed while awaiting debrief', () async {
      _installState(OperationPhase.awaitingDebrief);

      await DailyLogMutationGuard.assertDateMutable(DateTime(2026, 8, 13));
    });
  }

  test('another date is not locked by the current daily close', () async {
    _installState(OperationPhase.awaitingDebrief);

    await DailyLogMutationGuard.assertDateMutable(DateTime(2026, 8, 12));
  });

  test('open current date remains mutable after undo daily close', () async {
    _installState(OperationPhase.open);

    await DailyLogMutationGuard.assertDateMutable(DateTime(2026, 8, 13));
  });

  test('exception exposes the daily close helper text', () {
    expect(
      const ConfirmedDailyLogException().toString(),
      'DAILY CLOSE IN PROGRESS',
    );
  });
}

void _installState(OperationPhase phase) {
  final database = FakeIndexedDbDatabase();
  final date = OperationLocalDate.parse('2026-08-13');
  final now = DateTime.utc(2026, 8, 13, 12);
  database.seed(
    IndexedDbStoreNames.operationState,
    OperationState.canonicalId,
    OperationState(
      operationDate: date,
      phase: phase,
      activeAttempt: phase == OperationPhase.open
          ? null
          : OperationActiveAttempt(
              idempotencyKey: 'daily-close:${date.value}',
              targetLocalDate: date,
              startedAt: now,
              confirmationId: 'confirmation:${date.value}',
              confirmationDigest: 'digest',
            ),
      createdAt: now,
      updatedAt: now,
    ).toRecord(),
  );
  AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
}
