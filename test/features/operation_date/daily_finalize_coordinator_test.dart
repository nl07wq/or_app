import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/operation_date/models/daily_finalize_result.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_backup_verifier.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_coordinator.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_integrity_service.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_transaction.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  group('DailyFinalizeCoordinator', () {
    test(
      'finalizes, verifies backup, advances once, and restores next date',
      () async {
        final fixture = await _fixture('2026-07-31');

        final result = await fixture.coordinator.finalize(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        );

        expect(result.finalizedDate.value, '2026-07-31');
        expect(result.nextOperationDate.value, '2026-08-01');
        expect(result.confirmationId, 'confirmation:2026-07-31');
        expect(result.confirmationDigest, isNotEmpty);
        expect(result.backupPackageDigest, isNotEmpty);
        expect(fixture.restoreCount, 1);
        final state = await fixture.operationState.requireCurrent();
        expect(state.operationDate.value, '2026-08-01');
        expect(state.lastFinalizedDate?.value, '2026-07-31');
        expect(state.phase, OperationPhase.open);
        expect(state.activeAttempt, isNull);
      },
    );

    for (final dates in const [
      ('2026-01-31', '2026-02-01'),
      ('2026-12-31', '2027-01-01'),
      ('2028-02-28', '2028-02-29'),
      ('2028-02-29', '2028-03-01'),
    ]) {
      test('advances calendar date ${dates.$1} to ${dates.$2}', () async {
        final fixture = await _fixture(dates.$1);

        final result = await fixture.coordinator.finalize(
          targetLocalDate: OperationLocalDate.parse(dates.$1),
        );

        expect(result.nextOperationDate.value, dates.$2);
      });
    }

    test(
      'rejects a historical target without changing operation state',
      () async {
        final fixture = await _fixture('2026-07-31');

        await expectLater(
          fixture.coordinator.finalize(
            targetLocalDate: OperationLocalDate.parse('2026-07-30'),
          ),
          throwsA(
            isA<DailyFinalizeException>().having(
              (error) => error.code,
              'code',
              DailyFinalizeFailureCode.validationFailed,
            ),
          ),
        );

        expect(
          (await fixture.operationState.requireCurrent()).operationDate.value,
          '2026-07-31',
        );
      },
    );

    test('revision guard permits only one concurrent finalize lock', () async {
      final fixture = await _fixture('2026-07-31');
      Future<Object> run() async {
        try {
          return await fixture.coordinator.finalize(
            targetLocalDate: OperationLocalDate.parse('2026-07-31'),
          );
        } catch (error) {
          return error;
        }
      }

      final results = await Future.wait([run(), run()]);

      expect(results.whereType<DailyFinalizeResult>(), hasLength(1));
      expect(results.whereType<DailyFinalizeException>(), hasLength(1));
      expect(
        (await fixture.operationState.requireCurrent()).operationDate.value,
        '2026-08-01',
      );
    });

    test(
      'different existing confirmation stops as integrity conflict',
      () async {
        final fixture = await _fixture('2026-07-31');
        await fixture.confirmations.save(
          completeConfirmation(
            date: DateTime(2026, 7, 31),
            trainingName: 'Different',
          ).copyWith(estimatedTotalBurnKcal: 999),
        );

        await expectLater(
          fixture.coordinator.finalize(
            targetLocalDate: OperationLocalDate.parse('2026-07-31'),
          ),
          throwsA(
            isA<DailyFinalizeException>().having(
              (error) => error.code,
              'code',
              DailyFinalizeFailureCode.confirmationDigestMismatch,
            ),
          ),
        );

        final state = await fixture.operationState.requireCurrent();
        expect(state.operationDate.value, '2026-07-31');
        expect(state.phase, OperationPhase.finalizing);
        expect(
          state.activeAttempt?.failureCode,
          DailyFinalizeFailureCode.confirmationDigestMismatch.name,
        );
      },
    );

    test(
      'backup failure keeps confirmation and resumes without duplication',
      () async {
        final controller = AppInitializationController();
        final fixture = await _fixture('2026-07-31', controller: controller);

        await expectLater(
          fixture.coordinator.finalize(
            targetLocalDate: OperationLocalDate.parse('2026-07-31'),
          ),
          throwsA(
            isA<DailyFinalizeException>().having(
              (error) => error.code,
              'code',
              DailyFinalizeFailureCode.backupGenerationFailed,
            ),
          ),
        );
        var state = await fixture.operationState.requireCurrent();
        expect(state.phase, OperationPhase.finalizedPendingBackup);
        expect(await fixture.confirmations.findAll(), hasLength(1));

        controller.markReady();
        final result = await fixture.coordinator.recover();

        expect(result.nextOperationDate.value, '2026-08-01');
        expect(await fixture.confirmations.findAll(), hasLength(1));
        state = await fixture.operationState.requireCurrent();
        expect(state.phase, OperationPhase.open);
      },
    );

    test('reload in finalizing resumes from confirmation generation', () async {
      final fixture = await _fixture('2026-07-31');
      final current = await fixture.operationState.requireCurrent();
      final date = current.operationDate;
      await fixture.operationState.compareAndSaveRevision(
        current.copyWith(
          phase: OperationPhase.finalizing,
          activeAttempt: OperationActiveAttempt(
            idempotencyKey: 'daily-finalize:${date.value}',
            targetLocalDate: date,
            startedAt: DateTime.utc(2026, 7, 31, 12),
          ),
        ),
        expectedRevision: current.revision,
      );

      final result = await fixture.coordinator.recover();

      expect(result.finalizedDate, date);
      expect(result.nextOperationDate.value, '2026-08-01');
      expect(await fixture.confirmations.findAll(), hasLength(1));
    });

    test('reload in advancing completes one pending date advance', () async {
      final fixture = await _fixture('2026-07-31');
      final date = OperationLocalDate.parse('2026-07-31');
      final confirmation = completeConfirmation(date: DateTime(2026, 7, 31));
      await fixture.confirmations.save(confirmation);
      final digest = DailyFinalizeIntegrityService(
        fixture.operationState,
        fixture.confirmations,
      ).confirmationDigest(confirmation);
      final current = await fixture.operationState.requireCurrent();
      await fixture.operationState.compareAndSaveRevision(
        current.copyWith(
          phase: OperationPhase.advancing,
          activeAttempt: OperationActiveAttempt(
            idempotencyKey: 'daily-finalize:${date.value}',
            targetLocalDate: date,
            startedAt: DateTime.utc(2026, 7, 31, 12),
            confirmationId: 'confirmation:${date.value}',
            confirmationDigest: digest,
            backupPackageDigest: 'verified-package-digest',
            backupGeneratedAt: DateTime.utc(2026, 7, 31, 12, 5),
          ),
        ),
        expectedRevision: current.revision,
      );

      final result = await fixture.coordinator.recover();

      expect(result.nextOperationDate.value, '2026-08-01');
      expect(
        (await fixture.operationState.requireCurrent()).operationDate.value,
        '2026-08-01',
      );
    });

    test(
      'confirmation transaction failure rolls back the confirmation',
      () async {
        final fixture = await _fixture('2026-07-31');
        fixture.database.failOnTransactionNumber = 3;

        await expectLater(
          fixture.coordinator.finalize(
            targetLocalDate: OperationLocalDate.parse('2026-07-31'),
          ),
          throwsA(isA<DailyFinalizeException>()),
        );

        expect(
          await fixture.database.findAll(
            IndexedDbStoreNames.dailyLogConfirmations,
          ),
          isEmpty,
        );
        expect(
          (await fixture.operationState.requireCurrent()).operationDate.value,
          '2026-07-31',
        );
      },
    );

    test(
      'retry after completed finalize cannot advance the same date twice',
      () async {
        final fixture = await _fixture('2026-07-31');
        await fixture.coordinator.finalize(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        );

        await expectLater(
          fixture.coordinator.finalize(
            targetLocalDate: OperationLocalDate.parse('2026-07-31'),
          ),
          throwsA(isA<DailyFinalizeException>()),
        );

        expect(
          (await fixture.operationState.requireCurrent()).operationDate.value,
          '2026-08-01',
        );
      },
    );
  });
}

