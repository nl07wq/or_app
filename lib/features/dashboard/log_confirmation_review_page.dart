import 'package:flutter/material.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/training_summary.dart';
import '../../core/services/daily_log_confirmation_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../morning/models/morning_fact.dart';

class LogConfirmationReviewPage extends StatefulWidget {
  const LogConfirmationReviewPage({
    super.key,
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
    required this.estimatedTotalBurn,
  });

  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary activity;
  final TrainingSummary? training;
  final double? estimatedTotalBurn;

  @override
  State<LogConfirmationReviewPage> createState() =>
      _LogConfirmationReviewPageState();
}

class _LogConfirmationReviewPageState extends State<LogConfirmationReviewPage> {
  bool _isConfirming = false;

  Future<void> _confirmLog() async {
    if (_isConfirming) {
      return;
    }

    setState(() => _isConfirming = true);

    try {
      await DailyLogConfirmationService.confirmToday();

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on StateError {
      if (!mounted) {
        return;
      }

      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Morningデータが必要です。')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログの確定に失敗しました。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DAILY REVIEW')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusReviewSection(morning: widget.morning),
              const _ReviewDivider(),
              _FoodReviewSection(food: widget.food),
              const _ReviewDivider(),
              _WaterReviewSection(food: widget.food),
              const _ReviewDivider(),
              _EnergyReviewSection(
                estimatedTotalBurn: widget.estimatedTotalBurn,
              ),
              const _ReviewDivider(),
              _TrainingReviewSection(training: widget.training),
              const _ReviewDivider(),
              _ActivityReviewSection(activity: widget.activity),
              AppSpacing.gapLG,
              const Text(
                '確定後は本日の通常編集・削除がロックされます。\n'
                '変更する場合は訂正処理が必要です。',
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OperationButton(
                icon: Icons.verified_outlined,
                text: _isConfirming ? 'FINALIZING...' : 'FINALIZE DAY',
                onPressed: _isConfirming || widget.morning == null
                    ? null
                    : _confirmLog,
              ),
              AppSpacing.gapXS,
              const Text('本日の記録を確定', textAlign: TextAlign.center),
              TextButton(
                onPressed: _isConfirming ? null : () => Navigator.pop(context),
                child: const Text('BACK TO EDIT'),
              ),
            ],
          ),
        ),
      ),
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
          ? Text(
              'Not recorded',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth >= 560
                    ? (constraints.maxWidth - AppSpacing.md) / 2
                    : constraints.maxWidth;
                final items = [
                  'Weight ${morning!.weight.toStringAsFixed(1)} kg',
                  'Body Fat ${morning!.bodyFat == null ? 'Not recorded' : '${morning!.bodyFat!.toStringAsFixed(1)}%'}',
                  'Sleep ${_formatSleep(morning!.sleepDuration)}',
                  'Sleep Score ${morning!.sleepScore}',
                  'Foot Pain ${morning!.footPain}',
                  'Work Time ${morning!.workHours.toStringAsFixed(1)} h',
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: items
                          .map(
                            (item) =>
                                SizedBox(width: itemWidth, child: Text(item)),
                          )
                          .toList(growable: false),
                    ),
                    AppSpacing.gapXS,
                    Text(
                      'Memo ${morning!.freeNotes?.trim().isNotEmpty == true ? morning!.freeNotes!.trim() : '—'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
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
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text('${food!.mealCount} Meals'),
                Text('· ${_formatWhole(food!.calories)} kcal'),
                Text('· P ${food!.protein.toStringAsFixed(1)} g'),
                Text('· F ${food!.fat.toStringAsFixed(1)} g'),
                Text('· C ${food!.carbohydrates.toStringAsFixed(1)} g'),
              ],
            )
          : Text(
              'Not recorded',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
        food == null
            ? 'Not recorded'
            : '${_formatWhole(food!.hydrationMl)} / 3,500 ml',
      ),
    );
  }
}

class _EnergyReviewSection extends StatelessWidget {
  const _EnergyReviewSection({required this.estimatedTotalBurn});

  final double? estimatedTotalBurn;

  @override
  Widget build(BuildContext context) {
    return _ReviewSection(
      icon: Icons.local_fire_department_outlined,
      title: 'ENERGY',
      child: Text(
        estimatedTotalBurn == null
            ? 'EST. TOTAL BURN  Not available'
            : 'EST. TOTAL BURN  ${_formatWhole(estimatedTotalBurn!)} kcal',
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
          ? Text(
              'Not recorded',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Text(
              '${training!.exerciseCount} Exercises · '
              '${training!.setCount} Sets',
            ),
    );
  }
}

class _ActivityReviewSection extends StatelessWidget {
  const _ActivityReviewSection({required this.activity});

  final ActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    if (!activity.isRecorded) {
      return _ReviewSection(
        icon: Icons.directions_walk_outlined,
        title: 'ACTIVITY',
        child: Text(
          'Not recorded',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final netCarryOver = activity.calculationBasis?.netCarryOver;
    final carryOver = netCarryOver == null || netCarryOver == 0
        ? '—'
        : '${netCarryOver > 0 ? '+' : ''}${_formatSteps(netCarryOver)}';
    final bowel = activity.bowelMovement;
    final bowelShape = bowel.shape?.toString() ?? '—';
    final bowelAmount = bowel.amount?.toString() ?? '—';

    return _ReviewSection(
      icon: Icons.directions_walk_outlined,
      title: 'ACTIVITY',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text('Steps ${_formatSteps(activity.officialSteps)}'),
          Text('Today ${_formatSteps(activity.measuredSteps)}'),
          Text('Carry Over $carryOver'),
          Text('Bowel Shape $bowelShape'),
          Text('Bowel Amount $bowelAmount'),
        ],
      ),
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
