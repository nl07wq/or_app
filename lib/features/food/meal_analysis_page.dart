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
import 'models/food_unified_read_model.dart';
import 'models/nutrition_models.dart';
import 'models/food_summary_state.dart';
import 'widgets/food_pfc_balance_card.dart';

class MealAnalysisPage extends StatefulWidget {
  const MealAnalysisPage({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
  });

  final FoodUnifiedReadModel record;
  final Future<bool> Function(BuildContext context) onEdit;
  final Future<bool> Function(BuildContext context) onDelete;
  final bool canEdit;

  @override
  State<MealAnalysisPage> createState() => _MealAnalysisPageState();
}

class _MealAnalysisPageState extends State<MealAnalysisPage> {
  late final Future<_MealAnalysisContext> _context = _loadContext();

  Future<_MealAnalysisContext> _loadContext() async {
    final summary = await loadFoodSummary(localDate: widget.record.localDate);
    DynamicDailyTargetResult? targets;
    if (AppRepositoryRegistry.hasContainer) {
      try {
        final container = AppRepositoryRegistry.container;
        targets =
            await DynamicDailyTargetService(
              statusRepository: container.status,
              trainingRepository: container.training,
            ).load(
              operationDate: widget.record.localDate,
              currentStatus: await loadMorningFact(
                localDate: widget.record.localDate,
              ),
              food: summary,
              activity: const ActivitySummary.empty(),
              training: null,
            );
      } catch (_) {
        // Historical records remain analyzable even when a target cannot be
        // reconstructed from formal date-specific context.
      }
    }
    return _MealAnalysisContext(summary: summary, targets: targets);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MEAL ANALYSIS'),
      actions: [
        IconButton(
          key: const ValueKey('meal-analysis-edit'),
          tooltip: 'EDIT',
          icon: const Icon(Icons.edit_outlined),
          onPressed: !widget.canEdit
              ? null
              : () async {
                  final updated = await widget.onEdit(context);
                  if (!context.mounted) return;
                  if (updated) Navigator.pop(context, true);
                },
        ),
        IconButton(
          key: const ValueKey('meal-analysis-delete'),
          tooltip: 'DELETE',
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () async {
            final deleted = await widget.onDelete(context);
            if (!context.mounted) return;
            if (deleted) Navigator.pop(context, true);
          },
        ),
      ],
    ),
    body: FutureBuilder<_MealAnalysisContext>(
      future: _context,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data ?? const _MealAnalysisContext();
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            _Header(record: widget.record),
            AppSpacing.gapMD,
            _SummaryCard(nutrition: widget.record.nutritionAggregate),
            AppSpacing.gapMD,
            if (_pfcSnapshot(widget.record.nutritionAggregate) case final pfc?)
              if (FoodPfcBalanceCard.hasBalance(pfc)) ...[
                FoodPfcBalanceCard(
                  nutrition: pfc,
                  keyPrefix: 'meal-analysis-pfc',
                ),
                AppSpacing.gapMD,
              ],
            _DailyContextCard(summary: data.summary, targets: data.targets),
            AppSpacing.gapMD,
            _ContributionCard(items: widget.record.items),
            AppSpacing.gapMD,
            _AdjustmentHintCard(summary: data.summary, targets: data.targets),
          ],
        );
      },
    ),
  );
}

class _MealAnalysisContext {
  const _MealAnalysisContext({this.summary, this.targets});
  final FoodSummary? summary;
  final DynamicDailyTargetResult? targets;
}

class _Header extends StatelessWidget {
  const _Header({required this.record});
  final FoodUnifiedReadModel record;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(record.localDate, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        SectionHeader(
          icon: Icons.restaurant,
          title: record.mealType.toUpperCase(),
        ),
        if (record.memo != null) ...[AppSpacing.gapSM, Text(record.memo!)],
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
        const SectionHeader(icon: Icons.summarize_outlined, title: 'SUMMARY'),
        AppSpacing.gapSM,
        _NutritionRow('Calories', nutrition.calories, 'kcal'),
        _NutritionRow('Protein', nutrition.protein, 'g'),
        _NutritionRow('Fat', nutrition.fat, 'g'),
        _NutritionRow('Carbohydrate', nutrition.carbohydrate, 'g'),
      ],
    ),
  );
}

class _NutritionRow extends StatelessWidget {
  const _NutritionRow(this.label, this.value, this.unit);
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

class _DailyContextCard extends StatelessWidget {
  const _DailyContextCard({this.summary, this.targets});
  final FoodSummary? summary;
  final DynamicDailyTargetResult? targets;
  @override
  Widget build(BuildContext context) {
    final food = summary;
    final target = targets;
    if (food == null || target == null || !target.nutritionTargetsAvailable) {
      return _unavailable();
    }
    final caloriesTarget = DynamicDailyTargetPresentation.caloriesTargetKcal(
      target.calories,
    );
    final proteinTarget = DynamicDailyTargetPresentation.proteinTargetG(
      target.protein,
    );
    final fatTarget = DynamicDailyTargetPresentation.fatTargetG(target.fat);
    final carbohydrateTarget =
        DynamicDailyTargetPresentation.carbohydrateTargetG(target.carbohydrate);
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.today_outlined,
            title: 'DAILY CONTEXT',
          ),
          AppSpacing.gapSM,
          _DailyMetric(
            'Calories',
            food.calories,
            caloriesTarget?.toDouble(),
            'kcal',
          ),
          _DailyMetric('Protein', food.protein, proteinTarget?.toDouble(), 'g'),
          _DailyMetric('Fat', food.fat, fatTarget?.toDouble(), 'g'),
          _DailyMetric(
            'Carbohydrate',
            food.carbohydrates,
            carbohydrateTarget?.toDouble(),
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
        SectionHeader(icon: Icons.today_outlined, title: 'DAILY CONTEXT'),
        SizedBox(height: AppSpacing.sm),
        Text('目標データなし'),
      ],
    ),
  );
}

