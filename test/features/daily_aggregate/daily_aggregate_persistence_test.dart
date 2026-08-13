import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/indexed_db_daily_aggregate_repository.dart';
import 'package:or_app/features/daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_backup_verifier.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_coordinator.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_transaction.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_undo_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  test('repository put and getByDate preserve the aggregate', () async {
    final database = FakeIndexedDbDatabase();
    final repository = IndexedDbDailyAggregateRepository(database);
    final expected = _aggregate('2026-08-09', weightKg: 80.5);

    await repository.put(expected);

    expect(
      (await repository.getByDate('2026-08-09'))?.toJson(),
      expected.toJson(),
    );
  });

  test(
    'repository getRange is inclusive and operationDate ascending',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbDailyAggregateRepository(database);
      await repository.put(_aggregate('2026-08-11'));
      await repository.put(_aggregate('2026-08-09'));
      await repository.put(_aggregate('2026-08-10'));

      final values = await repository.getRange('2026-08-09', '2026-08-10');

      expect(values.map((value) => value.operationDate), [
        '2026-08-09',
        '2026-08-10',
      ]);
    },
  );

  test('finalize generates, saves, and reads back the aggregate', () async {
    final fixture = await _fixture();

    await fixture.close('2026-08-09');

    final saved = await fixture.aggregates.getByDate('2026-08-09');
    expect(saved?.operationDate, '2026-08-09');
    expect(saved?.sourceType, DailyAggregateSourceType.records);
    expect(saved?.trainingPerformed, isTrue);
  });

  test(
    'undo restores prepared close and preserves finalized artifacts',
    () async {
      final fixture = await _fixture();
      await fixture.close('2026-08-09');
      final confirmationBefore = await fixture.confirmations
          .findPersistedByLocalDate('2026-08-09');
      final aggregateBefore = await fixture.aggregates.getByDate('2026-08-09');
      final debriefRecord = <String, Object?>{
        'localDate': '2026-08-09',
        'revision': 3,
        'previousRevisions': const [1, 2],
      };
      fixture.database.seed(
        IndexedDbStoreNames.dailyDebriefRecords,
        '2026-08-09',
        debriefRecord,
      );
      final inspection = await fixture.undo.inspect();

      await fixture.undo.undo(expectedRevision: inspection.revision);

      final state = await fixture.operationState.requireCurrent();
      expect(state.operationDate.value, '2026-08-09');
      expect(state.phase, OperationPhase.awaitingDebrief);
      expect(state.lastFinalizedDate, isNull);
      expect(state.undoableFinalizeDate, isNull);
      expect(state.activeAttempt?.confirmationId, 'confirmation:2026-08-09');
      expect(
        (await fixture.confirmations.findPersistedByLocalDate(
          '2026-08-09',
        ))?.toRecord(),
        confirmationBefore?.toRecord(),
      );
      expect(
        (await fixture.aggregates.getByDate('2026-08-09'))?.toJson(),
        aggregateBefore?.toJson(),
      );
      expect(
        fixture.database.rawRecord(
          IndexedDbStoreNames.dailyDebriefRecords,
          '2026-08-09',
        ),
        debriefRecord,
      );
      await fixture.coordinator.validateAwaitingState(state);
      expect((await fixture.undo.inspect()).canUndo, isFalse);
    },
  );

  test('prepared daily debrief does not issue finalize undo', () async {
    final fixture = await _fixture();
    final date = OperationLocalDate.parse('2026-08-09');
    await fixture.coordinator.prepareDailyDebrief(targetLocalDate: date);
    final inspection = await fixture.undo.inspect();

    expect(inspection.canUndo, isFalse);
    expect(inspection.isAwaitingDailyClose, isFalse);

    final state = await fixture.operationState.requireCurrent();
    expect(state.operationDate, date);
    expect(state.phase, OperationPhase.awaitingDebrief);
    expect(await fixture.confirmations.findByLocalDate(date.value), isNotNull);
    expect(await fixture.aggregates.getByDate(date.value), isNotNull);
  });

  test('re-finalize replaces the same date from the latest source', () async {
    var weightKg = 80.5;
    final fixture = await _fixture(weight: () => weightKg);
    await fixture.close('2026-08-09');
    final inspection = await fixture.undo.inspect();
    await fixture.undo.undo(expectedRevision: inspection.revision);
    weightKg = 79.8;

    await fixture.close('2026-08-09');

    final saved = await fixture.aggregates.getByDate('2026-08-09');
    expect(saved?.weightKg, 79.8);
    expect(
      await fixture.aggregates.getRange('2026-08-09', '2026-08-09'),
      hasLength(1),
    );
  });
}

Future<_Fixture> _fixture({double Function()? weight}) async {
  final database = FakeIndexedDbDatabase();
  final operationState = IndexedDbOperationStateRepository(
    database,
    now: () => DateTime.utc(2026, 8, 9, 12),
  );
  await operationState.createInitial(OperationLocalDate.parse('2026-08-09'));
  final confirmations = IndexedDbDailyLogConfirmationRepository(
    database,
    now: () => DateTime.utc(2026, 8, 9, 12),
  );
  final controller = AppInitializationController()..markReady();
  final aggregates = IndexedDbDailyAggregateRepository(database);
  final coordinator = DailyFinalizeCoordinator(
    operationState,
    confirmations,
    DailyFinalizeTransaction(
      database,
      now: () => DateTime.utc(2026, 8, 9, 12, 2),
    ),
    DailyFinalizeBackupVerifier(
      BackupExportService(
        database: database,
        controller: controller,
        clock: () => DateTime.utc(2026, 8, 9, 12, 1),
      ),
    ),
    restoreNextDate: () async {},
    buildDailyConfirmation: (date, _) async => completeConfirmation(
      date: DateTime.parse(date.value),
      confirmedAt: DateTime.utc(2026, 8, 9, 12),
    ),
    buildDailyAggregate: (date, _) async => _aggregate(
      date,
      weightKg: weight?.call() ?? 80.5,
      trainingPerformed: true,
    ),
    readDailyAggregate: aggregates.getByDate,
    saveDailyAggregate: aggregates.put,
    validatePreparedDailyDebrief: (_) async {},
    now: () => DateTime.utc(2026, 8, 9, 12),
  );
  return _Fixture(
    database: database,
    aggregates: aggregates,
    confirmations: confirmations,
    operationState: operationState,
    coordinator: coordinator,
    undo: DailyFinalizeUndoService(
      database,
      now: () => DateTime.utc(2026, 8, 9, 12, 3),
    ),
  );
}

DailyAggregateV1 _aggregate(
  String operationDate, {
  double? weightKg,
  bool trainingPerformed = false,
}) => DailyAggregateV1(
  operationDate: operationDate,
  weightKg: weightKg,
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
  trainingPerformed: trainingPerformed,
  digestiveCount: null,
  sourceType: DailyAggregateSourceType.records,
);

class _Fixture {
  const _Fixture({
    required this.database,
    required this.aggregates,
    required this.confirmations,
    required this.operationState,
    required this.coordinator,
    required this.undo,
  });

  final FakeIndexedDbDatabase database;
  final IndexedDbDailyAggregateRepository aggregates;
  final IndexedDbDailyLogConfirmationRepository confirmations;
  final IndexedDbOperationStateRepository operationState;
  final DailyFinalizeCoordinator coordinator;
  final DailyFinalizeUndoService undo;

  Future<void> close(String localDate) async {
    final date = OperationLocalDate.parse(localDate);
    await coordinator.prepareDailyDebrief(targetLocalDate: date);
    await coordinator.finalize(targetLocalDate: date);
  }
}
