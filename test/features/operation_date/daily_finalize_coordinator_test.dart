import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/indexed_db_daily_aggregate_repository.dart';
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
      'prepare atomically stores confirmation and aggregate and awaits DD',
      () async {
        final fixture = await _fixture('2026-07-31');

        final result = await fixture.coordinator.prepareDailyDebrief(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        );

        expect(result.operationDate.value, '2026-07-31');
        expect(result.confirmationId, 'confirmation:2026-07-31');
        expect(await fixture.confirmations.findAll(), hasLength(1));
        expect(await fixture.aggregates.getByDate('2026-07-31'), isNotNull);
        final state = await fixture.operationState.requireCurrent();
        expect(state.operationDate.value, '2026-07-31');
        expect(state.phase, OperationPhase.awaitingDebrief);
        expect(state.requiresRecovery, isFalse);
        expect(fixture.restoreCount, 0);
      },
    );

    test(
      'finalize validates DD, backs up, advances once, and restores',
      () async {
        final fixture = await _fixture('2026-07-31');
        await fixture.coordinator.prepareDailyDebrief(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        );

        final result = await fixture.coordinator.finalize(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        );

        expect(result.finalizedDate.value, '2026-07-31');
        expect(result.nextOperationDate.value, '2026-08-01');
        expect(result.backupPackageDigest, isNotEmpty);
        expect(fixture.restoreCount, 1);
        final state = await fixture.operationState.requireCurrent();
        expect(state.operationDate.value, '2026-08-01');
        expect(state.lastFinalizedDate?.value, '2026-07-31');
        expect(state.phase, OperationPhase.open);
        expect(state.activeAttempt, isNull);
      },
    );

    test('finalize is read-only blocked when DD is not ACTIVE', () async {
      final fixture = await _fixture('2026-07-31');
      await fixture.coordinator.prepareDailyDebrief(
        targetLocalDate: OperationLocalDate.parse('2026-07-31'),
      );
      fixture.debriefActive = false;
      final before = await fixture.operationState.requireCurrent();

      await expectLater(
        fixture.coordinator.finalize(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        ),
        throwsA(isA<StateError>()),
      );

      final after = await fixture.operationState.requireCurrent();
      expect(after.revision, before.revision);
      expect(after.phase, OperationPhase.awaitingDebrief);
      expect(after.operationDate, before.operationDate);
    });

    for (final dates in const [
      ('2026-01-31', '2026-02-01'),
      ('2026-12-31', '2027-01-01'),
      ('2028-02-28', '2028-02-29'),
      ('2028-02-29', '2028-03-01'),
    ]) {
      test('advances calendar date ${dates.$1} to ${dates.$2}', () async {
        final fixture = await _fixture(dates.$1);
        await fixture.coordinator.prepareDailyDebrief(
          targetLocalDate: OperationLocalDate.parse(dates.$1),
        );

        final result = await fixture.coordinator.finalize(
          targetLocalDate: OperationLocalDate.parse(dates.$1),
        );

        expect(result.nextOperationDate.value, dates.$2);
      });
    }

    test('rejects a historical preparation target without mutation', () async {
      final fixture = await _fixture('2026-07-31');

      await expectLater(
        fixture.coordinator.prepareDailyDebrief(
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
    });

    test('concurrent preparation acquires one close lock', () async {
      final fixture = await _fixture('2026-07-31');
      Future<Object> run() async {
        try {
          return await fixture.coordinator.prepareDailyDebrief(
            targetLocalDate: OperationLocalDate.parse('2026-07-31'),
          );
        } catch (error) {
          return error;
        }
      }

      final results = await Future.wait([run(), run()]);

      expect(results.whereType<DailyClosePreparationResult>(), hasLength(1));
      expect(results.whereType<DailyFinalizeException>(), hasLength(1));
      expect(
        (await fixture.operationState.requireCurrent()).phase,
        OperationPhase.awaitingDebrief,
      );
    });

    test(
      're-create updates the same confirmation and aggregate identity',
      () async {
        final fixture = await _fixture('2026-07-31');
        final date = OperationLocalDate.parse('2026-07-31');
        await fixture.coordinator.prepareDailyDebrief(targetLocalDate: date);
        final first = await fixture.confirmations.findPersistedByLocalDate(
          date.value,
        );
        fixture.trainingName = 'Updated';

        await fixture.coordinator.prepareDailyDebrief(targetLocalDate: date);

        final second = await fixture.confirmations.findPersistedByLocalDate(
          date.value,
        );
        final state = await fixture.operationState.requireCurrent();
        expect(state.phase, OperationPhase.awaitingDebrief);
        expect(second!.id, first!.id);
        expect(second.projectedRevision, first.projectedRevision + 1);
        expect(
          second.projectedSnapshotDigest,
          isNot(first.projectedSnapshotDigest),
        );
        expect(await fixture.confirmations.findAll(), hasLength(1));
        expect(await fixture.aggregates.getByDate(date.value), isNotNull);
      },
    );

    test('finalize rejects current source changes until re-create', () async {
      final fixture = await _fixture('2026-07-31');
      final date = OperationLocalDate.parse('2026-07-31');
      await fixture.coordinator.prepareDailyDebrief(targetLocalDate: date);
      fixture.trainingName = 'Changed after create';

      await expectLater(
        fixture.coordinator.finalize(targetLocalDate: date),
        throwsA(isA<StateError>()),
      );

      final state = await fixture.operationState.requireCurrent();
      expect(state.operationDate, date);
      expect(state.phase, OperationPhase.awaitingDebrief);
    });

    test(
      'backup failure keeps awaiting artifacts and finalize can retry',
      () async {
        final controller = AppInitializationController();
        final fixture = await _fixture('2026-07-31', controller: controller);
        await fixture.coordinator.prepareDailyDebrief(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        );

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
        expect(
          (await fixture.operationState.requireCurrent()).phase,
          OperationPhase.awaitingDebrief,
        );
        expect(await fixture.confirmations.findAll(), hasLength(1));
        expect(await fixture.aggregates.getByDate('2026-07-31'), isNotNull);

        controller.markReady();
        final result = await fixture.coordinator.finalize(
          targetLocalDate: OperationLocalDate.parse('2026-07-31'),
        );
        expect(result.nextOperationDate.value, '2026-08-01');
      },
    );

    test('reload in finalizing resumes only through awaiting DD', () async {
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

      expect(result, isNull);
      expect(
        (await fixture.operationState.requireCurrent()).phase,
        OperationPhase.awaitingDebrief,
      );
      expect(await fixture.confirmations.findAll(), hasLength(1));
    });

    test('reload in awaiting debrief validates without advancing', () async {
      final fixture = await _fixture('2026-07-31');
      final date = OperationLocalDate.parse('2026-07-31');
      await fixture.coordinator.prepareDailyDebrief(targetLocalDate: date);
      final before = await fixture.operationState.requireCurrent();

      final result = await fixture.coordinator.recover();

      final after = await fixture.operationState.requireCurrent();
      expect(result, isNull);
      expect(after.toRecord(), before.toRecord());
      expect(after.phase, OperationPhase.awaitingDebrief);
      expect(after.operationDate, date);
      expect(fixture.restoreCount, 0);
    });

    test('reload in advancing completes one pending date advance', () async {
      final fixture = await _fixture('2026-07-31');
      final date = OperationLocalDate.parse('2026-07-31');
      final confirmation = completeConfirmation(date: DateTime(2026, 7, 31));
      await fixture.confirmations.save(confirmation);
      await fixture.aggregates.put(_aggregate(date.value));
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

      expect(result?.nextOperationDate.value, '2026-08-01');
      expect(
        (await fixture.operationState.requireCurrent()).operationDate.value,
        '2026-08-01',
      );
    });

    test('preparation transaction failure rolls back all artifacts', () async {
      final fixture = await _fixture('2026-07-31');
      fixture.database.failOnTransactionNumber = 3;

      await expectLater(
        fixture.coordinator.prepareDailyDebrief(
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
        await fixture.database.findAll(
          IndexedDbStoreNames.dailyAggregateRecords,
        ),
        isEmpty,
      );
    });

    test('completed finalize cannot advance the same date twice', () async {
      final fixture = await _fixture('2026-07-31');
      await fixture.coordinator.prepareDailyDebrief(
        targetLocalDate: OperationLocalDate.parse('2026-07-31'),
      );
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
    });
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
  final aggregates = IndexedDbDailyAggregateRepository(database);
  final initialization =
      controller ?? (AppInitializationController()..markReady());
  late _Fixture fixture;
  final coordinator = DailyFinalizeCoordinator(
    operationState,
    confirmations,
    DailyFinalizeTransaction(
      database,
      now: () => DateTime.utc(2026, 7, 31, 12, 2),
    ),
    DailyFinalizeBackupVerifier(
      BackupExportService(
        database: database,
        controller: initialization,
        clock: () => DateTime.utc(2026, 7, 31, 12, 5),
      ),
    ),
    restoreNextDate: () async => fixture.restoreCount++,
    buildDailyConfirmation: (date, _) async => completeConfirmation(
      date: DateTime.parse(date.value),
      confirmedAt: DateTime.utc(2026, 7, 31, 12, 1),
      trainingName: fixture.trainingName,
    ),
    buildDailyAggregate: (date, _) async => _aggregate(date),
    readDailyAggregate: aggregates.getByDate,
    saveDailyAggregate: aggregates.put,
    validatePreparedDailyDebrief: (_) async {
      if (!fixture.debriefActive) throw StateError('DD is not ACTIVE.');
    },
    now: () => DateTime.utc(2026, 7, 31, 12),
  );
  fixture = _Fixture(
    database: database,
    operationState: operationState,
    confirmations: confirmations,
    aggregates: aggregates,
    coordinator: coordinator,
  );
  return fixture;
}

DailyAggregateV1 _aggregate(String operationDate) => DailyAggregateV1(
  operationDate: operationDate,
  weightKg: null,
  bodyFatPercent: null,
  sleepDurationMinutes: null,
  sleepScore: null,
  sleepType: null,
  plantarFasciitisLevel: null,
  workStartTime: null,
  workEndTime: null,
  workBreakMinutes: null,
  actualWorkMinutes: null,
  intakeCaloriesKcal: null,
  proteinG: null,
  fatG: null,
  carbsG: null,
  hydrationMl: 0,
  officialSteps: null,
  measuredSteps: null,
  trainingPerformed: false,
  digestiveCount: null,
  sourceType: DailyAggregateSourceType.records,
);

class _Fixture {
  final FakeIndexedDbDatabase database;
  final IndexedDbOperationStateRepository operationState;
  final IndexedDbDailyLogConfirmationRepository confirmations;
  final IndexedDbDailyAggregateRepository aggregates;
  final DailyFinalizeCoordinator coordinator;
  int restoreCount = 0;
  bool debriefActive = true;
  String trainingName = 'Session';

  _Fixture({
    required this.database,
    required this.operationState,
    required this.confirmations,
    required this.aggregates,
    required this.coordinator,
  });
}