class _DailyMetric extends StatelessWidget {
  const _DailyMetric(this.label, this.current, this.target, this.unit);
  final String label;
  final double current;
  final double? target;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final remaining = target == null ? null : target! - current;
    final suffix = remaining == null
        ? '目標なし'
        : remaining >= 0
        ? '残り ${FoodNutritionFormatter.macro(remaining)}$unit'
        : 'OVER +${FoodNutritionFormatter.macro(-remaining)}$unit';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        '${FoodNutritionFormatter.macro(current)} / ${target == null ? '—' : FoodNutritionFormatter.macro(target!)} $unit\n$suffix',
        textAlign: TextAlign.end,
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({required this.items});
  final List<FoodUnifiedItemReadModel> items;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.leaderboard_outlined,
          title: 'FOOD CONTRIBUTION',
        ),
        AppSpacing.gapSM,
        for (final metric in _metrics)
          _ContributionMetric(metric: metric, items: items),
      ],
    ),
  );
}

class _ContributionMetric extends StatelessWidget {
  const _ContributionMetric({required this.metric, required this.items});
  final _ContributionMetricDefinition metric;
  final List<FoodUnifiedItemReadModel> items;
  @override
  Widget build(BuildContext context) {
    final ranked =
        items.where((item) => metric.select(item.nutrition) != null).toList()
          ..sort(
            (a, b) => metric
                .select(b.nutrition)!
                .compareTo(metric.select(a.nutrition)!),
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
            for (var index = 0; index < ranked.length; index++)
              Text(
                '${index + 1}. ${ranked[index].displayName} — ${FoodNutritionFormatter.macro(metric.select(ranked[index].nutrition)!)}${metric.unit}',
              ),
        ],
      ),
    );
  }
}

class _ContributionMetricDefinition {
  const _ContributionMetricDefinition(this.label, this.unit, this.select);
  final String label;
  final String unit;
  final double? Function(NutritionSnapshot) select;
}

const _metrics = [
  _ContributionMetricDefinition('CALORIE CONTRIBUTORS', 'kcal', _calories),
  _ContributionMetricDefinition('PROTEIN CONTRIBUTORS', 'g', _protein),
  _ContributionMetricDefinition('FAT CONTRIBUTORS', 'g', _fat),
  _ContributionMetricDefinition(
    'CARBOHYDRATE CONTRIBUTORS',
    'g',
    _carbohydrate,
  ),
];
double? _calories(NutritionSnapshot value) => value.calories;
double? _protein(NutritionSnapshot value) => value.protein;
double? _fat(NutritionSnapshot value) => value.fat;
double? _carbohydrate(NutritionSnapshot value) => value.carbohydrate;

class _AdjustmentHintCard extends StatelessWidget {
  const _AdjustmentHintCard({this.summary, this.targets});
  final FoodSummary? summary;
  final DynamicDailyTargetResult? targets;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          icon: Icons.tips_and_updates_outlined,
          title: 'ADJUSTMENT HINT',
        ),
        AppSpacing.gapSM,
        Text(_hint(summary, targets)),
      ],
    ),
  );
}

String _hint(FoodSummary? summary, DynamicDailyTargetResult? targets) {
  if (summary == null ||
      targets == null ||
      !targets.nutritionTargetsAvailable) {
    return '目標データなし';
  }
  final calories = DynamicDailyTargetPresentation.caloriesTargetKcal(
    targets.calories,
  );
  final protein = DynamicDailyTargetPresentation.proteinTargetG(
    targets.protein,
  );
  final fat = DynamicDailyTargetPresentation.fatTargetMaxG(targets.fat);
  final carbs = DynamicDailyTargetPresentation.carbohydrateTargetG(
    targets.carbohydrate,
  );
  if (calories != null && summary.calories > calories) return '次の食事は低カロリーを優先';
  if (fat != null && summary.fat > fat) return '次の食事は低脂質を優先';
  if (protein != null && summary.protein >= protein) return 'たんぱく質は目標に到達しています';
  if (protein != null && summary.protein < protein) {
    return '次の食事は高たんぱくを優先';
  }
  if (carbs != null && summary.carbohydrates < carbs) return '炭水化物はまだ余裕があります';
  return '次の食事も記録して、1日の推移を確認';
}

NutritionSnapshot? _pfcSnapshot(FoodNutritionAggregate value) {
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
