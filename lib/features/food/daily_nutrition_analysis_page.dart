import 'package:flutter/material.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../dashboard/models/dynamic_daily_target.dart';
import '../dashboard/services/dynamic_daily_target_service.dart';
import '../morning/models/morning_fact_state.dart';
import '../repositories/app_repository_container.dart';
import 'food_nutrition_formatter.dart';
import 'models/food_nutrition_aggregate.dart';
import 'models/food_summary_state.dart';
import 'models/food_unified_read_model.dart';
import 'models/nutrition_models.dart';
import 'widgets/food_pfc_balance_card.dart';
import 'widgets/nutrition_analysis_visuals.dart';

class DailyNutritionAnalysisPage extends StatefulWidget {
  const DailyNutritionAnalysisPage({
    super.key,
    required this.operationDate,
    required this.records,
  });

  final String operationDate;
  final List<FoodUnifiedReadModel> records;

  @override
  State<DailyNutritionAnalysisPage> createState() =>
      _DailyNutritionAnalysisPageState();
}

class _DailyNutritionAnalysisPageState
    extends State<DailyNutritionAnalysisPage> {
  late final Future<_DailyContext> _context = _loadContext();

  Future<_DailyContext> _loadContext() async {
    final summary = await loadFoodSummary(localDate: widget.operationDate);
    DynamicDailyTargetResult? targets;
    if (AppRepositoryRegistry.hasContainer) {
      try {
        final container = AppRepositoryRegistry.container;
        targets =
            await DynamicDailyTargetService(
              statusRepository: container.status,
              trainingRepository: container.training,
            ).load(
              operationDate: widget.operationDate,
              currentStatus: await loadMorningFact(
                localDate: widget.operationDate,
              ),
              food: summary,
              activity: const ActivitySummary.empty(),
              training: null,
            );
      } catch (_) {}
    }
    return _DailyContext(summary: summary, targets: targets);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DAILY NUTRITION ANALYSIS')),
    body: FutureBuilder<_DailyContext>(
      future: _context,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data ?? const _DailyContext();
        final nutrition = FoodMixedDaySummary.fromRecords(
          widget.records,
        ).nutrition;
        final meals = widget.records
            .where((record) => record.waterMl == null)
            .toList();
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            _DateCard(operationDate: widget.operationDate),
            AppSpacing.gapMD,
            _SummaryCard(nutrition: nutrition),
            AppSpacing.gapMD,
            _TargetProgressCard(summary: data.summary, targets: data.targets),
            AppSpacing.gapMD,
            if (_pfc(nutrition) case final pfc?)
              if (FoodPfcBalanceCard.hasBalance(pfc)) ...[
                FoodPfcBalanceCard(
                  nutrition: pfc,
                  keyPrefix: 'daily-analysis-pfc',
                ),
                AppSpacing.gapMD,
              ],
            _MealShareCard(meals: meals, nutrition: nutrition),
            AppSpacing.gapMD,
            _MealContributionCard(meals: meals),
            AppSpacing.gapMD,
            _FoodContributionCard(meals: meals),
            AppSpacing.gapMD,
            _AssessmentCard(summary: data.summary, targets: data.targets),
            AppSpacing.gapMD,
            _HintCard(
              operationDate: widget.operationDate,
              summary: data.summary,
              targets: data.targets,
            ),
          ],
        );
      },
    ),
  );
}

class _DailyContext {
  const _DailyContext({this.summary, this.targets});
  final FoodSummary? summary;
  final DynamicDailyTargetResult? targets;
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.operationDate});
  final String operationDate;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(operationDate, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        const SectionHeader(
          icon: Icons.insights_outlined,
          title: 'DAILY NUTRITION ANALYSIS',
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.nutrition});
  final FoodNutritionAggregate nutrition;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.summarize_outlined,
          title: 'DAILY SUMMARY',
        ),
        AppSpacing.gapSM,
        _KnownRow('Calories', nutrition.calories, 'kcal'),
        _KnownRow('Protein', nutrition.protein, 'g'),
        _KnownRow('Fat', nutrition.fat, 'g'),
        _KnownRow('Carbohydrate', nutrition.carbohydrate, 'g'),
      ],
    ),
  );
}

