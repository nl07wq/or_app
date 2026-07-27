import 'package:flutter/material.dart';

import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../../morning/models/morning_fact.dart';

class DailyReviewBody extends StatelessWidget {
  const DailyReviewBody({
    super.key,
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
    required this.estimatedTotalBurnKcal,
  });

  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary? activity;
  final TrainingSummary? training;
  final double? estimatedTotalBurnKcal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusReviewSection(morning: morning),
        const _ReviewDivider(),
        _FoodReviewSection(food: food),
        const _ReviewDivider(),
        _WaterReviewSection(food: food),
        const _ReviewDivider(),
        _EnergyReviewSection(
          food: food,
          estimatedTotalBurnKcal: estimatedTotalBurnKcal,
        ),
        const _ReviewDivider(),
        _TrainingReviewSection(training: training),
        const _ReviewDivider(),
        _ActivityReviewSection(activity: activity),
      ],
    );
  }
}

class _StatusReviewSection extends StatelessWidget {
  const _StatusReviewSection({required this.morning});

  final MorningFact? morning;

  @override
  Widget build(BuildContext context) {
    return _ReviewSection(
      icon: Icons.monitor_heart_outlined,
      title: 'STATUS',
      child: morning == null
          ? const Text('Not recorded')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResponsiveReviewRow(
                  key: const ValueKey('status-weight-body-fat-row'),
                  children: [
                    Text('Weight ${morning!.weight.toStringAsFixed(1)} kg'),
                    Text(
                      'Body Fat '
                      '${morning!.bodyFat == null ? 'Not recorded' : '${morning!.bodyFat!.toStringAsFixed(1)}%'}',
                    ),
                  ],
                ),
                AppSpacing.gapXS,
                _ResponsiveReviewRow(
                  key: const ValueKey('status-sleep-score-row'),
                  children: [
                    Text('Sleep ${_formatSleep(morning!.sleepDuration)}'),
                    Text('Sleep Score ${morning!.sleepScore}'),
                  ],
                ),
                AppSpacing.gapXS,
                _ResponsiveReviewRow(
                  key: const ValueKey('status-foot-pain-row'),
                  children: [Text('Foot Pain ${morning!.footPain}')],
                ),
                AppSpacing.gapXS,
                _ResponsiveReviewRow(
                  key: const ValueKey('status-work-memo-row'),
                  children: [
                    Text(
                      'Work Time ${morning!.workHours.toStringAsFixed(1)} h',
                    ),
                    Text(
                      'Memo ${morning!.freeNotes?.trim().isNotEmpty == true ? morning!.freeNotes!.trim() : '—'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _FoodReviewSection extends StatelessWidget {
  const _FoodReviewSection({required this.food});

  final FoodSummary? food;

  @override
  Widget build(BuildContext context) {
    final hasMeal = (food?.mealCount ?? 0) > 0;
    return _ReviewSection(
      icon: Icons.restaurant_outlined,
      title: 'FOOD',
      child: hasMeal
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResponsiveReviewRow(
                  key: const ValueKey('food-meals-calories-row'),
                  children: [
                    Text(
                      '${food!.mealCount} ${food!.mealCount == 1 ? 'Meal' : 'Meals'}',
                    ),
                    Text('${_formatWhole(food!.calories)} kcal'),
                  ],
                ),
                AppSpacing.gapXS,
                _ResponsiveReviewRow(
                  key: const ValueKey('food-macros-row'),
                  children: [
                    Text('P ${food!.protein.toStringAsFixed(1)} g'),
                    Text('F ${food!.fat.toStringAsFixed(1)} g'),
                    Text('C ${food!.carbohydrates.toStringAsFixed(1)} g'),
                  ],
                ),
              ],
            )
          : const Text('Not recorded'),
    );
  }
}

class _WaterReviewSection extends StatelessWidget {
  const _WaterReviewSection({required this.food});

  final FoodSummary? food;

  @override
  Widget build(BuildContext context) {
    return _ReviewSection(
      icon: Icons.water_drop_outlined,
      title: 'WATER',
      child: Text(
        food == null ? '未記録' : '${_formatWhole(food!.hydrationMl)} / 3,500 ml',
      ),
    );
  }
}

class _EnergyReviewSection extends StatelessWidget {
  const _EnergyReviewSection({
    required this.food,
    required this.estimatedTotalBurnKcal,
  });

  final FoodSummary? food;
  final double? estimatedTotalBurnKcal;

  @override
  Widget build(BuildContext context) {
    final balance = food == null || estimatedTotalBurnKcal == null
        ? null
        : food!.calories - estimatedTotalBurnKcal!;
    final balanceText = balance == null
        ? '—'
        : '${_formatSignedWhole(balance)} kcal';
    return _ReviewSection(
      icon: Icons.local_fire_department_outlined,
      title: 'ENERGY',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            estimatedTotalBurnKcal == null
                ? 'Est. Total Burn —'
                : 'Est. Total Burn ${_formatWhole(estimatedTotalBurnKcal!)} kcal',
          ),
          Text.rich(
            key: const ValueKey('calorie-balance'),
            TextSpan(
              children: [
                const TextSpan(text: 'Calorie Balance '),
                TextSpan(
                  text: balanceText,
                  style: TextStyle(
                    color: _calorieBalanceColor(context, balance),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingReviewSection extends StatelessWidget {
  const _TrainingReviewSection({required this.training});

  final TrainingSummary? training;

  @override
  Widget build(BuildContext context) {
    return _ReviewSection(
      icon: Icons.fitness_center_outlined,
      title: 'TRAINING',
      child: training == null
          ? const Text('Not recorded')
          : Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  '${training!.exerciseCount} '
                  '${training!.exerciseCount == 1 ? 'Exercise' : 'Exercises'}',
                ),
                Text(
                  '${training!.setCount} '
                  '${training!.setCount == 1 ? 'Set' : 'Sets'}',
                ),
              ],
            ),
    );
  }
}

class _ActivityReviewSection extends StatelessWidget {
  const _ActivityReviewSection({required this.activity});

  final ActivitySummary? activity;

  @override
  Widget build(BuildContext context) {
    if (activity == null || !activity!.isRecorded) {
      return const _ReviewSection(
        icon: Icons.directions_walk_outlined,
        title: 'ACTIVITY',
        child: Text('Not recorded'),
      );
    }

    final netCarryOver = activity!.calculationBasis?.netCarryOver;
    final carryOver = netCarryOver == null || netCarryOver == 0
        ? '—'
        : '${netCarryOver > 0 ? '+' : ''}${_formatSteps(netCarryOver)}';
    final bowel = activity!.bowelMovement;
    final digestive = activity!.digestiveSummary;

    return _ReviewSection(
      icon: Icons.directions_walk_outlined,
      title: 'ACTIVITY',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text('Steps ${_formatSteps(activity!.officialSteps)}'),
          Text('Today ${_formatSteps(activity!.measuredSteps)}'),
          Text('Carry Over $carryOver'),
          if (digestive != null && digestive.eventCount == 0)
            Semantics(label: '排便記録なし', child: const Text('No record'))
          else if (digestive != null) ...[
            _SemanticSummaryValue(
              label: 'Digestive Count',
              value: digestive.eventCount.toString(),
            ),
            _SemanticSummaryValue(
              label: 'Total Amount',
              value: digestive.totalAmount.toString(),
            ),
            _SemanticSummaryValue(
              label: 'Latest Shape',
              value: _formatBowelShape(digestive.latestShape),
            ),
            _SemanticSummaryValue(
              label: 'Latest Relief',
              value: _formatRelief(digestive.latestRelief),
            ),
          ] else ...[
            Text('Bowel Shape ${_formatBowelShape(bowel.shape)}'),
            Text('Bowel Amount ${_formatBowelAmount(bowel.amount)}'),
          ],
        ],
      ),
    );
  }
}

class _SemanticSummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SemanticSummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      label: label,
      value: value,
      child: Text('$label $value'),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title review',
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: icon, title: title),
          AppSpacing.gapSM,
          child,
        ],
      ),
    );
  }
}

