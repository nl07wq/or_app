import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/indexed_db_daily_aggregate_repository.dart';
import 'package:or_app/features/daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
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

    await fixture.coordinator.finalize(
      targetLocalDate: OperationLocalDate.parse('2026-08-09'),
    );

    final saved = await fixture.aggregates.getByDate('2026-08-09');
    expect(saved?.operationDate, '2026-08-09');
    expect(saved?.sourceType, DailyAggregateSourceType.records);
    expect(saved?.trainingPerformed, isTrue);
  });

  test('undo last finalize deletes the target aggregate', () async {
    final fixture = await _fixture();
    await fixture.coordinator.finalize(
      targetLocalDate: OperationLocalDate.parse('2026-08-09'),
    );
    final inspection = await fixture.undo.inspect();

    await fixture.undo.undo(expectedRevision: inspection.revision);

    expect(await fixture.aggregates.getByDate('2026-08-09'), isNull);
  });

  test('re-finalize replaces the same date from the latest source', () async {
    var weightKg = 80.5;
    final fixture = await _fixture(weight: () => weightKg);
    await fixture.coordinator.finalize(
      targetLocalDate: OperationLocalDate.parse('2026-08-09'),
    );
    final inspection = await fixture.undo.inspect();
    await fixture.undo.undo(expectedRevision: inspection.revision);
    weightKg = 79.8;

    await fixture.coordinator.finalize(
      targetLocalDate: OperationLocalDate.parse('2026-08-09'),
    );

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
    now: () => DateTime.utc(2026, 8, 9, 12),
  );
  return _Fixture(
    aggregates: aggregates,
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
    required this.aggregates,
    required this.coordinator,
    required this.undo,
  });

  final IndexedDbDailyAggregateRepository aggregates;
  final DailyFinalizeCoordinator coordinator;
  final DailyFinalizeUndoService undo;
}