class _KnownRow extends StatelessWidget {
  const _KnownRow(this.label, this.value, this.unit);
  final String label;
  final FoodNutritionValueAggregate value;
  final String unit;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(
      value.completeness == FoodNutritionCompleteness.unknown
          ? '—'
          : '${FoodNutritionFormatter.macro(value.knownTotal)} $unit${value.completeness == FoodNutritionCompleteness.partial ? ' +' : ''}',
    ),
  );
}

class _TargetProgressCard extends StatelessWidget {
  const _TargetProgressCard({this.summary, this.targets});
  final FoodSummary? summary;
  final DynamicDailyTargetResult? targets;
  @override
  Widget build(BuildContext context) {
    if (summary == null || targets?.nutritionTargetsAvailable != true) {
      return _unavailable();
    }
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.track_changes_outlined,
            title: 'TARGET PROGRESS',
          ),
          AppSpacing.gapSM,
          _ProgressRow(
            'Calories',
            summary!.calories,
            DynamicDailyTargetPresentation.caloriesTargetKcal(
              targets!.calories,
            )?.toDouble(),
            'kcal',
          ),
          _ProgressRow(
            'Protein',
            summary!.protein,
            DynamicDailyTargetPresentation.proteinTargetG(
              targets!.protein,
            )?.toDouble(),
            'g',
          ),
          _ProgressRow(
            'Fat',
            summary!.fat,
            DynamicDailyTargetPresentation.fatTargetG(targets!.fat)?.toDouble(),
            'g',
            range: (
              DynamicDailyTargetPresentation.fatTargetMinG(targets!.fat),
              DynamicDailyTargetPresentation.fatTargetMaxG(targets!.fat),
            ),
          ),
          _ProgressRow(
            'Carbohydrate',
            summary!.carbohydrates,
            DynamicDailyTargetPresentation.carbohydrateTargetG(
              targets!.carbohydrate,
            )?.toDouble(),
            'g',
          ),
        ],
      ),
    );
  }

  Widget _unavailable() => const OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.track_changes_outlined,
          title: 'TARGET PROGRESS',
        ),
        SizedBox(height: AppSpacing.sm),
        Text('目標データなし'),
      ],
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(
    this.label,
    this.current,
    this.target,
    this.unit, {
    this.range,
  });
  final String label;
  final double current;
  final double? target;
  final String unit;
  final (int?, int?)? range;
  @override
  Widget build(BuildContext context) {
    final remaining = target == null ? null : target! - current;
    final rangeLabel = range == null || range!.$1 == null
        ? null
        : 'TARGET ${range!.$1}–${range!.$2}$unit';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: rangeLabel == null ? null : Text(rangeLabel),
      trailing: Text(
        target == null
            ? '目標なし'
            : '${FoodNutritionFormatter.macro(current)} / ${FoodNutritionFormatter.macro(target!)} $unit\n${remaining! >= 0 ? '残り ${FoodNutritionFormatter.macro(remaining)}$unit' : 'OVER +${FoodNutritionFormatter.macro(-remaining)}$unit'}',
        textAlign: TextAlign.end,
      ),
    );
  }
}

class _MealContributionCard extends StatelessWidget {
  const _MealContributionCard({required this.meals});
  final List<FoodUnifiedReadModel> meals;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.restaurant_menu,
          title: 'MEAL CONTRIBUTION',
        ),
        AppSpacing.gapSM,
        if (meals.isEmpty)
          const Text('—')
        else ...[
          for (final meal in meals)
            _MealVisualCard(
              meal: meal,
              dailyCalories: _mealCaloriesTotal(meals),
            ),
          AppSpacing.gapSM,
          for (final metric in _mealMetrics)
            _HighestMeal(metric: metric, meals: meals),
        ],
      ],
    ),
  );
}

