import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/theme/history_metric_color_registry.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:or_app/features/nutrition_history/models/nutrition_history_models.dart';
import 'package:or_app/features/nutrition_history/pages/nutrition_history_page.dart';
import 'package:or_app/features/nutrition_history/services/nutrition_history_chart_engine.dart';
import 'package:or_app/features/nutrition_history/services/nutrition_history_source_resolver.dart';

void main() {
  const engine = NutritionHistoryChartEngine();

  testWidgets('hotfix: nutrition summary shows only distribution values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final resolver = NutritionHistorySourceResolver(
      dailyAggregateRepository: _AggregateRepository([
        _aggregate('2026-08-08', intake: 1500),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionHistoryPage(
          resolver: resolver,
          clock: () => DateTime(2026, 8, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('MIN'), findsOneWidget);
    expect(find.text('AVERAGE'), findsOneWidget);
    expect(find.text('RECORDS'), findsOneWidget);
    expect(find.text('START'), findsNothing);
    expect(find.text('LATEST'), findsNothing);
    expect(find.text('CHANGE'), findsNothing);
  });

  test('hotfix: average excludes null and preserves numeric zero', () {
    const source = [
      NutritionHistoryDataPoint(
        operationDate: '2026-08-01',
        intakeCaloriesKcal: 0,
        estimatedExpenditureKcal: null,
        estimatedCalorieBalanceKcal: null,
      ),
      NutritionHistoryDataPoint(
        operationDate: '2026-08-02',
        intakeCaloriesKcal: null,
        estimatedExpenditureKcal: null,
        estimatedCalorieBalanceKcal: null,
      ),
      NutritionHistoryDataPoint(
        operationDate: '2026-08-03',
        intakeCaloriesKcal: 30,
        estimatedExpenditureKcal: null,
        estimatedCalorieBalanceKcal: null,
      ),
    ];

    final summary = _build(
      engine,
      source,
      NutritionHistoryMetric.intakeCalories,
    ).summary!;

    expect(summary.maximum, 30);
    expect(summary.minimum, 0);
    expect(summary.average, 15);
    expect(summary.measurementCount, 2);
  });

  test('hotfix: history metrics have fixed color mappings', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    Color resolve(HistoryMetricColorKey key) =>
        HistoryMetricColorRegistry.resolveFor(
          key: key,
          colorScheme: scheme,
          brightness: Brightness.light,
        );

    expect(resolve(HistoryMetricColorKey.weight), scheme.primary);
    expect(resolve(HistoryMetricColorKey.bodyFat), Colors.purple.shade600);
    expect(
      resolve(HistoryMetricColorKey.intakeCalories),
      Colors.orange.shade700,
    );
    expect(
      resolve(HistoryMetricColorKey.estimatedExpenditure),
      Colors.cyan.shade700,
    );
    expect(resolve(HistoryMetricColorKey.calorieBalance), Colors.teal.shade600);
  });

  test('maps calories and PFC from the existing Daily Aggregate', () async {
    final resolver = NutritionHistorySourceResolver(
      dailyAggregateRepository: _AggregateRepository([
        _aggregate(
          '2026-08-08',
          intake: 1479,
          expenditure: 2650,
          balance: -1150,
          protein: 120,
          fat: 55,
          carbs: 210,
        ),
      ]),
    );

    final point = (await resolver.resolve(
      startDate: '2026-08-01',
      endDate: '2026-08-08',
    )).single;

    expect(point.intakeCaloriesKcal, 1479);
    expect(point.estimatedExpenditureKcal, 2650);
    expect(point.estimatedCalorieBalanceKcal, -1150);
    expect(point.proteinG, 120);
    expect(point.fatG, 55);
    expect(point.carbohydrateG, 210);
  });

  test('missing metrics do not create points in other charts', () {
    const source = [
      NutritionHistoryDataPoint(
        operationDate: '2026-08-08',
        intakeCaloriesKcal: 1800,
        estimatedExpenditureKcal: null,
        estimatedCalorieBalanceKcal: null,
      ),
    ];

    expect(
      _build(engine, source, NutritionHistoryMetric.intakeCalories).points,
      hasLength(1),
    );
    expect(
      _build(
        engine,
        source,
        NutritionHistoryMetric.estimatedExpenditure,
      ).points,
      isEmpty,
    );
    expect(
      _build(engine, source, NutritionHistoryMetric.calorieBalance).points,
      isEmpty,
    );
  });

  test('one-year search uses each metric valid data range as viewport', () {
    final source = [
      for (var day = 1; day <= 8; day++)
        _point(
          '2026-08-${day.toString().padLeft(2, '0')}',
          intake: 1400.0 + day,
        ),
    ];

    final model = engine.build(
      source: source,
      metric: NutritionHistoryMetric.intakeCalories,
      period: BodyHistoryPeriod.oneYear,
      startDate: '2025-08-10',
      endDate: '2026-08-10',
      availablePlotWidth: 268,
    );

    expect(model.startDate, '2026-08-01');
    expect(model.endDate, '2026-08-08');
    expect(model.points, hasLength(8));
  });

  test('long ranges preserve every non-null metric point', () {
    final weeklySource = [
      for (var index = 0; index < 160; index++)
        _point(
          _format(DateTime.utc(2026, 1, 5).add(Duration(days: index))),
          intake: index == 2 ? null : (index == 0 ? 1000 : 2000),
        ),
    ];
    final weekly = engine.build(
      source: weeklySource,
      metric: NutritionHistoryMetric.intakeCalories,
      period: BodyHistoryPeriod.oneYear,
      startDate: '2026-01-05',
      endDate: '2026-06-13',
      availablePlotWidth: 268,
    );
    final monthlySource = [
      for (var index = 0; index < 1100; index++)
        _point(
          _format(DateTime.utc(2023, 1, 1).add(Duration(days: index))),
          expenditure: index == 1 ? null : (index == 0 ? 2000 : 3000),
        ),
    ];
    final monthly = engine.build(
      source: monthlySource,
      metric: NutritionHistoryMetric.estimatedExpenditure,
      period: BodyHistoryPeriod.allTime,
      startDate: '2023-01-01',
      endDate: '2026-01-04',
      availablePlotWidth: 268,
    );

    expect(weekly.granularity, BodyHistoryGranularity.daily);
    expect(weekly.points, hasLength(159));
    expect(weekly.points.every((point) => point.measurementCount == 1), isTrue);
    expect(monthly.granularity, BodyHistoryGranularity.daily);
    expect(monthly.points, hasLength(1099));
    expect(
      monthly.points.every((point) => point.measurementCount == 1),
      isTrue,
    );
  });

  test('calorie balance preserves negatives and exposes a zero line', () {
    const source = [
      NutritionHistoryDataPoint(
        operationDate: '2026-08-01',
        intakeCaloriesKcal: null,
        estimatedExpenditureKcal: null,
        estimatedCalorieBalanceKcal: -1150,
      ),
      NutritionHistoryDataPoint(
        operationDate: '2026-08-08',
        intakeCaloriesKcal: null,
        estimatedExpenditureKcal: null,
        estimatedCalorieBalanceKcal: -700,
      ),
    ];

    final model = _build(engine, source, NutritionHistoryMetric.calorieBalance);

    expect(model.points.map((point) => point.value), [-1150, -700]);
    expect(model.summary?.average, -925);
    expect(model.showZeroLine, isTrue);
    expect(model.axis!.minimum, lessThan(0));
    expect(model.axis!.maximum, greaterThan(0));
  });
}

NutritionHistoryChartModel _build(
  NutritionHistoryChartEngine engine,
  List<NutritionHistoryDataPoint> source,
  NutritionHistoryMetric metric,
) => engine.build(
  source: source,
  metric: metric,
  period: BodyHistoryPeriod.oneMonth,
  startDate: '2026-08-01',
  endDate: '2026-08-31',
  availablePlotWidth: 268,
);

NutritionHistoryDataPoint _point(
  String date, {
  double? intake,
  double? expenditure,
  double? balance,
  double? protein,
  double? fat,
  double? carbs,
}) => NutritionHistoryDataPoint(
  operationDate: date,
  intakeCaloriesKcal: intake,
  estimatedExpenditureKcal: expenditure,
  estimatedCalorieBalanceKcal: balance,
  proteinG: protein,
  fatG: fat,
  carbohydrateG: carbs,
);

DailyAggregateV1 _aggregate(
  String date, {
  double? intake,
  double? expenditure,
  double? balance,
  double? protein,
  double? fat,
  double? carbs,
}) => DailyAggregateV1(
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
  intakeCaloriesKcal: intake,
  estimatedExpenditureKcal: expenditure,
  estimatedCalorieBalanceKcal: balance,
  proteinG: protein,
  fatG: fat,
  carbsG: carbs,
  hydrationMl: 0,
  officialSteps: null,
  measuredSteps: null,
  trainingPerformed: false,
  digestiveCount: null,
  sourceType: DailyAggregateSourceType.records,
);

String _format(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class _AggregateRepository implements DailyAggregateRepository {
  final List<DailyAggregateV1> records;

  const _AggregateRepository(this.records);

  @override
  Future<List<DailyAggregateV1>> getRange(
    String startDate,
    String endDate,
  ) async => records;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