class _ReviewDivider extends StatelessWidget {
  const _ReviewDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ResponsiveReviewRow extends StatelessWidget {
  const _ResponsiveReviewRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          for (final child in children)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: child,
            ),
        ],
      ),
    );
  }
}

Color? _calorieBalanceColor(BuildContext context, double? balance) {
  if (balance == null || (balance >= -150 && balance <= 150)) {
    return null;
  }
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (balance >= 151) {
    return isDark ? Colors.amberAccent : Colors.amber.shade800;
  }
  return isDark ? Colors.cyanAccent : Colors.cyan.shade700;
}

String _formatSleep(Duration duration) {
  final minutes = duration.inMinutes.remainder(60);
  return '${duration.inHours}h ${minutes.toString().padLeft(2, '0')}m';
}

String _formatSteps(int steps) => steps.toString().replaceAllMapped(
  RegExp(r'(?<!^)(?=(\d{3})+$)'),
  (_) => ',',
);

String _formatWhole(double value) => _formatSteps(value.round());

String _formatSignedWhole(double value) {
  final rounded = value.round();
  final sign = rounded > 0
      ? '+'
      : rounded < 0
      ? '-'
      : '';
  return '$sign${_formatSteps(rounded.abs())}';
}

String _formatBowelShape(int? value) => switch (value) {
  1 => '硬便',
  2 => '普通便',
  3 => '軟便',
  _ => '—',
};

String _formatBowelAmount(int? value) => switch (value) {
  1 => '少量',
  2 => '普通',
  3 => '多量',
  _ => '—',
};

String _formatRelief(int? value) => switch (value) {
  0 => '残便感',
  1 => '普通',
  2 => 'スッキリ',
  _ => '—',
};
