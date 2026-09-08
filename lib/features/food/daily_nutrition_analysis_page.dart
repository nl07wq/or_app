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
import 'models/daily_nutrition_target_assessment.dart';
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.8,
          children: [
            _KnownRow(
              'Calories',
              nutrition.calories,
              'kcal',
              NutritionVisualMetric.calories,
            ),
            _KnownRow(
              'Protein',
              nutrition.protein,
              'g',
              NutritionVisualMetric.protein,
            ),
            _KnownRow('Fat', nutrition.fat, 'g', NutritionVisualMetric.fat),
            _KnownRow(
              'Carbohydrate',
              nutrition.carbohydrate,
              'g',
              NutritionVisualMetric.carbohydrate,
            ),
          ],
        ),
      ],
    ),
  );
}

class _KnownRow extends StatelessWidget {
  const _KnownRow(this.label, this.value, this.unit, this.metric);
  final String label;
  final FoodNutritionValueAggregate value;
  final String unit;
  final NutritionVisualMetric metric;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: NutritionVisualColors.forMetric(metric),
          width: 3,
        ),
      ),
    ),
    padding: const EdgeInsets.only(left: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value.completeness == FoodNutritionCompleteness.unknown
              ? '—'
              : '${FoodNutritionFormatter.macro(value.knownTotal)} $unit${value.completeness == FoodNutritionCompleteness.partial ? ' +' : ''}',
        ),
      ],
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
            assessment: assessSingleNutritionTarget(
              summary!.calories,
              DynamicDailyTargetPresentation.caloriesTargetKcal(
                targets!.calories,
              )?.toDouble(),
            ),
          ),
          _ProgressRow(
            'Protein',
            summary!.protein,
            DynamicDailyTargetPresentation.proteinTargetG(
              targets!.protein,
            )?.toDouble(),
            'g',
            assessment: assessSingleNutritionTarget(
              summary!.protein,
              DynamicDailyTargetPresentation.proteinTargetG(
                targets!.protein,
              )?.toDouble(),
            ),
          ),
          _ProgressRow(
            'Fat',
            summary!.fat,
            DynamicDailyTargetPresentation.fatTargetG(targets!.fat)?.toDouble(),
            'g',
            assessment: assessRangedNutritionTarget(
              summary!.fat,
              DynamicDailyTargetPresentation.fatTargetMinG(
                targets!.fat,
              )?.toDouble(),
              DynamicDailyTargetPresentation.fatTargetMaxG(
                targets!.fat,
              )?.toDouble(),
            ),
          ),
          _ProgressRow(
            'Carbohydrate',
            summary!.carbohydrates,
            DynamicDailyTargetPresentation.carbohydrateTargetG(
              targets!.carbohydrate,
            )?.toDouble(),
            'g',
            assessment: assessSingleNutritionTarget(
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
    required this.assessment,
  });
  final String label;
  final double current;
  final double? target;
  final String unit;
  final DailyNutritionTargetAssessment assessment;
  @override
  Widget build(BuildContext context) {
    final delta = target == null ? null : current - target!;
    final deltaText = delta == null
        ? '目標なし'
        : '${delta >= 0 ? '+' : ''}${FoodNutritionFormatter.macro(delta)}$unit';
    final deltaColor = switch (assessment.status) {
      DailyNutritionTargetStatus.low => NutritionVisualColors.low,
      DailyNutritionTargetStatus.onTrack => NutritionVisualColors.onTrack,
      DailyNutritionTargetStatus.over => NutritionVisualColors.high,
      DailyNutritionTargetStatus.unavailable => Theme.of(
        context,
      ).colorScheme.outline,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 116,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  target == null
                      ? '目標なし'
                      : '${FoodNutritionFormatter.macro(current)} / ${FoodNutritionFormatter.macro(target!)} $unit',
                  textAlign: TextAlign.end,
                ),
                Text(
                  deltaText,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: deltaColor),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 68,
            child: Center(
              child: target == null
                  ? null
                  : NutritionStatusBadge(status: assessment.badgeLabel),
            ),
          ),
        ],
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
          const SectionHeader(
            icon: Icons.leaderboard_outlined,
            title: 'HIGHEST MEAL',
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
    const colors = [
      Color(0xFF6386A6),
      Color(0xFF5D9A86),
      Color(0xFF8874A6),
      Color(0xFFB18762),
      Color(0xFF5D9CAA),
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
                      _MealShareLegendRow(
                        color: colors[i],
                        label: analysisMealTypeLabel(entries[i].key),
                        calories: entries[i].value,
                        percent: _percent(entries[i].value, total),
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

class _MealShareLegendRow extends StatelessWidget {
  const _MealShareLegendRow({
    required this.color,
    required this.label,
    required this.calories,
    required this.percent,
  });

  final Color color;
  final String label;
  final double calories;
  final int percent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      SizedBox(
        width: 66,
        child: Text(
          '${FoodNutritionFormatter.macro(calories)} kcal',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      SizedBox(
        width: 28,
        child: Text(
          '$percent%',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            analysisMealTypeLabel(meal.mealType),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            calories == null
                ? '—'
                : '${FoodNutritionFormatter.macro(calories)} kcal  ${_percent(calories, dailyCalories)}% OF DAY',
          ),
          if (pfc == null || !FoodPfcBalanceCard.hasBalance(pfc))
            const Text('PFC —')
          else
            _MacroBars(pfc: pfc),
          Text(_nutritionText(meal.nutritionAggregate)),
        ],
      ),
    );
  }
}

class _MacroBars extends StatelessWidget {
  const _MacroBars({required this.pfc});
  final NutritionSnapshot pfc;
  @override
  Widget build(BuildContext context) {
    final values = [pfc.protein! * 4, pfc.fat! * 9, pfc.carbohydrate! * 4];
    final total = values.reduce((a, b) => a + b);
    return Column(
      children: [
        for (final pair in [
          (label: 'P', value: values[0], color: NutritionVisualColors.protein),
          (label: 'F', value: values[1], color: NutritionVisualColors.fat),
          (
            label: 'C',
            value: values[2],
            color: NutritionVisualColors.carbohydrate,
          ),
        ])
          Row(
            children: [
              SizedBox(width: 16, child: Text(pair.label)),
              Expanded(
                child: LinearProgressIndicator(
                  value: pair.value / total,
                  color: pair.color,
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(pair.value / total * 100).round()}%',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
      ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = metric.label == 'CARB' && constraints.maxWidth >= 330
            ? 'CARBOHYDRATE'
            : metric.label;
        return Container(
          key: ValueKey('highest-meal-${metric.label.toLowerCase()}'),
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          constraints: const BoxConstraints(minHeight: 36),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 15,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 16,
                child: Center(
                  child: _MealTypeBadge(
                    label: analysisMealTypeLabel(meal.mealType),
                  ),
                ),
              ),
              Expanded(
                flex: 13,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${FoodNutritionFormatter.macro(metric.select(meal.nutritionAggregate)!)} ${metric.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MealTypeBadge extends StatelessWidget {
  const _MealTypeBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
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
            summary!.calories,
            assessSingleNutritionTarget(
              summary!.calories,
              DynamicDailyTargetPresentation.caloriesTargetKcal(
                targets!.calories,
              )?.toDouble(),
            ),
          ),
          _AssessmentRow(
            'PROTEIN',
            summary!.protein,
            assessSingleNutritionTarget(
              summary!.protein,
              DynamicDailyTargetPresentation.proteinTargetG(
                targets!.protein,
              )?.toDouble(),
            ),
          ),
          _AssessmentRow(
            'FAT',
            summary!.fat,
            assessRangedNutritionTarget(
              summary!.fat,
              DynamicDailyTargetPresentation.fatTargetMinG(
                targets!.fat,
              )?.toDouble(),
              DynamicDailyTargetPresentation.fatTargetMaxG(
                targets!.fat,
              )?.toDouble(),
            ),
          ),
          _AssessmentRow(
            'CARBOHYDRATE',
            summary!.carbohydrates,
            assessSingleNutritionTarget(
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
  const _AssessmentRow(this.label, this.current, this.assessment);
  final String label;
  final double current;
  final DailyNutritionTargetAssessment assessment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 300;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(width: compact ? 102 : 116, child: Text(label)),
            SizedBox(
              width: compact ? 80 : 92,
              child: Center(
                child: NutritionStatusBadge(status: assessment.badgeLabel),
              ),
            ),
            Expanded(
              child: Text(
                _assessmentComment(label, current, assessment),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    },
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
  _MealMetric('CALORIE', 'kcal', _mealCalories),
  _MealMetric('PROTEIN', 'g', _mealProtein),
  _MealMetric('FAT', 'g', _mealFat),
  _MealMetric('CARB', 'g', _mealCarbohydrate),
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
String _assessmentComment(
  String label,
  double current,
  DailyNutritionTargetAssessment assessment,
) => switch (label) {
  'CALORIES' => switch (assessment.status) {
    DailyNutritionTargetStatus.low => '摂取やや少なめ',
    DailyNutritionTargetStatus.onTrack => '目標範囲内',
    DailyNutritionTargetStatus.over => '摂取やや多め',
    DailyNutritionTargetStatus.unavailable => '目標データなし',
  },
  'PROTEIN' => switch (assessment.status) {
    DailyNutritionTargetStatus.low =>
      'あと約${((assessment.lowerBound ?? current) - current).clamp(0, double.infinity).round()}g',
    DailyNutritionTargetStatus.onTrack => '目標範囲内',
    DailyNutritionTargetStatus.over => '十分に確保',
    DailyNutritionTargetStatus.unavailable => '目標データなし',
  },
  'FAT' => switch (assessment.status) {
    DailyNutritionTargetStatus.low => '脂質やや少なめ',
    DailyNutritionTargetStatus.onTrack => '目標範囲内',
    DailyNutritionTargetStatus.over => '脂質を控えめに',
    DailyNutritionTargetStatus.unavailable => '目標データなし',
  },
  'CARBOHYDRATE' => switch (assessment.status) {
    DailyNutritionTargetStatus.low => '炭水化物少なめ',
    DailyNutritionTargetStatus.onTrack => '目標範囲内',
    DailyNutritionTargetStatus.over => '炭水化物多め',
    DailyNutritionTargetStatus.unavailable => '目標データなし',
  },
  _ => '目標データなし',
};

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
  final fat = assessRangedNutritionTarget(
    summary.fat,
    DynamicDailyTargetPresentation.fatTargetMinG(targets.fat)?.toDouble(),
    DynamicDailyTargetPresentation.fatTargetMaxG(targets.fat)?.toDouble(),
  );
  final protein = assessSingleNutritionTarget(
    summary.protein,
    DynamicDailyTargetPresentation.proteinTargetG(targets.protein)?.toDouble(),
  );
  final calories = assessSingleNutritionTarget(
    summary.calories,
    DynamicDailyTargetPresentation.caloriesTargetKcal(
      targets.calories,
    )?.toDouble(),
  );
  final carbohydrate = assessSingleNutritionTarget(
    summary.carbohydrates,
    DynamicDailyTargetPresentation.carbohydrateTargetG(
      targets.carbohydrate,
    )?.toDouble(),
  );
  final historical = date != DateTime.now().toIso8601String().substring(0, 10);
  if (fat.status == DailyNutritionTargetStatus.over) {
    return historical ? 'この日は脂質が高めでした。' : '脂質は十分なため、残りは低脂質を優先。';
  }
  if (protein.status == DailyNutritionTargetStatus.low) {
    return historical
        ? 'この日はタンパク質が目標未達でした。'
        : 'タンパク質をあと${((protein.lowerBound ?? summary.protein) - summary.protein).clamp(0, double.infinity).round()}g程度確保。';
  }
  if (calories.status == DailyNutritionTargetStatus.over) {
    return historical ? 'この日は総摂取量がやや多めでした。' : '総摂取量はやや多めです。';
  }
  if (carbohydrate.status == DailyNutritionTargetStatus.over) {
    return historical ? 'この日は炭水化物が多めでした。' : '炭水化物はやや控えめに。';
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
