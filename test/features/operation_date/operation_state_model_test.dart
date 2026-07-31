import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 31, 1);

  test('round trips the canonical version 1 open record', () {
    final state = OperationState(
      operationDate: OperationLocalDate.parse('2026-07-31'),
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final restored = OperationState.fromRecord(state.toRecord());

    expect(restored.id, OperationState.canonicalId);
    expect(restored.recordVersion, 1);
    expect(restored.operationDate.value, '2026-07-31');
    expect(restored.phase, OperationPhase.open);
    expect(restored.revision, 0);
    expect(restored.activeAttempt, isNull);
  });

  test('ignores unknown fields without weakening required validation', () {
    final record = OperationState(
      operationDate: OperationLocalDate.parse('2026-07-31'),
      createdAt: createdAt,
      updatedAt: createdAt,
    ).toRecord()..['futureField'] = 'preserved-by-future-reader';

    expect(OperationState.fromRecord(record).operationDate.value, '2026-07-31');
    expect(
      () => OperationState.fromRecord({...record, 'recordVersion': 2}),
      throwsFormatException,
    );
  });

  test('rejects invalid dates timestamps revisions and canonical IDs', () {
    final valid = OperationState(
      operationDate: OperationLocalDate.parse('2026-07-31'),
      createdAt: createdAt,
      updatedAt: createdAt,
    ).toRecord();

    for (final invalid in [
      {...valid, 'id': 'other'},
      {...valid, 'operationDate': '2026-02-30'},
      {...valid, 'revision': -1},
      {...valid, 'createdAt': '2026-07-31T01:00:00'},
      {...valid, 'updatedAt': '2026-07-30T01:00:00.000Z'},
      {...valid, 'lastFinalizedDate': '2026-07-31'},
    ]) {
      expect(() => OperationState.fromRecord(invalid), throwsFormatException);
    }
  });

  test('requires phase and active attempt consistency', () {
    final date = OperationLocalDate.parse('2026-07-31');
    final attempt = OperationActiveAttempt(
      idempotencyKey: 'attempt-1',
      targetLocalDate: date,
      startedAt: createdAt,
    );

    expect(
      () => OperationState(
        operationDate: date,
        phase: OperationPhase.open,
        activeAttempt: attempt,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationState(
        operationDate: date,
        phase: OperationPhase.finalizing,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationState(
        operationDate: date,
        phase: OperationPhase.finalizing,
        activeAttempt: OperationActiveAttempt(
          idempotencyKey: 'attempt-2',
          targetLocalDate: OperationLocalDate.parse('2026-08-01'),
          startedAt: createdAt,
        ),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      throwsFormatException,
    );
    expect(
      OperationState(
        operationDate: date,
        phase: OperationPhase.finalizing,
        activeAttempt: attempt,
        createdAt: createdAt,
        updatedAt: createdAt,
      ).requiresRecovery,
      isTrue,
    );
  });

  test('requires confirmation and backup evidence for later phases', () {
    final date = OperationLocalDate.parse('2026-07-31');
    OperationActiveAttempt attempt({
      String? confirmationId,
      String? confirmationDigest,
      String? backupDigest,
      DateTime? backupGeneratedAt,
    }) {
      return OperationActiveAttempt(
        idempotencyKey: 'attempt-1',
        targetLocalDate: date,
        startedAt: createdAt,
        confirmationId: confirmationId,
        confirmationDigest: confirmationDigest,
        backupPackageDigest: backupDigest,
        backupGeneratedAt: backupGeneratedAt,
      );
    }

    expect(
      () => OperationState(
        operationDate: date,
        phase: OperationPhase.finalizedPendingBackup,
        activeAttempt: attempt(),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationState(
        operationDate: date,
        phase: OperationPhase.advancing,
        activeAttempt: attempt(
          confirmationId: 'confirmation:2026-07-31',
          confirmationDigest: 'confirmation-digest',
        ),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      throwsFormatException,
    );
    expect(
      OperationState(
        operationDate: date,
        phase: OperationPhase.advancing,
        activeAttempt: attempt(
          confirmationId: 'confirmation:2026-07-31',
          confirmationDigest: 'confirmation-digest',
          backupDigest: 'backup-digest',
          backupGeneratedAt: createdAt,
        ),
        createdAt: createdAt,
        updatedAt: createdAt,
      ).phase,
      OperationPhase.advancing,
    );
  });

  test('round trips all persistent phases', () {
    final date = OperationLocalDate.parse('2026-07-31');
    final confirmationAttempt = OperationActiveAttempt(
      idempotencyKey: 'attempt-1',
      targetLocalDate: date,
      startedAt: createdAt,
      confirmationId: 'confirmation:2026-07-31',
      confirmationDigest: 'confirmation-digest',
    );
    final advancingAttempt = OperationActiveAttempt(
      idempotencyKey: 'attempt-1',
      targetLocalDate: date,
      startedAt: createdAt,
      confirmationId: 'confirmation:2026-07-31',
      confirmationDigest: 'confirmation-digest',
      backupPackageDigest: 'backup-digest',
      backupGeneratedAt: createdAt,
    );
    final states = [
      OperationState(
        operationDate: date,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      OperationState(
        operationDate: date,
        phase: OperationPhase.finalizing,
        activeAttempt: OperationActiveAttempt(
          idempotencyKey: 'attempt-1',
          targetLocalDate: date,
          startedAt: createdAt,
        ),
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      OperationState(
        operationDate: date,
        phase: OperationPhase.finalizedPendingBackup,
        activeAttempt: confirmationAttempt,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      OperationState(
        operationDate: date,
        phase: OperationPhase.advancing,
        activeAttempt: advancingAttempt,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    ];

    for (final state in states) {
      expect(OperationState.fromRecord(state.toRecord()).phase, state.phase);
    }
    expect(states.map((state) => state.requiresRecovery), [
      isFalse,
      isTrue,
      isTrue,
      isTrue,
    ]);
  });
}
