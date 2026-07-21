import 'package:flutter/material.dart';

import '../../core/engine/commander_snapshot.dart';
import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/operation_engine.dart';
import '../../core/engine/operation_input.dart';
import '../../core/engine/training_summary.dart';
import '../../core/models/meal_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/services/app_clock.dart';
import '../../core/services/daily_log_confirmation_state.dart';
import '../../core/services/daily_log_confirmation_service.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/models/daily_log_confirmation_status.dart';

import '../food/services/food_submit_service.dart';
import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';

import '../food/models/food_summary_state.dart';
import '../activity/models/activity_summary_state.dart';

import '../training/models/training_summary_state.dart';

import 'widgets/status_card.dart';
import 'log_confirmation_review_page.dart';
import 'package:flutter/foundation.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.debugDateOverride,
      builder: (context, _, _) {
        return ValueListenableBuilder<MorningFact?>(
          valueListenable: morningFactNotifier,
          builder: (context, morningFact, _) {
            return ValueListenableBuilder<FoodSummary?>(
              valueListenable: foodSummaryNotifier,
              builder: (context, foodSummary, _) {
                return ValueListenableBuilder<TrainingSummary?>(
                  valueListenable: trainingSummaryNotifier,
                  builder: (context, trainingSummary, _) {
                    return ValueListenableBuilder<ActivitySummary>(
                      valueListenable: activitySummaryNotifier,
                      builder: (context, activitySummary, _) {
                        final input = morningFact == null
                            ? null
                            : OperationInput(
                                morning: morningFact,
                                food: foodSummary,
                                training: trainingSummary,
                                activity: activitySummary,
                              );
                        final engine = const OperationEngine();
                        final snapshot = input == null
                            ? null
                            : engine.generateCommanderSnapshot(input);
                        final estimatedTDEE = input == null
                            ? null
                            : engine.estimateTDEE(input);

                        return Scaffold(
                          appBar: AppBar(title: const Text('ORLO DASHBOARD')),
                          body: ListView(
                            padding: AppSpacing.cardPadding,
                            children: [
                              if (kDebugMode) ...[
                                _DebugDateCard(
                                  onPreviousDay: () => _changeDebugDate(-1),
                                  onToday: _resetDebugDate,
                                  onNextDay: () => _changeDebugDate(1),
                                ),
                                AppSpacing.gapLG,
                              ],
                              SectionHeader(
                                icon: Icons.dashboard_outlined,
                                title: 'DAILY COMMAND',
                              ),
                              AppSpacing.gapLG,
                              SectionHeader(
                                icon: Icons.flag_outlined,
                                title: 'COMMANDER INTENT',
                              ),
                              AppSpacing.gapSM,
                              _CommanderIntentCard(snapshot: snapshot),
                              AppSpacing.gapXL,
                              StatusCard(
                                isReady: morningFact != null,
                                status: snapshot?.status,
                              ),
                              AppSpacing.gapXL,
                              SectionHeader(
                                icon: Icons.wb_sunny_outlined,
                                title: 'MORNING BRIEF SUMMARY',
                              ),
                              AppSpacing.gapSM,
                              _InfoCard(
                                icon: Icons.lightbulb_outline,
                                title: 'BRIEFING',
                                message: snapshot?.summary ?? '--',
                              ),
                              AppSpacing.gapXL,
                              SectionHeader(
                                icon: Icons.timeline_outlined,
                                title: 'OPERATION PROGRESS',
                              ),
                              AppSpacing.gapSM,
                              _ProgressCard(
                                morningFact: morningFact,
                                estimatedTDEE: estimatedTDEE,
                                foodSummary: foodSummary,
                                trainingSummary: trainingSummary,
                                activitySummary: activitySummary,
                                onWaterTap: () => _showQuickWaterInput(context),
                              ),
                              AppSpacing.gapXL,
                              SectionHeader(
                                icon: Icons.fact_check_outlined,
                                title: 'LOG CONFIRMATION',
                              ),
                              AppSpacing.gapSM,
                              ValueListenableBuilder<
                                DailyLogConfirmationStatus
                              >(
                                valueListenable: dailyLogConfirmationNotifier,
                                builder: (context, confirmationStatus, _) {
                                  if (confirmationStatus.isConfirmed) {
                                    return _ConfirmedLogConfirmationCard(
                                      confirmedAt:
                                          confirmationStatus.confirmedAt!,
                                      date: confirmationStatus.date,
                                    );
                                  }

                                  return _UnconfirmedLogConfirmationCard(
                                    morningFact: morningFact,
                                    foodSummary: foodSummary,
                                    activitySummary: activitySummary,
                                    trainingSummary: trainingSummary,
                                  );
                                },
                              ),
                              AppSpacing.gapXL,
                              SectionHeader(
                                icon: Icons.bolt_outlined,
                                title: 'QUICK ACCESS',
                              ),
                              AppSpacing.gapSM,
                              _MorningButton(),
                              AppSpacing.gapMD,
                              _FoodButton(),
                              AppSpacing.gapMD,
                              _TrainingButton(),
                              AppSpacing.gapMD,
                              _ActivityButton(),
                              AppSpacing.gapMD,
                              _CommandCenterButton(),
                              AppSpacing.gapMD,
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _changeDebugDate(int dayOffset) async {
    final current = AppClock.today();
    AppClock.setDebugDate(
      DateTime(current.year, current.month, current.day + dayOffset),
    );
    await refreshActivitySummary();
  }

  Future<void> _resetDebugDate() async {
    AppClock.clearDebugDateOverride();
    await refreshActivitySummary();
  }

  void _showQuickWaterInput(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickWaterSheet(dashboardContext: context),
    );
  }

  String _formatSteps(int steps) => steps.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );
}

class _DebugDateCard extends StatelessWidget {
  final VoidCallback onPreviousDay;
  final VoidCallback onToday;
  final VoidCallback onNextDay;

  const _DebugDateCard({
    required this.onPreviousDay,
    required this.onToday,
    required this.onNextDay,
  });

  @override
  Widget build(BuildContext context) {
    final date = AppClock.today();
    final dateText =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppClock.hasDebugDateOverride
                ? 'DEBUG DATE OVERRIDE'
                : 'DEBUG DATE',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          AppSpacing.gapSM,
          Text(dateText),
          AppSpacing.gapMD,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPreviousDay,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous day'),
              ),
              OutlinedButton.icon(
                onPressed: onToday,
                icon: const Icon(Icons.today),
                label: const Text('Today'),
              ),
              OutlinedButton.icon(
                onPressed: onNextDay,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next day'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmedLogConfirmationCard extends StatelessWidget {
  const _ConfirmedLogConfirmationCard({
    required this.confirmedAt,
    required this.date,
  });

  final DateTime confirmedAt;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final localTime = confirmedAt.toLocal();
    final time =
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S LOG CONFIRMED",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          AppSpacing.gapSM,
          Text('Confirmed at $time'),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.visibility_outlined,
            text: 'View Confirmation',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.logConfirmationDetail,
              arguments: date,
            ),
          ),
          AppSpacing.gapSM,
          OperationButton(
            icon: Icons.edit_note_outlined,
            text: 'Correct Log',
            onPressed: () => _showReopenDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showReopenDialog(BuildContext context) async {
    final shouldReopen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Correct Log'),
        content: const Text(
          'この日の確定を解除して、通常の編集・削除を再開します。\n'
          '確定スナップショットは削除されますが、入力済みデータは変更されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('編集を再開'),
          ),
        ],
      ),
    );

    if (shouldReopen != true || !context.mounted) {
      return;
    }

    try {
      await DailyLogConfirmationService.reopenDate(date);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('確定状態を解除できませんでした。')));
    }
  }
}

class _UnconfirmedLogConfirmationCard extends StatelessWidget {
  const _UnconfirmedLogConfirmationCard({
    required this.morningFact,
    required this.foodSummary,
    required this.activitySummary,
    required this.trainingSummary,
  });

  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final ActivitySummary activitySummary;
  final TrainingSummary? trainingSummary;

  @override
  Widget build(BuildContext context) {
    final mealCount = foodSummary?.mealCount ?? 0;

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Morning: ${morningFact == null ? 'Missing' : 'Recorded'}'),
          Text('Food: ${mealCount > 0 ? '$mealCount meals' : 'Not recorded'}'),
          Text(
            'Activity: ${activitySummary.isRecorded ? '${_formatSteps(activitySummary.steps)} steps' : 'Not recorded'}',
          ),
          Text(
            'Training: ${trainingSummary == null
                ? 'Not recorded'
                : trainingSummary!.completed
                ? 'Completed'
                : 'Not completed'}',
          ),
          if (morningFact == null) const Text('Morningデータの入力が必要です。'),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.fact_check_outlined,
            text: "Review Today's Log",
            onPressed: morningFact == null
                ? null
                : () => Navigator.pushNamed(
                    context,
                    AppRoutes.logConfirmationReview,
                    arguments: LogConfirmationReviewPage(
                      morning: morningFact,
                      food: foodSummary,
                      activity: activitySummary,
                      training: trainingSummary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatSteps(int steps) => steps.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );
}

class _CommanderIntentCard extends StatelessWidget {
  final CommanderSnapshot? snapshot;

  const _CommanderIntentCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.track_changes_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: AppSpacing.md),
              Text('最優先目標', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          AppSpacing.gapLG,
          Text(
            snapshot?.commanderIntent ?? '--',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          AppSpacing.gapSM,
          Text(snapshot?.summary ?? '--'),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                AppSpacing.gapSM,
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final MorningFact? morningFact;
  final double? estimatedTDEE;
  final FoodSummary? foodSummary;
  final TrainingSummary? trainingSummary;
  final ActivitySummary activitySummary;
  final VoidCallback onWaterTap;

  const _ProgressCard({
    required this.morningFact,
    required this.estimatedTDEE,
    required this.foodSummary,
    required this.trainingSummary,
    required this.activitySummary,
    required this.onWaterTap,
  });

  @override
  Widget build(BuildContext context) {
    final morningComplete = morningFact != null;
    final mealCount = foodSummary?.mealCount ?? 0;
    final calories = foodSummary?.calories ?? 0;
    final protein = foodSummary?.protein ?? 0;
    final hydrationMl = foodSummary?.hydrationMl ?? 0;

    return ValueListenableBuilder<double>(
      valueListenable: trainingCardioCaloriesNotifier,
      builder: (context, cardioCalories, _) {
        final estimatedTotalBurn = estimatedTDEE == null
            ? null
            : estimatedTDEE! + cardioCalories;

        return OperationCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ProgressSummaryMetric(
                      label: 'WEIGHT',
                      value: morningFact == null
                          ? '--'
                          : '${morningFact!.weight.toStringAsFixed(1)} kg',
                    ),
                  ),
                  Expanded(
                    child: _ProgressSummaryMetric(
                      label: 'SLEEP',
                      value: morningFact == null
                          ? '--'
                          : _formatSleep(morningFact!.sleepDuration),
                    ),
                  ),
                  Expanded(
                    child: _ProgressSummaryMetric(
                      label: 'BASE BURN',
                      value: estimatedTDEE == null
                          ? '--'
                          : '${estimatedTDEE!.toStringAsFixed(0)} kcal',
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMD,
              Row(
                children: [
                  Expanded(
                    child: _ProgressSummaryMetric(
                      label: 'EXERCISE\nCARDIO ONLY',
                      value: '${cardioCalories.toStringAsFixed(0)} kcal',
                    ),
                  ),
                  Expanded(
                    child: _ProgressSummaryMetric(
                      label: 'EST. TOTAL BURN',
                      value: estimatedTotalBurn == null
                          ? '--'
                          : '${estimatedTotalBurn.toStringAsFixed(0)} kcal',
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLG,
              _ProgressRow(
                label: 'MORNING ROUTINE',
                status: morningComplete ? '完了' : '未完了',
                progress: morningComplete ? 1.0 : 0.0,
              ),
              AppSpacing.gapMD,
              _ProgressRow(
                label: 'FOOD',
                status: '$mealCount / 3',
                progress: (mealCount / 3).clamp(0.0, 1.0).toDouble(),
              ),
              AppSpacing.gapMD,
              _ProgressRow(
                label: 'CALORIES',
                status: '${calories.toStringAsFixed(0)} / 2200 kcal',
                progress: (calories / 2200).clamp(0.0, 1.0).toDouble(),
              ),
              AppSpacing.gapMD,
              _ProgressRow(
                label: 'PROTEIN',
                status: '${protein.toStringAsFixed(1)} / 100 g',
                progress: (protein / 100).clamp(0.0, 1.0).toDouble(),
              ),
              AppSpacing.gapMD,
              _ProgressRow(
                label: 'WATER',
                status: '${hydrationMl.toStringAsFixed(0)} / 3500 ml',
                progress: (hydrationMl / 3500).clamp(0.0, 1.0).toDouble(),
                onTap: onWaterTap,
              ),
              AppSpacing.gapMD,
              _ProgressRow(
                label: 'ACTIVITY',
                status: activitySummary.isRecorded
                    ? '${_formatSteps(activitySummary.steps)} steps'
                    : 'Not recorded',
                progress: 0,
              ),
              AppSpacing.gapMD,
              _ProgressRow(
                label: 'TRAINING',
                status: trainingSummary?.completed == true ? '実施' : '未実施',
                progress: trainingSummary?.completed == true ? 1.0 : 0.0,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatSleep(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  String _formatSteps(int steps) => steps.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );
}

class _ProgressSummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ProgressSummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        AppSpacing.gapXS,
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String status;
  final double progress;
  final VoidCallback? onTap;

  const _ProgressRow({
    required this.label,
    required this.status,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(status),
                if (onTap != null) ...[
                  SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          ],
        ),
        AppSpacing.gapXS,
        LinearProgressIndicator(value: progress),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}

class _QuickWaterSheet extends StatefulWidget {
  final BuildContext dashboardContext;

  const _QuickWaterSheet({required this.dashboardContext});

  @override
  State<_QuickWaterSheet> createState() => _QuickWaterSheetState();
}

class _QuickWaterSheetState extends State<_QuickWaterSheet> {
  final _customAmountController = TextEditingController();
  bool _isSaving = false;
  String? _validationMessage;

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _save(int amountMl) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      await FoodSubmitService.save(
        MealData(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: DateTime.now().toIso8601String().split('T').first,
          mealType: 'Water',
          items: const [],
          memo: '',
          waterMl: amountMl.toDouble(),
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        widget.dashboardContext,
      ).showSnackBar(SnackBar(content: Text('$amountMl ml を記録しました')));
    } on ConfirmedDailyLogException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showConfirmedLogMessage(context, error);
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Water を記録できませんでした')));
    }
  }

  void _saveCustomAmount() {
    final amountMl = int.tryParse(_customAmountController.text.trim());

    if (amountMl == null || amountMl <= 0) {
      setState(() => _validationMessage = '正の整数の ml を入力してください。');
      return;
    }

    _save(amountMl);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: OperationCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'QUICK WATER LOG',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              AppSpacing.gapMD,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [250, 350, 500, 750]
                    .map(
                      (amount) => OutlinedButton(
                        onPressed: _isSaving ? null : () => _save(amount),
                        child: Text('$amount ml'),
                      ),
                    )
                    .toList(),
              ),
              AppSpacing.gapLG,
              OperationTextField(
                controller: _customAmountController,
                label: 'Custom amount (ml)',
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_validationMessage != null) {
                    setState(() => _validationMessage = null);
                  }
                },
              ),
              if (_validationMessage != null) ...[
                AppSpacing.gapXS,
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              AppSpacing.gapMD,
              OperationButton(
                icon: Icons.save_outlined,
                text: 'Save Water',
                onPressed: _isSaving ? null : _saveCustomAmount,
              ),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MorningButton extends StatelessWidget {
  const _MorningButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.play_arrow,
      text: 'Morning',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.morning);
      },
    );
  }
}

class _FoodButton extends StatelessWidget {
  const _FoodButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.restaurant,
      text: 'Food',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.food);
      },
    );
  }
}

class _ActivityButton extends StatelessWidget {
  const _ActivityButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.directions_walk_outlined,
      text: 'Activity',
      onPressed: () => Navigator.pushNamed(context, AppRoutes.activity),
    );
  }
}

class _TrainingButton extends StatelessWidget {
  const _TrainingButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.fitness_center,
      text: 'Training',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.training);
      },
    );
  }
}

class _CommandCenterButton extends StatelessWidget {
  const _CommandCenterButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.flag,
      text: 'Command Center',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.commandCenter);
      },
    );
  }
}
