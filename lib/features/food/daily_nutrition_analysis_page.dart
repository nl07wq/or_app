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
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(meal.mealType.toUpperCase()),
              subtitle: Text(_nutritionText(meal.nutritionAggregate)),
            ),
          AppSpacing.gapSM,
          for (final metric in _mealMetrics)
            _HighestMeal(metric: metric, meals: meals),
        ],
      ],
    ),
  );
}

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
    final items = meals.expand((meal) => meal.items).toList();
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.leaderboard_outlined,
            title: 'TOP FOOD CONTRIBUTORS',
          ),
          AppSpacing.gapSM,
          for (final metric in _metrics)
            _RankedFoods(metric: metric, items: items),
        ],
      ),
    );
  }
}

class _RankedFoods extends StatelessWidget {
  const _RankedFoods({required this.metric, required this.items});
  final _Metric metric;
  final List<FoodUnifiedItemReadModel> items;
  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final item in items) {
      final value = metric.select(item.nutrition);
      if (value != null) {
        totals[item.displayName] = (totals[item.displayName] ?? 0) + value;
      }
    }
    final ranked = totals.entries.toList()
      ..sort(
        (a, b) => b.value == a.value
            ? a.key.compareTo(b.key)
            : b.value.compareTo(a.value),
      );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (ranked.isEmpty)
            const Text('—')
          else
            for (var index = 0; index < ranked.length && index < 3; index++)
              Text(
                '${index + 1}. ${ranked[index].key} — ${FoodNutritionFormatter.macro(ranked[index].value)}${metric.unit}',
              ),
        ],
      ),
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
          Text(
            'Calories: ${_status(summary!.calories, DynamicDailyTargetPresentation.caloriesTargetKcal(targets!.calories)?.toDouble())}',
          ),
          Text(
            'Protein: ${_status(summary!.protein, DynamicDailyTargetPresentation.proteinTargetG(targets!.protein)?.toDouble())}',
          ),
          Text('Fat: ${_rangeStatus(summary!.fat, targets!.fat)}'),
          Text(
            'Carbohydrate: ${_status(summary!.carbohydrates, DynamicDailyTargetPresentation.carbohydrateTargetG(targets!.carbohydrate)?.toDouble())}',
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

class _Metric {
  const _Metric(this.label, this.unit, this.select);
  final String label;
  final String unit;
  final double? Function(NutritionSnapshot) select;
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
  _Metric('TOP CALORIE FOODS', 'kcal', _calories),
  _Metric('TOP PROTEIN FOODS', 'g', _protein),
  _Metric('TOP FAT FOODS', 'g', _fat),
  _Metric('TOP CARB FOODS', 'g', _carb),
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
