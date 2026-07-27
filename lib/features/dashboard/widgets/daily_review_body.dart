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
          ? const Text('未記録')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text('体重 ${morning!.weight.toStringAsFixed(1)} kg'),
                    Text(
                      '体脂肪率 '
                      '${morning!.bodyFat == null ? '未記録' : '${morning!.bodyFat!.toStringAsFixed(1)}%'}',
                    ),
                    Text('睡眠 ${_formatSleep(morning!.sleepDuration)}'),
                    Text('睡眠スコア ${morning!.sleepScore}'),
                    Text('足の痛み ${morning!.footPain}'),
                    Text('勤務時間 ${morning!.workHours.toStringAsFixed(1)} h'),
                  ],
                ),
                AppSpacing.gapXS,
                Text(
                  'メモ ${morning!.freeNotes?.trim().isNotEmpty == true ? morning!.freeNotes!.trim() : '—'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          ? Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text('${food!.mealCount}食'),
                Text('${_formatWhole(food!.calories)} kcal'),
                Text('P ${food!.protein.toStringAsFixed(1)} g'),
                Text('F ${food!.fat.toStringAsFixed(1)} g'),
                Text('C ${food!.carbohydrates.toStringAsFixed(1)} g'),
              ],
            )
          : const Text('未記録'),
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
    return _ReviewSection(
      icon: Icons.local_fire_department_outlined,
      title: 'ENERGY',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            estimatedTotalBurnKcal == null
                ? '推定総消費 表示不可'
                : '推定総消費 ${_formatWhole(estimatedTotalBurnKcal!)} kcal',
          ),
          Text(
            balance == null
                ? 'カロリー収支 —'
                : 'カロリー収支 ${_formatSignedWhole(balance)} kcal',
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
          ? const Text('未記録')
          : Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text('${training!.exerciseCount}種目'),
                Text('${training!.setCount}セット'),
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
        child: Text('未記録'),
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
          Text('歩数 ${_formatSteps(activity!.officialSteps)}'),
          Text('実測歩数 ${_formatSteps(activity!.measuredSteps)}'),
          Text('繰越 $carryOver'),
          if (digestive != null && digestive.eventCount == 0)
            const Text('排便記録なし')
          else if (digestive != null) ...[
            _SemanticSummaryValue(
              label: '排便回数',
              value: '${digestive.eventCount}回',
            ),
            _SemanticSummaryValue(
              label: '総量',
              value: digestive.totalAmount.toString(),
            ),
            _SemanticSummaryValue(
              label: '最新形状',
              value: _formatBowelShape(digestive.latestShape),
            ),
            _SemanticSummaryValue(
              label: '最新スッキリ感',
              value: _formatRelief(digestive.latestRelief),
            ),
          ] else ...[
            Text('便形状 ${_formatBowelShape(bowel.shape)}'),
            Text('便量 ${_formatBowelAmount(bowel.amount)}'),
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
  final sign = rounded < 0 ? '-' : '';
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
  0 => '残便感あり',
  1 => '普通',
  2 => 'スッキリ',
  _ => '—',
};