class _MealShareCard extends StatelessWidget {
  const _MealShareCard({required this.meals, required this.nutrition});
  final List<FoodUnifiedReadModel> meals;
  final FoodNutritionAggregate nutrition;
  @override
  Widget build(BuildContext context) {
    final shares = <String, double>{};
    for (final meal in meals) {
      final kcal = _mealCalories(meal.nutritionAggregate);
      if (kcal != null && kcal > 0) {
        shares[meal.mealType] = (shares[meal.mealType] ?? 0) + kcal;
      }
    }
    final total = shares.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return const OperationCard(child: Text('MEAL SHARE\n—'));
    final entries = shares.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final colors = [
      for (var i = 0; i < entries.length; i++)
        Colors.primaries[i % Colors.primaries.length],
    ];
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.pie_chart_outline,
            title: 'MEAL SHARE',
          ),
          AppSpacing.gapSM,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NutritionDonut(
                values: entries.map((entry) => entry.value).toList(),
                colors: colors,
                centerTop: FoodNutritionFormatter.macro(total),
                centerBottom: 'DAILY kcal',
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      Text(
                        '${entries[i].key.toUpperCase()}  ${_percent(entries[i].value, total)}%  ${FoodNutritionFormatter.macro(entries[i].value)} kcal',
                        style: TextStyle(color: colors[i]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealVisualCard extends StatelessWidget {
  const _MealVisualCard({required this.meal, required this.dailyCalories});
  final FoodUnifiedReadModel meal;
  final double dailyCalories;
  @override
  Widget build(BuildContext context) {
    final calories = _mealCalories(meal.nutritionAggregate);
    final pfc = _pfc(meal.nutritionAggregate);
    return OperationCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pfc != null && FoodPfcBalanceCard.hasBalance(pfc))
            NutritionDonut(
              values: [pfc.protein! * 4, pfc.fat! * 9, pfc.carbohydrate! * 4],
              colors: const [
                foodDetailProteinColor,
                foodDetailFatColor,
                foodDetailCarbohydrateColor,
              ],
              centerTop: 'PFC',
              centerBottom: '${_percent(calories ?? 0, dailyCalories)}% OF DAY',
              size: 76,
            ),
          if (pfc != null && FoodPfcBalanceCard.hasBalance(pfc))
            const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealType.toUpperCase(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  calories == null
                      ? '—'
                      : '${FoodNutritionFormatter.macro(calories)} kcal  ${_percent(calories, dailyCalories)}% OF DAY',
                ),
                Text(_nutritionText(meal.nutritionAggregate)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _mealCaloriesTotal(Iterable<FoodUnifiedReadModel> meals) =>
    meals.fold<double>(
      0,
      (sum, meal) => sum + (_mealCalories(meal.nutritionAggregate) ?? 0),
    );
int _percent(double numerator, double denominator) =>
    denominator <= 0 ? 0 : (numerator / denominator * 100).round();

class _HighestMeal extends StatelessWidget {
  const _HighestMeal({required this.metric, required this.meals});
  final _MealMetric metric;
  final List<FoodUnifiedReadModel> meals;

  @override
  Widget build(BuildContext context) {
    final ranked =
        meals
            .where((meal) => metric.select(meal.nutritionAggregate) != null)
            .toList()
          ..sort((a, b) {
            final byValue = metric
                .select(b.nutritionAggregate)!
                .compareTo(metric.select(a.nutritionAggregate)!);
            return byValue != 0 ? byValue : a.createdAt.compareTo(b.createdAt);
          });
    if (ranked.isEmpty) return const SizedBox.shrink();
    final meal = ranked.first;
    return Text(
      '${metric.label}: ${meal.mealType.toUpperCase()} — '
      '${FoodNutritionFormatter.macro(metric.select(meal.nutritionAggregate)!)}${metric.unit}',
    );
  }
}

class _FoodContributionCard extends StatelessWidget {
  const _FoodContributionCard({required this.meals});
  final List<FoodUnifiedReadModel> meals;
  @override
  Widget build(BuildContext context) {
    final items = [
      for (final meal in meals)
        for (final item in meal.items) (item: item, mealType: meal.mealType),
    ];
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.leaderboard_outlined,
            title: 'TOP FOOD CONTRIBUTORS',
          ),
          AppSpacing.gapSM,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final metric in _metrics)
                SizedBox(
                  width: 165,
                  child: _RankedFoods(metric: metric, items: items),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankedFoods extends StatelessWidget {
  const _RankedFoods({required this.metric, required this.items});
  final _Metric metric;
  final List<({FoodUnifiedItemReadModel item, String mealType})> items;
  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    final sources = <String, String>{};
    for (final entry in items) {
      final value = metric.select(entry.item.nutrition);
      if (value != null) {
        totals[entry.item.displayName] =
            (totals[entry.item.displayName] ?? 0) + value;
        sources.putIfAbsent(entry.item.displayName, () => entry.mealType);
      }
    }
    final ranked = totals.entries.toList()
      ..sort(
        (a, b) => b.value == a.value
            ? a.key.compareTo(b.key)
            : b.value.compareTo(a.value),
      );
    final total = totals.values.fold<double>(0, (sum, value) => sum + value);
    final top = ranked.isEmpty ? null : ranked.first;
    return NutritionContributorCard(
      metric: metric.visualMetric,
      foodName: top?.key ?? '—',
      value: top?.value,
      unit: metric.unit,
      sharePercent: top == null ? null : _percent(top.value, total),
      mealType: top == null ? null : sources[top.key],
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({this.summary, this.targets});
  final FoodSummary? summary;
  final DynamicDailyTargetResult? targets;
  @override
  Widget build(BuildContext context) {
    if (summary == null || targets?.nutritionTargetsAvailable != true) {
      return const SizedBox.shrink();
    }
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.fact_check_outlined,
            title: 'DAILY ASSESSMENT',
          ),
          AppSpacing.gapSM,
          _AssessmentRow(
            'CALORIES',
            _status(
              summary!.calories,
              DynamicDailyTargetPresentation.caloriesTargetKcal(
                targets!.calories,
              )?.toDouble(),
            ),
          ),
          _AssessmentRow(
            'PROTEIN',
            _status(
              summary!.protein,
              DynamicDailyTargetPresentation.proteinTargetG(
                targets!.protein,
              )?.toDouble(),
            ),
          ),
          _AssessmentRow('FAT', _rangeStatus(summary!.fat, targets!.fat)),
          _AssessmentRow(
            'CARBOHYDRATE',
            _status(
              summary!.carbohydrates,
              DynamicDailyTargetPresentation.carbohydrateTargetG(
                targets!.carbohydrate,
              )?.toDouble(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.operationDate, this.summary, this.targets});
  final String operationDate;
  final FoodSummary? summary;
  final DynamicDailyTargetResult? targets;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.tips_and_updates_outlined,
          title: 'ADJUSTMENT / REVIEW',
        ),
        AppSpacing.gapSM,
        Text(_dailyHint(operationDate, summary, targets)),
      ],
    ),
  );
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow(this.label, this.status);
  final String label;
  final String status;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        NutritionStatusBadge(status: status),
      ],
    ),
  );
}

class _Metric {
  const _Metric(this.label, this.unit, this.select, this.visualMetric);
  final String label;
  final String unit;
  final double? Function(NutritionSnapshot) select;
  final NutritionVisualMetric visualMetric;
}

class _MealMetric {
  const _MealMetric(this.label, this.unit, this.select);
  final String label;
  final String unit;
  final double? Function(FoodNutritionAggregate) select;
}

const _mealMetrics = [
  _MealMetric('HIGHEST CALORIE MEAL', 'kcal', _mealCalories),
  _MealMetric('HIGHEST PROTEIN MEAL', 'g', _mealProtein),
  _MealMetric('HIGHEST FAT MEAL', 'g', _mealFat),
  _MealMetric('HIGHEST CARB MEAL', 'g', _mealCarbohydrate),
];

double? _known(FoodNutritionValueAggregate value) =>
    value.completeness == FoodNutritionCompleteness.unknown
    ? null
    : value.knownTotal;
double? _mealCalories(FoodNutritionAggregate value) => _known(value.calories);
double? _mealProtein(FoodNutritionAggregate value) => _known(value.protein);
double? _mealFat(FoodNutritionAggregate value) => _known(value.fat);
double? _mealCarbohydrate(FoodNutritionAggregate value) =>
    _known(value.carbohydrate);

const _metrics = [
  _Metric('TOP CALORIE', 'kcal', _calories, NutritionVisualMetric.calories),
  _Metric('TOP PROTEIN', 'g', _protein, NutritionVisualMetric.protein),
  _Metric('TOP FAT', 'g', _fat, NutritionVisualMetric.fat),
  _Metric('TOP CARB', 'g', _carb, NutritionVisualMetric.carbohydrate),
];
double? _calories(NutritionSnapshot value) => value.calories;
double? _protein(NutritionSnapshot value) => value.protein;
double? _fat(NutritionSnapshot value) => value.fat;
double? _carb(NutritionSnapshot value) => value.carbohydrate;
String _nutritionText(FoodNutritionAggregate value) =>
    '${FoodNutritionFormatter.macro(value.calories.knownTotal)} kcal / P ${FoodNutritionFormatter.macro(value.protein.knownTotal)} / F ${FoodNutritionFormatter.macro(value.fat.knownTotal)} / C ${FoodNutritionFormatter.macro(value.carbohydrate.knownTotal)}';
String _status(double current, double? target) {
  if (target == null) return '目標なし';
  const tolerance = 1.0;
  if (current > target + tolerance) return 'OVER';
  if (current < target - tolerance) return 'LOW';
  return 'ON TRACK';
}

String _rangeStatus(double current, DynamicRangeTarget target) {
  final low = target.low;
  final high = target.high;
  if (low == null || high == null) return '目標なし';
  const tolerance = 1.0;
  if (current > high + tolerance) return 'OVER';
  if (current < low - tolerance) return 'LOW';
  return 'ON TRACK';
}

String _dailyHint(
  String date,
  FoodSummary? summary,
  DynamicDailyTargetResult? targets,
) {
  if (summary == null ||
      targets == null ||
      !targets.nutritionTargetsAvailable) {
    return '目標データなし';
  }
  final fat = DynamicDailyTargetPresentation.fatTargetMaxG(targets.fat);
  final protein = DynamicDailyTargetPresentation.proteinTargetG(
    targets.protein,
  );
  final historical = date != DateTime.now().toIso8601String().substring(0, 10);
  if (fat != null && summary.fat > fat) {
    return historical ? 'この日は脂質が高めでした。' : '脂質は十分なため、残りは低脂質を優先。';
  }
  if (protein != null && summary.protein < protein) {
    return historical
        ? 'この日はタンパク質が目標未達でした。'
        : 'タンパク質をあと${FoodNutritionFormatter.macro(protein - summary.protein)}g程度確保。';
  }
  return historical ? 'この日は目標内でバランスを維持できました。' : '総摂取量は目標内。次の食事ではバランス維持を優先。';
}

NutritionSnapshot? _pfc(FoodNutritionAggregate value) {
  if (value.protein.completeness != FoodNutritionCompleteness.complete ||
      value.fat.completeness != FoodNutritionCompleteness.complete ||
      value.carbohydrate.completeness != FoodNutritionCompleteness.complete) {
    return null;
  }
  return NutritionSnapshot(
    calories: value.calories.completeness == FoodNutritionCompleteness.complete
        ? value.calories.knownTotal
        : null,
    protein: value.protein.knownTotal,
    fat: value.fat.knownTotal,
    carbohydrate: value.carbohydrate.knownTotal,
  );
}
