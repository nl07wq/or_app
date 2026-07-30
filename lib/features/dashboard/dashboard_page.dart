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
import '../../core/state/app_initialization_state.dart';

import '../food/services/food_submit_service.dart';
import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';

import '../food/models/food_summary_state.dart';
import '../activity/models/activity_summary_state.dart';

import '../training/models/training_summary_state.dart';

import 'widgets/status_card.dart';
import 'widgets/daily_log_card.dart';
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
    final isReadOnly = appInitializationController.value.isReadOnly;
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
                          appBar: AppBar(title: const Text('O.R.L.O.')),
                          body: LayoutBuilder(
                            builder: (context, dashboardConstraints) {
                              final useLargeLayout =
                                  dashboardConstraints.maxWidth >= 900;
                              return ListView(
                                padding: AppSpacing.cardPadding,
                                children: [
                                  Center(
                                    child: ConstrainedBox(
                                      key: const ValueKey(
                                        'dashboard-main-content',
                                      ),
                                      constraints: const BoxConstraints(
                                        maxWidth: 1280,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (kDebugMode) ...[
                                            _DebugDateCard(
                                              onPreviousDay: () =>
                                                  _changeDebugDate(-1),
                                              onToday: _resetDebugDate,
                                              onNextDay: () =>
                                                  _changeDebugDate(1),
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
                                          _CommanderIntentCard(
                                            snapshot: snapshot,
                                          ),
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
                                            useLargeLayout: useLargeLayout,
                                            onWaterTap: isReadOnly
                                                ? null
                                                : () => _showQuickWaterInput(
                                                    context,
                                                  ),
                                          ),
                                          AppSpacing.gapXL,
                                          SectionHeader(
                                            icon: Icons.fact_check_outlined,
                                            title: 'DAILY LOG',
                                          ),
                                          AppSpacing.gapSM,
                                          ValueListenableBuilder<
                                            DailyLogConfirmationStatus
                                          >(
                                            valueListenable:
                                                dailyLogConfirmationNotifier,
                                            builder: (context, confirmationStatus, _) {
                                              if (confirmationStatus
                                                  .isConfirmed) {
                                                return _ConfirmedLogConfirmationCard(
                                                  confirmedAt:
                                                      confirmationStatus
                                                          .confirmedAt!,
                                                  date: confirmationStatus.date,
                                                  isReadOnly: isReadOnly,
                                                );
                                              }

                                              return DailyLogCard(
                                                morningFact: morningFact,
                                                foodSummary: foodSummary,
                                                activitySummary:
                                                    activitySummary,
                                                trainingSummary:
                                                    trainingSummary,
                                                onReview: isReadOnly
                                                    ? null
                                                    : () => Navigator.pushNamed(
                                                        context,
                                                        AppRoutes
                                                            .logConfirmationReview,
                                                        arguments: LogConfirmationReviewPage(
                                                          morning: morningFact,
                                                          food: foodSummary,
                                                          activity:
                                                              activitySummary,
                                                          training:
                                                              trainingSummary,
                                                          estimatedTotalBurn:
                                                              _estimatedTotalBurn(
                                                                estimatedTDEE,
                                                                trainingSummary,
                                                              ),
                                                        ),
                                                      ),
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
                                    ),
                                  ),
                                ],
                              );
                            },
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
    required this.isReadOnly,
  });

  final DateTime confirmedAt;
  final DateTime date;
  final bool isReadOnly;

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
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'DAILY LOG FINALIZED',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          AppSpacing.gapSM,
          Text('Finalized at $time'),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.article_outlined,
            text: 'VIEW DAILY LOG',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.logConfirmationDetail,
              arguments: date,
            ),
          ),
          AppSpacing.gapSM,
          OperationButton(
            icon: Icons.edit_note_outlined,
            text: 'CORRECT LOG',
            onPressed: isReadOnly ? null : () => _showReopenDialog(context),
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
  final bool useLargeLayout;
  final VoidCallback? onWaterTap;

  const _ProgressCard({
    required this.morningFact,
    required this.estimatedTDEE,
    required this.foodSummary,
    required this.trainingSummary,
    required this.activitySummary,
    required this.useLargeLayout,
    required this.onWaterTap,
  });

  @override
  Widget build(BuildContext context) {
    final morningComplete = morningFact != null;
    final mealCount = foodSummary?.mealCount ?? 0;
    final calories = foodSummary?.calories ?? 0;
    final protein = foodSummary?.protein ?? 0;
    final hydrationMl = foodSummary?.hydrationMl ?? 0;
    final digestiveSummary = activitySummary.digestiveSummary;
    final activityDetails = !activitySummary.isRecorded
        ? const <String>[]
        : digestiveSummary?.hasExplicitNoMovement == true
        ? const ['Digestive None']
        : (digestiveSummary?.eventCount ?? 0) > 0
        ? [
            'Digestive Count ${digestiveSummary!.eventCount}',
            'Total Amount ${digestiveSummary.totalAmount}',
          ]
        : const <String>[];

    final energyStatus =
        trainingSummary?.energyCalculationStatus ??
        TrainingEnergyCalculationStatus.complete;
    final cardioCalories = trainingSummary?.trainingCardioCaloriesKcal ?? 0;
    final estimatedTotalBurn = _estimatedTotalBurn(
      estimatedTDEE,
      trainingSummary,
    );

    return OperationCard(
      child: useLargeLayout
          ? Row(
              key: const ValueKey('operation-progress-large-layout'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSummary(
                    context,
                    cardioCalories: cardioCalories,
                    energyStatus: energyStatus,
                    estimatedTotalBurn: estimatedTotalBurn,
                    large: true,
                  ),
                ),
                SizedBox(width: AppSpacing.xl),
                Expanded(
                  flex: 3,
                  child: _buildProgressTiles(
                    morningComplete: morningComplete,
                    mealCount: mealCount,
                    calories: calories,
                    protein: protein,
                    hydrationMl: hydrationMl,
                    activityDetails: activityDetails,
                    forceTwoColumns: true,
                  ),
                ),
              ],
            )
          : Column(
              key: const ValueKey('operation-progress-compact-layout'),
              children: [
                _buildSummary(
                  context,
                  cardioCalories: cardioCalories,
                  energyStatus: energyStatus,
                  estimatedTotalBurn: estimatedTotalBurn,
                  large: false,
                ),
                AppSpacing.gapLG,
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildProgressTiles(
                      morningComplete: morningComplete,
                      mealCount: mealCount,
                      calories: calories,
                      protein: protein,
                      hydrationMl: hydrationMl,
                      activityDetails: activityDetails,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummary(
    BuildContext context, {
    required double cardioCalories,
    required TrainingEnergyCalculationStatus energyStatus,
    required double? estimatedTotalBurn,
    required bool large,
  }) {
    final metrics = [
      _ProgressSummaryMetric(
        label: 'WEIGHT',
        value: morningFact == null
            ? '--'
            : '${morningFact!.weight.toStringAsFixed(1)} kg',
        labelFirst: large,
      ),
      _ProgressSummaryMetric(
        label: 'SLEEP',
        value: morningFact == null
            ? '--'
            : _formatSleep(morningFact!.sleepDuration),
        labelFirst: large,
      ),
      _ProgressSummaryMetric(
        label: 'BASE BURN',
        value: estimatedTDEE == null
            ? '--'
            : '${estimatedTDEE!.toStringAsFixed(0)} kcal',
        labelFirst: large,
      ),
      _ProgressSummaryMetric(
        label: 'EXERCISE\nCARDIO ONLY',
        value: switch (energyStatus) {
          TrainingEnergyCalculationStatus.complete =>
            '${cardioCalories.toStringAsFixed(0)} kcal',
          TrainingEnergyCalculationStatus.partial =>
            '${cardioCalories.toStringAsFixed(0)} kcal\nPartial',
          TrainingEnergyCalculationStatus.notCalculated => 'Not calculated',
        },
        labelFirst: large,
      ),
      _ProgressSummaryMetric(
        label: 'EST. TOTAL BURN',
        value: estimatedTotalBurn == null
            ? 'Not calculated'
            : energyStatus == TrainingEnergyCalculationStatus.partial
            ? '${estimatedTotalBurn.toStringAsFixed(0)} kcal\nPartial'
            : '${estimatedTotalBurn.toStringAsFixed(0)} kcal',
        labelFirst: large,
      ),
    ];

    if (large) {
      return Column(
        key: const ValueKey('operation-summary'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPERATION SUMMARY',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.gapMD,
          for (var index = 0; index < metrics.length; index++) ...[
            metrics[index],
            if (index != metrics.length - 1) AppSpacing.gapMD,
          ],
        ],
      );
    }

    return Column(
      key: const ValueKey('operation-summary'),
      children: [
        Row(
          children: [
            for (final metric in metrics.take(3)) Expanded(child: metric),
          ],
        ),
        AppSpacing.gapMD,
        Row(
          children: [
            for (final metric in metrics.skip(3)) Expanded(child: metric),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressTiles({
    required bool morningComplete,
    required int mealCount,
    required double calories,
    required double protein,
    required double hydrationMl,
    required List<String> activityDetails,
    bool forceTwoColumns = false,
  }) {
    return LayoutBuilder(
      key: const ValueKey('operation-progress-tiles'),
      builder: (context, constraints) {
        final useTwoColumns = forceTwoColumns || constraints.maxWidth >= 280;
        final tileWidth = useTwoColumns
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        Widget tile({
          required String label,
          required String status,
          required double progress,
          VoidCallback? onTap,
          bool fullWidth = false,
          List<String> details = const [],
        }) {
          return SizedBox(
            key: ValueKey('operation-progress-$label'),
            width: fullWidth ? constraints.maxWidth : tileWidth,
            child: _ProgressRow(
              label: label,
              status: status,
              progress: progress,
              onTap: onTap,
              details: details,
            ),
          );
        }

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            tile(
              label: 'STATUS',
              status: morningComplete ? '完了' : '未完了',
              progress: morningComplete ? 1.0 : 0.0,
            ),
            tile(
              label: 'FOOD',
              status: '$mealCount / 3',
              progress: (mealCount / 3).clamp(0.0, 1.0).toDouble(),
            ),
            tile(
              label: 'CALORIES',
              status: '${calories.toStringAsFixed(0)} / 2200 kcal',
              progress: (calories / 2200).clamp(0.0, 1.0).toDouble(),
            ),
            tile(
              label: 'PROTEIN',
              status: '${protein.toStringAsFixed(1)} / 100 g',
              progress: (protein / 100).clamp(0.0, 1.0).toDouble(),
            ),
            tile(
              label: 'WATER',
              status: '${hydrationMl.toStringAsFixed(0)} / 3500 ml',
              progress: (hydrationMl / 3500).clamp(0.0, 1.0).toDouble(),
              onTap: onWaterTap,
            ),
            tile(
              label: 'TRAINING',
              status: trainingSummary?.completed == true
                  ? 'Recorded'
                  : 'Not recorded',
              progress: trainingSummary?.completed == true ? 1.0 : 0.0,
            ),
            tile(
              label: 'ACTIVITY',
              status: activitySummary.isRecorded
                  ? '${_formatSteps(activitySummary.steps)} steps'
                  : 'Not recorded',
              progress: activitySummary.isRecorded ? 1.0 : 0.0,
              fullWidth: true,
              details: activityDetails,
            ),
          ],
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

double? _estimatedTotalBurn(
  double? baseBurn,
  TrainingSummary? trainingSummary,
) {
  if (baseBurn == null) return null;
  final status =
      trainingSummary?.energyCalculationStatus ??
      TrainingEnergyCalculationStatus.complete;
  if (status == TrainingEnergyCalculationStatus.notCalculated) return null;
  return baseBurn + (trainingSummary?.trainingCardioCaloriesKcal ?? 0);
}

class _ProgressSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool labelFirst;

  const _ProgressSummaryMetric({
    required this.label,
    required this.value,
    this.labelFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: labelFirst
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (labelFirst)
          Text(label, style: Theme.of(context).textTheme.labelSmall)
        else
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        AppSpacing.gapXS,
        if (labelFirst)
          Text(value, style: Theme.of(context).textTheme.titleSmall)
        else
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
  final List<String> details;

  const _ProgressRow({
    required this.label,
    required this.status,
    required this.progress,
    this.onTap,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        AppSpacing.gapXS,
        Row(
          children: [
            Expanded(child: Text(status)),
            if (onTap != null) ...[
              SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
        if (details.isNotEmpty) ...[
          AppSpacing.gapSM,
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [for (final detail in details) Text(detail)],
          ),
        ],
        AppSpacing.gapXS,
        LinearProgressIndicator(value: progress),
      ],
    );

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: content,
        ),
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
      text: 'STATUS',
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
      text: 'FOOD',
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
      text: 'ACTIVITY',
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
      text: 'TRAINING',
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
      text: 'COMMAND CENTER',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.commandCenter);
      },
    );
  }
}
