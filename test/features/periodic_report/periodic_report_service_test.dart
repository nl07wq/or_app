import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/periodic_report/models/periodic_report.dart';
import 'package:or_app/features/periodic_report/services/periodic_report_service.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final now = DateTime.now().toUtc();

  test(
    'prepare exports immutable formal facts and the analysis-only contract',
    () async {
      final fixture = await _fixture(now);
      final prepared = await fixture.service.prepare(
        type: PeriodicReportType.weekly,
        anchor: DateTime(2026, 8, 24),
      );

      expect(prepared.facts.periodId, 'weekly:2026-08-24');
      expect(prepared.prompt, contains('"exchangeType": "periodicReport"'));
      expect(prepared.prompt, contains('"reportType": "weekly"'));
      expect(prepared.prompt, contains('7700 kcal/kg'));
      expect(prepared.prompt, contains('Do not invent'));
      expect(prepared.prompt, contains('HUMAN-FACING ANALYSIS PRESENTATION'));
      expect(prepared.prompt, contains('98.33 kg becomes 98.3 kg'));
      expect(prepared.prompt, contains('12500 becomes 12,500'));
      expect(prepared.prompt, contains('369.9 minutes'));
      expect(prepared.prompt, contains('becomes 6:10'));
      expect(prepared.prompt, contains('without an unnecessary .0 suffix'));
      expect(prepared.prompt, contains('custom or unknown exercise name'));
      expect(prepared.prompt, contains('DISPLAY-ONLY EXERCISE LABELS'));
      expect(
        prepared.prompt,
        contains('Keep every source and derived duration value in minutes'),
      );
      expect(prepared.prompt, contains('"total": -1540.0'));
      expect(prepared.facts.metrics['calorieBalanceKcal']!.total, -1540.0);
      expect(PeriodicReportPayloadExample.analysis.keys, {
        'body',
        'nutrition',
        'calorieBalance',
        'activity',
        'recovery',
        'training',
        'condition',
        'operation',
        'overallSummary',
        'nextPeriodFocus',
      });
      final exerciseLabels = periodicReportExerciseDisplayLabels(const [
        'Bench Press',
        'Hack Squat',
        'Lat Pulldown',
        'Leg Press',
        'Shoulder Press',
        'Custom Rope Pull',
      ]);
      expect(exerciseLabels['Bench Press'], isNot('Bench Press'));
      expect(exerciseLabels['Hack Squat'], isNot('Hack Squat'));
      expect(exerciseLabels['Lat Pulldown'], isNot('Lat Pulldown'));
      expect(exerciseLabels['Leg Press'], isNot('Leg Press'));
      expect(exerciseLabels['Shoulder Press'], isNot('Shoulder Press'));
      expect(exerciseLabels['Custom Rope Pull'], 'Custom Rope Pull');
    },
  );

  test('imports Rev 1 and Rev 2 and preserves Rev 1', () async {
    final fixture = await _fixture(now);
    final prepared = await fixture.service.prepare(
      type: PeriodicReportType.weekly,
      anchor: DateTime(2026, 8, 24),
    );

    Future<PeriodicReportRecord> import(String id, String summary) async {
      final response = fixture.container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        exchangeType: ReportSyncExchangeType.periodicReport,
        exchangeId: id,
        operationDate: prepared.facts.endDate,
        createdAt: now,
        payload: {
          'operationDate': prepared.facts.endDate,
          'periodId': prepared.facts.periodId,
          'reportType': prepared.facts.reportType.stableId,
          'sourceDigest': ReportSyncCanonicalService.digest(
            prepared.facts.toJson(),
          ),
          'analysis': _analysis(summary).toJson(),
        },
      );
      final preview = await fixture.service.preview(
        type: PeriodicReportType.weekly,
        anchor: DateTime(2026, 8, 24),
        rawResponse: fixture.container.reportSyncCodec.encode(response),
      );
      return fixture.service.apply(preview);
    }

    final first = await import('periodic-response-1', 'first');
    final second = await import('periodic-response-2', 'second');
    expect(first.revision, 1);
    expect(second.revision, 2);
    expect(second.previousRevisions.single.analysis.overallSummary, 'first');
    expect(second.analysis.overallSummary, 'second');
    expect(
      (await fixture.container.reportSyncHistory.list())
          .where(
            (value) =>
                value.exchangeType == ReportSyncExchangeType.periodicReport &&
                value.direction == ReportSyncDirection.response,
          )
          .length,
      2,
    );
  });

  test(
    'history uses app import clock when response createdAt is in the future',
    () async {
      final fixture = await _fixture(now);
      final prepared = await fixture.service.prepare(
        type: PeriodicReportType.weekly,
        anchor: DateTime(2026, 8, 24),
      );
      final responseCreatedAt = now.add(const Duration(hours: 2));
      final response = fixture.container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        exchangeType: ReportSyncExchangeType.periodicReport,
        exchangeId: 'periodic-future-response',
        operationDate: prepared.facts.endDate,
        createdAt: responseCreatedAt,
        payload: {
          'operationDate': prepared.facts.endDate,
          'periodId': prepared.facts.periodId,
          'reportType': prepared.facts.reportType.stableId,
          'sourceDigest': ReportSyncCanonicalService.digest(
            prepared.facts.toJson(),
          ),
          'analysis': _analysis('future metadata').toJson(),
        },
      );
      final startedAt = now.add(const Duration(minutes: 1));
      final completedAt = now.add(const Duration(minutes: 2));
      final clock = _SequenceClock([startedAt, completedAt]);
      final service = PeriodicReportService(
        container: fixture.container,
        clock: clock.call,
      );
      final preview = await service.preview(
        type: PeriodicReportType.weekly,
        anchor: DateTime(2026, 8, 24),
        rawResponse: fixture.container.reportSyncCodec.encode(response),
      );

      await service.apply(preview);

      final history = (await fixture.container.reportSyncHistory.list())
          .singleWhere(
            (value) => value.exchangeId == 'periodic-future-response',
          );
      expect(preview.response.createdAt, responseCreatedAt);
      expect(history.startedAt, startedAt);
      expect(history.completedAt, completedAt);
      expect(history.completedAt.isBefore(history.startedAt), isFalse);
      expect(clock.calls, 2);
    },
  );
}