Future<_Fixture> _fixture(
  String localDate, {
  AppInitializationController? controller,
}) async {
  final database = FakeIndexedDbDatabase();
  final operationState = IndexedDbOperationStateRepository(
    database,
    now: () => DateTime.utc(2026, 7, 31, 12),
  );
  await operationState.createInitial(OperationLocalDate.parse(localDate));
  final confirmations = IndexedDbDailyLogConfirmationRepository(
    database,
    now: () => DateTime.utc(2026, 7, 31, 12),
  );
  final initialization =
      controller ?? (AppInitializationController()..markReady());
  var restoreCount = 0;
  late _Fixture fixture;
  final coordinator = DailyFinalizeCoordinator(
    operationState,
    confirmations,
    DailyFinalizeTransaction(
      database,
      now: () => DateTime.utc(2026, 7, 31, 12),
    ),
    DailyFinalizeBackupVerifier(
      BackupExportService(
        database: database,
        controller: initialization,
        clock: () => DateTime.utc(2026, 7, 31, 12, 5),
      ),
    ),
    restoreNextDate: () async {
      restoreCount++;
      fixture.restoreCount = restoreCount;
    },
    buildDailyConfirmation: (date, _) async => completeConfirmation(
      date: DateTime.parse(date.value),
      confirmedAt: DateTime.utc(2026, 7, 31, 12, 1),
    ),
    now: () => DateTime.utc(2026, 7, 31, 12),
  );
  fixture = _Fixture(
    database: database,
    operationState: operationState,
    confirmations: confirmations,
    coordinator: coordinator,
  );
  return fixture;
}

class _Fixture {
  final FakeIndexedDbDatabase database;
  final IndexedDbOperationStateRepository operationState;
  final IndexedDbDailyLogConfirmationRepository confirmations;
  final DailyFinalizeCoordinator coordinator;
  int restoreCount = 0;

  _Fixture({
    required this.database,
    required this.operationState,
    required this.confirmations,
    required this.coordinator,
  });
}
