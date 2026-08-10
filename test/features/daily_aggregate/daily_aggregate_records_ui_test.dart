import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/body_history/services/body_history_source_resolver.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/pages/daily_aggregate_records_page.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:or_app/features/nutrition_history/services/nutrition_history_source_resolver.dart';
import 'package:or_app/features/status/repositories/status_repository.dart';

void main() {
  testWidgets('lists records newest first and opens detail without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _AggregateRepository([
      _aggregate('2026-08-08', DailyAggregateSourceType.legacyDns),
      _aggregate('2026-08-10', DailyAggregateSourceType.records),
    ]);

    for (final width in [390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 5000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text('DAILY AGGREGATE RECORDS'), findsWidgets);
      expect(find.text('Source Type  records'), findsOneWidget);
      expect(find.text('Source Type  legacyDns'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('2026-08-10')).dy,
        lessThan(tester.getTopLeft(find.text('2026-08-08')).dy),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('detail covers formal fields and preserves null zero and false', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _AggregateRepository([
      _aggregate('2026-08-10', DailyAggregateSourceType.records),
    ]);
    for (final width in [390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 7000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: DailyAggregateDetailPage(
            operationDate: '2026-08-10',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final section in const [
        'BODY',
        'RECOVERY',
        'CONDITION',
        'WORK',
        'NUTRITION',
        'HYDRATION',
        'ACTIVITY',
        'DIGESTIVE',
        'OPERATION',
        'SOURCE',
      ]) {
        expect(find.text(section), findsOneWidget);
      }
      for (final label in const [
        'Weight Kg',
        'Body Fat Percent',
        'Sleep Duration Minutes',
        'Sleep Score',
        'Sleep Type',
        'Plantar Fasciitis Level',
        'Work Start Time',
        'Work End Time',
        'Work Break Minutes',
        'Actual Work Minutes',
        'Intake Calories Kcal',
        'Estimated Expenditure Kcal',
        'Estimated Calorie Balance Kcal',
        'Protein G',
        'Fat G',
        'Carbs G',
        'Hydration Ml',
        'Official Steps',
        'Measured Steps',
        'Training Performed',
        'Digestive Count',
        'Condition Fact Summary',
        'Operation Status',
        'Operation Date',
        'Source Type',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('—'), findsWidgets);
      expect(find.text('0'), findsWidgets);
      expect(find.text('false'), findsOneWidget);
      expect(find.text('Digestive Events'), findsOneWidget);
      expect(find.text('Event 1'), findsOneWidget);
      expect(find.textContaining('夕食は帰宅後就寝により欠食'), findsOneWidget);
      expect(find.text('CORRECT RECORD'), findsNothing);
      expect(find.text('CORRECTION HISTORY'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('deletes only the selected aggregate and refreshes the list', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _AggregateRepository([
      _aggregate('2026-08-08', DailyAggregateSourceType.legacyDns),
      _aggregate('2026-08-10', DailyAggregateSourceType.records),
    ]);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2026-08-10'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('DELETE DAILY AGGREGATE'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('DELETE DAILY AGGREGATE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Source Recordは削除しません'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'CANCEL'));
    await tester.pumpAndSettle();
    expect(repository.deletedDates, isEmpty);

    await tester.tap(find.text('DELETE DAILY AGGREGATE'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'DELETE'));
    await tester.pumpAndSettle();
    expect(repository.deletedDates, ['2026-08-10']);
    expect(find.text('2026-08-10'), findsNothing);
    expect(find.text('2026-08-08'), findsOneWidget);

    await tester.tap(find.text('2026-08-08'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('DELETE DAILY AGGREGATE'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('DELETE DAILY AGGREGATE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Historical DNS'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'DELETE'));
    await tester.pumpAndSettle();
    expect(repository.deletedDates, ['2026-08-10', '2026-08-08']);
    expect(repository.sourceRecords, [
      'STATUS',
      'FOOD',
      'ACTIVITY',
      'TRAINING',
    ]);
    expect(find.text('保存済みRecordはありません。'), findsOneWidget);
  });

  test('History resolvers read current aggregate store after delete', () async {
    final repository = _AggregateRepository([
      _aggregate('2026-08-10', DailyAggregateSourceType.legacyDns),
    ]);
    final body = BodyHistorySourceResolver(
      statusRepository: const _StatusRepository(),
      dailyAggregateRepository: repository,
    );
    final nutrition = NutritionHistorySourceResolver(
      dailyAggregateRepository: repository,
    );
    expect(
      await body.resolve(startDate: '2026-08-10', endDate: '2026-08-10'),
      hasLength(1),
    );
    expect(
      await nutrition.resolve(startDate: '2026-08-10', endDate: '2026-08-10'),
      hasLength(1),
    );

    await repository.deleteByDate('2026-08-10');

    expect(
      await body.resolve(startDate: '2026-08-10', endDate: '2026-08-10'),
      isEmpty,
    );
    expect(
      await nutrition.resolve(startDate: '2026-08-10', endDate: '2026-08-10'),
      isEmpty,
    );
  });
}

Widget _app(_AggregateRepository repository) => MaterialApp(
  home: DailyAggregateRecordsPage(repository: repository),
  routes: {
    AppRoutes.dailyAggregateDetail: (context) => DailyAggregateDetailPage(
      operationDate: ModalRoute.of(context)!.settings.arguments! as String,
      repository: repository,
    ),
  },
);

class _AggregateRepository implements DailyAggregateRepository {
  final Map<String, DailyAggregateV1> _records;
  final List<String> deletedDates = [];
  final List<String> sourceRecords = ['STATUS', 'FOOD', 'ACTIVITY', 'TRAINING'];

  _AggregateRepository(Iterable<DailyAggregateV1> records)
    : _records = {for (final record in records) record.operationDate: record};

  @override
  Future<DailyAggregateV1?> getByDate(String operationDate) async =>
      _records[operationDate];

  @override
  Future<List<DailyAggregateV1>> getRange(
    String startDate,
    String endDate,
  ) async => [
    for (final record in _records.values)
      if (record.operationDate.compareTo(startDate) >= 0 &&
          record.operationDate.compareTo(endDate) <= 0)
        record,
  ];

  @override
  Future<void> deleteByDate(String operationDate) async {
    _records.remove(operationDate);
    deletedDates.add(operationDate);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StatusRepository implements StatusRepository {
  const _StatusRepository();

  @override
  Future<StatusReadResult> getRange(String startDate, String endDate) async =>
      StatusReadResult(records: const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DailyAggregateV1 _aggregate(
  String operationDate,
  DailyAggregateSourceType sourceType,
) => DailyAggregateV1(
  operationDate: operationDate,
  weightKg: null,
  bodyFatPercent: 31.2,
  sleepDurationMinutes: 0,
  sleepScore: null,
  sleepType: SleepType.nap,
  plantarFasciitisLevel: 0,
  workStartTime: null,
  workEndTime: '18:00',
  workBreakMinutes: 0,
  actualWorkMinutes: 420,
  intakeCaloriesKcal: 1479,
  estimatedExpenditureKcal: 2200,
  estimatedCalorieBalanceKcal: -721,
  proteinG: 99.3,
  fatG: 57.9,
  carbsG: 149.1,
  hydrationMl: 0,
  officialSteps: 0,
  measuredSteps: null,
  trainingPerformed: false,
  digestiveCount: 1,
  digestiveEvents: const [
    DailyAggregateDigestiveEventV1(amount: 0, shape: null, relief: null),
  ],
  operationStatus: null,
  conditionFactSummary: const ['夕食は帰宅後就寝により欠食'],
  sourceType: sourceType,
);