Future<_Fixture> _fixture(DateTime now) async {
  final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
  await container.operationState.createInitial(
    OperationLocalDate.parse('2026-08-31'),
  );
  await container.dailyAggregates.put(_daily('2026-08-24', -770));
  await container.dailyAggregates.put(_daily('2026-08-30', -770));
  return _Fixture(
    container,
    PeriodicReportService(container: container, clock: () => now),
  );
}

DailyAggregateV1 _daily(String date, double balance) => DailyAggregateV1(
  operationDate: date,
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
  estimatedCalorieBalanceKcal: balance,
  proteinG: null,
  fatG: null,
  carbsG: null,
  hydrationMl: null,
  officialSteps: null,
  measuredSteps: null,
  trainingPerformed: false,
  digestiveCount: null,
  sourceType: DailyAggregateSourceType.records,
);

PeriodicReportAnalysis _analysis(String summary) => PeriodicReportAnalysis(
  body: 'body',
  nutrition: 'nutrition',
  calorieBalance: 'balance',
  activity: 'activity',
  recovery: 'recovery',
  training: 'training',
  condition: 'condition',
  operation: 'operation',
  overallSummary: summary,
  nextPeriodFocus: 'focus',
);

class _Fixture {
  const _Fixture(this.container, this.service);
  final AppRepositoryContainer container;
  final PeriodicReportService service;
}

class _SequenceClock {
  _SequenceClock(this._values);

  final List<DateTime> _values;
  int calls = 0;

  DateTime call() => _values[calls++];
}
