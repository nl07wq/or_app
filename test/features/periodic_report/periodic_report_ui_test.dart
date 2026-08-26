import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/command_center/pages/command_center_page.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/periodic_report/models/periodic_report.dart';
import 'package:or_app/features/periodic_report/pages/periodic_report_page.dart';
import 'package:or_app/features/periodic_report/widgets/periodic_report_chart.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  test('FINALIZE candidates retain weekly monthly yearly order', () {
    expect(periodicReportTypesForFinalizedDate(DateTime(2027, 1, 31)), [
      PeriodicReportType.weekly,
      PeriodicReportType.monthly,
    ]);
    expect(periodicReportTypesForFinalizedDate(DateTime(2027, 12, 31)), [
      PeriodicReportType.monthly,
      PeriodicReportType.yearly,
    ]);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('Periodic Report panel has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _install(operationDate: '2026-08-31');
      await _pump(
        tester,
        width: width,
        child: const PeriodicReportPanel(reportType: PeriodicReportType.weekly),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('WEEKLY REPORT'), findsOneWidget);
      expect(find.text('WEEK OF 2026-08-24'), findsOneWidget);
      expect(find.text('CREATE REPORT'), findsOneWidget);
    });
  }

  testWidgets('weekly report uses semantic cards and formal daily charts', (
    tester,
  ) async {
    final fixture = await _install(operationDate: '2026-09-01');
    final report = _report(
      PeriodicReportType.weekly,
      '2026-08-24',
      revision: 2,
    );
    _seedReport(fixture.database, report);
    await fixture.container.dailyAggregates.put(
      _daily('2026-08-24', weight: 98.33, steps: 8000, calories: 2208.57),
    );
    await fixture.container.dailyAggregates.put(
      _daily('2026-08-26', weight: 97.91, steps: 9200, calories: 2100),
    );

    await _pump(
      tester,
      width: 390,
      height: 9000,
      child: PeriodicReportPanel(
        reportType: PeriodicReportType.weekly,
        initialAnchor: DateTime(2026, 8, 24),
      ),
    );

    expect(find.text('REV 2'), findsOneWidget);
    expect(find.text('LATEST'), findsOneWidget);
    for (final key in [
      'overall-summary',
      'body',
      'nutrition',
      'calorie-balance',
      'activity',
      'recovery',
      'training',
      'condition',
      'operation',
      'next-period-focus',
    ]) {
      expect(
        find.byKey(ValueKey('periodic-report-section-$key')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey('periodic-report-chart-conditionLevel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('periodic-report-chart-weightKg')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('periodic-report-chart-officialSteps')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('periodic-report-chart-intakeCaloriesKcal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('periodic-report-chart-calorieBalanceKcal')),
      findsOneWidget,
    );
    expect(find.textContaining('AVERAGE 98.3'), findsOneWidget);
    expect(find.textContaining('TOTAL 17200'), findsOneWidget);
    expect(find.textContaining('98.33'), findsNothing);
    expect(
      find.byKey(const ValueKey('periodic-report-previous-revisions')),
      findsOneWidget,
    );

    final chart = tester.widget<PeriodicReportChart>(
      find.byKey(const ValueKey('periodic-report-chart-weightKg')),
    );
    expect(chart.points.map((point) => point.x), [0, 2]);
    expect(chart.points.any((point) => point.value == 0), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly report keeps daily facts and a scrollable day axis', (
    tester,
  ) async {
    final fixture = await _install(operationDate: '2026-08-01');
    final report = _report(PeriodicReportType.monthly, '2026-07-01');
    _seedReport(fixture.database, report);
    await fixture.container.dailyAggregates.put(
      _daily('2026-07-01', weight: 98, steps: 7000, calories: 2000),
    );
    await fixture.container.dailyAggregates.put(
      _daily('2026-07-31', weight: 96, steps: 9000, calories: 2100),
    );

    await _pump(
      tester,
      width: 390,
      height: 5000,
      child: PeriodicReportPanel(
        reportType: PeriodicReportType.monthly,
        initialAnchor: DateTime(2026, 7),
      ),
    );

    expect(find.text('MONTHLY REPORT'), findsOneWidget);
    expect(find.text('2026-07'), findsOneWidget);
    final chart = tester.widget<PeriodicReportChart>(
      find.byKey(const ValueKey('periodic-report-chart-weightKg')),
    );
    expect(chart.maximumIndex, 30);
    expect(chart.points.map((point) => point.label), ['1', '31']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yearly charts use generated monthly report facts only', (
    tester,
  ) async {
    final fixture = await _install(operationDate: '2026-01-01');
    final yearly = _report(PeriodicReportType.yearly, '2025-01-01');
    _seedReport(fixture.database, yearly);
    _seedReport(
      fixture.database,
      _report(PeriodicReportType.monthly, '2025-01-01', weightAverage: 99),
    );
    _seedReport(
      fixture.database,
      _report(PeriodicReportType.monthly, '2025-12-01', weightAverage: 94),
    );

    await _pump(
      tester,
      width: 900,
      height: 6000,
      child: PeriodicReportPanel(
        reportType: PeriodicReportType.yearly,
        initialAnchor: DateTime(2025),
      ),
    );

    expect(find.text('YEARLY REPORT'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    final weightChart = tester.widget<PeriodicReportChart>(
      find.byKey(const ValueKey('periodic-report-chart-weightKg')),
    );
    expect(weightChart.maximumIndex, 11);
    expect(weightChart.points.map((point) => point.label), ['JAN', 'DEC']);
    expect(
      find.byKey(const ValueKey('periodic-report-chart-trainingSessionCount')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('import action bar clears transient state but keeps report', (
    tester,
  ) async {
    final fixture = await _install(operationDate: '2026-09-01');
    final report = _report(PeriodicReportType.weekly, '2026-08-24');
    _seedReport(fixture.database, report);
    await fixture.container.dailyAggregates.put(
      _daily('2026-08-24', weight: 98, steps: 8000, calories: 2100),
    );
    final original = fixture.database.rawRecord(
      IndexedDbStoreNames.periodicReportRecords,
      report.id,
    );

    await _pump(
      tester,
      width: 320,
      height: 1600,
      child: PeriodicReportPanel(
        reportType: PeriodicReportType.weekly,
        initialAnchor: DateTime(2026, 8, 24),
      ),
    );
    await tester.tap(find.text('CREATE REVISION'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('periodic-report-response-action-bar')),
      findsOneWidget,
    );
    expect(find.byIcon(Symbols.content_paste), findsOneWidget);
    expect(find.byIcon(Symbols.backspace), findsOneWidget);
    expect(find.byIcon(Symbols.fact_check), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('periodic-report-response-input')),
      'temporary response',
    );
    await tester.tap(find.text('VALIDATE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CLEAR'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('periodic-report-response-input')),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.text('REV 1'), findsOneWidget);
    expect(
      fixture.database.rawRecord(
        IndexedDbStoreNames.periodicReportRecords,
        report.id,
      ),
      original,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<_Fixture> _install({required String operationDate}) async {
  final database = FakeIndexedDbDatabase();
  final container = AppRepositoryContainer.indexedDb(database);
  await container.operationState.createInitial(
    OperationLocalDate.parse(operationDate),
  );
  AppRepositoryRegistry.install(container);
  return _Fixture(database: database, container: container);
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double height = 900,
  required Widget child,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void _seedReport(FakeIndexedDbDatabase database, PeriodicReportRecord report) {
  database.seed(
    IndexedDbStoreNames.periodicReportRecords,
    report.id,
    report.toRecord(),
  );
}

PeriodicReportRecord _report(
  PeriodicReportType type,
  String startDate, {
  int revision = 1,
  double weightAverage = 98.33,
}) {
  final start = DateTime.parse(startDate);
  final end = switch (type) {
    PeriodicReportType.weekly => start.add(const Duration(days: 6)),
    PeriodicReportType.monthly => DateTime(start.year, start.month + 1, 0),
    PeriodicReportType.yearly => DateTime(start.year, 12, 31),
  };
  final expectedDays = end.difference(start).inDays + 1;
  final facts = PeriodicReportFacts(
    reportType: type,
    periodId: switch (type) {
      PeriodicReportType.weekly => 'weekly:$startDate',
      PeriodicReportType.monthly => 'monthly:${startDate.substring(0, 7)}',
      PeriodicReportType.yearly => 'yearly:${startDate.substring(0, 4)}',
    },
    startDate: startDate,
    endDate: end.toIso8601String().substring(0, 10),
    expectedDailyCount: expectedDays,
    availableDailyCount: 2,
    missingDailyDates: const [],
    sourceMonthlyFactIds: const [],
    missingMonthlyFactIds: const [],
    metrics: {
      'weightKg': PeriodicMetricFact(
        sampleCount: 2,
        average: weightAverage,
        start: weightAverage + 0.5,
        end: weightAverage - 0.5,
        change: -1,
      ),
      'bodyFatPercent': const PeriodicMetricFact(
        sampleCount: 2,
        average: 31.98,
      ),
      'intakeCaloriesKcal': const PeriodicMetricFact(
        sampleCount: 2,
        total: 4308.57,
        average: 2154.285,
      ),
      'proteinG': const PeriodicMetricFact(
        sampleCount: 2,
        total: 240,
        average: 120,
      ),
      'fatG': const PeriodicMetricFact(sampleCount: 2, total: 120, average: 60),
      'carbsG': const PeriodicMetricFact(
        sampleCount: 2,
        total: 400,
        average: 200,
      ),
      'calorieBalanceKcal': const PeriodicMetricFact(
        sampleCount: 2,
        total: -983.39,
        average: -491.695,
      ),
      'officialSteps': const PeriodicMetricFact(
        sampleCount: 2,
        total: 17200,
        average: 8600,
      ),
      'sleepDurationMinutes': const PeriodicMetricFact(
        sampleCount: 2,
        average: 420,
      ),
      'sleepScore': const PeriodicMetricFact(sampleCount: 2, average: 82.25),
    },
    previousPeriodComparisons: const {},
    operationStatusCounts: const {'GREEN': 1, 'YELLOW': 1},
    trainingSessionCount: 2,
    trainingDays: 2,
    exercisesPerformed: const ['Squat'],
    theoreticalWeightChangeKg: -0.1277,
    actualWeightChangeKg: -1,
  );
  final initial = PeriodicReportRecord.initial(
    facts: facts,
    analysis: _analysis(),
    sourceDigest: 'a' * 64,
    responseDigest: 'b' * 64,
    exchangeId: 'periodic:$startDate:1',
    timestamp: DateTime.utc(start.year, start.month, start.day),
  );
  if (revision == 1) return initial;
  return initial.revise(
    facts: facts,
    analysis: _analysis(),
    sourceDigest: 'a' * 64,
    responseDigest: 'c' * 64,
    exchangeId: 'periodic:$startDate:2',
    timestamp: DateTime.utc(start.year, start.month, start.day, 1),
  );
}

PeriodicReportAnalysis _analysis() => const PeriodicReportAnalysis(
  body: 'BODY ANALYSIS',
  nutrition: 'NUTRITION ANALYSIS',
  calorieBalance: 'CALORIE BALANCE ANALYSIS',
  activity: 'ACTIVITY ANALYSIS',
  recovery: 'RECOVERY ANALYSIS',
  training: 'TRAINING ANALYSIS',
  condition: 'CONDITION BODY',
  operation: 'OPERATION ANALYSIS',
  overallSummary: 'OVERALL SUMMARY BODY',
  nextPeriodFocus: 'NEXT PERIOD FOCUS BODY',
);

DailyAggregateV1 _daily(
  String date, {
  required double weight,
  required int steps,
  required double calories,
}) => DailyAggregateV1(
  operationDate: date,
  weightKg: weight,
  bodyFatPercent: 32,
  sleepDurationMinutes: 420,
  sleepScore: 82,
  sleepType: null,
  plantarFasciitisLevel: null,
  workStartTime: null,
  workEndTime: null,
  workBreakMinutes: null,
  actualWorkMinutes: null,
  intakeCaloriesKcal: calories,
  estimatedExpenditureKcal: calories + 400,
  estimatedCalorieBalanceKcal: -400,
  proteinG: 120,
  fatG: 60,
  carbsG: 200,
  hydrationMl: 2000,
  officialSteps: steps,
  measuredSteps: null,
  trainingPerformed: true,
  digestiveCount: null,
  operationStatus: 'GREEN',
  sourceType: DailyAggregateSourceType.records,
);

class _Fixture {
  const _Fixture({required this.database, required this.container});

  final FakeIndexedDbDatabase database;
  final AppRepositoryContainer container;
}
