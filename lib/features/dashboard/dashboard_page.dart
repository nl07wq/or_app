import 'package:flutter/material.dart';

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
import '../../core/widgets/operation_flip_tile.dart';
import '../../core/widgets/section_header.dart';
import '../system/widgets/system_menu_button.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/services/daily_log_confirmation_state.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/models/daily_log_confirmation_status.dart';
import '../../core/state/app_initialization_state.dart';

import '../food/services/food_submit_service.dart';
import '../food/data/water_quick_presets.dart';
import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';

import '../food/models/food_summary_state.dart';
import '../activity/models/activity_summary_state.dart';

import '../training/models/training_summary_state.dart';
import '../command_center/models/daily_command_read_model.dart';
import '../command_center/services/daily_command_read_model_builder.dart';
import '../command_center/services/daily_estimated_total_burn_service.dart';
import '../command_center/widgets/daily_command_item.dart';
import '../repositories/app_repository_container.dart';
import '../operation_date/models/operation_local_date.dart';
import '../operation_date/services/operation_date_service.dart';
import '../report_sync/models/morning_brief_state.dart';

import 'widgets/daily_log_card.dart';
import 'log_confirmation_review_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<OperationLocalDate> _operationDateFuture =
      const OperationDateService().current();
  int _operationDateTransitionToken = 0;

  @override
  Widget build(BuildContext context) {
    final isReadOnly = appInitializationController.value.isReadOnly;
    return Builder(
      builder: (context) {
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
                        final estimatedTDEE = input == null
                            ? null
                            : engine.estimateTDEE(input);

                        return Scaffold(
                          appBar: AppBar(
                            title: const Text('O.R.L.O.'),
                            actions: const [SystemMenuButton()],
                          ),
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
                                          _OperationDateCard(
                                            operationDateFuture:
                                                _operationDateFuture,
                                            transitionToken:
                                                _operationDateTransitionToken,
                                          ),
                                          AppSpacing.gapLG,
                                          SectionHeader(
                                            icon: Icons.dashboard_outlined,
                                            title: 'DAILY COMMAND',
                                          ),
                                          AppSpacing.gapSM,
                                          ValueListenableBuilder<int>(
                                            valueListenable:
                                                morningBriefRevisionNotifier,
                                            builder: (context, _, __) =>
                                                _DailyCommandSummary(
                                                  morningFact: morningFact,
                                                  foodSummary: foodSummary,
                                                  trainingSummary:
                                                      trainingSummary,
                                                  activitySummary:
                                                      activitySummary,
                                                ),
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
                                              return DailyLogCard(
                                                morningFact: morningFact,
                                                foodSummary: foodSummary,
                                                activitySummary:
                                                    activitySummary,
                                                trainingSummary:
                                                    trainingSummary,
                                                onReview: isReadOnly
                                                    ? null
                                                    : () async {
                                                        final changed = await Navigator.pushNamed(
                                                          context,
                                                          AppRoutes
                                                              .logConfirmationReview,
                                                          arguments: LogConfirmationReviewPage(
                                                            morning:
                                                                morningFact,
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
                                                            targetDate:
                                                                confirmationStatus
                                                                    .date,
                                                          ),
                                                        );
                                                        if (changed == true &&
                                                            mounted) {
                                                          await _refreshOperationDate(
                                                            animateTransition:
                                                                true,
                                                          );
                                                        }
                                                      },
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

  Future<void> _refreshOperationDate({bool animateTransition = false}) async {
    final operationDate = await const OperationDateService().current();
    if (!mounted) return;
    setState(() {
      _operationDateFuture = Future.value(operationDate);
      if (animateTransition) {
        _operationDateTransitionToken++;
      }
    });
  }

  void _showQuickWaterInput(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickWaterSheet(dashboardContext: context),
    );
  }
}

class _OperationDateCard extends StatefulWidget {
  const _OperationDateCard({
    required this.operationDateFuture,
    required this.transitionToken,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;

  @override
  State<_OperationDateCard> createState() => _OperationDateCardState();
}

class _OperationDateCardState extends State<_OperationDateCard> {
  OperationLocalDate? _displayedDate;
  int _consumedTransitionToken = 0;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: widget.operationDateFuture,
    builder: (context, snapshot) {
      var animate = false;
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        final nextDate = snapshot.requireData;
        animate =
            widget.transitionToken != _consumedTransitionToken &&
            _displayedDate != null &&
            _displayedDate != nextDate;
        _displayedDate = nextDate;
        _consumedTransitionToken = widget.transitionToken;
      }
      final date = _displayedDate;
      return OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                AppSpacing.gapSM,
                Text(
                  'OPERATION DATE',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            AppSpacing.gapSM,
            if (date == null)
              Text('LOADING...', style: Theme.of(context).textTheme.titleSmall)
            else
              _OperationDateFlipRow(date: date, animate: animate),
          ],
        ),
      );
    },
  );
}

class _OperationDateFlipRow extends StatelessWidget {
  const _OperationDateFlipRow({required this.date, required this.animate});

  static const _monthAndWeekdayWidth = 48.0;
  static const _dayWidth = 40.0;
  static const _tileHeight = 36.0;
  static const _tileGap = 6.0;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  final OperationLocalDate date;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final parsed = date.asUtcDate;
    final values = [
      _months[parsed.month - 1],
      parsed.day.toString().padLeft(2, '0'),
      _weekdays[parsed.weekday - 1],
    ];
    return Semantics(
      label: 'OPERATION DATE ${date.value}',
      child: ExcludeSemantics(
        child: Row(
          key: const ValueKey('operation-date-flip-row'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0) const SizedBox(width: _tileGap),
              OperationFlipTile(
                key: ValueKey('operation-date-tile-$index'),
                value: values[index],
                valueKey: ValueKey(
                  'operation-date-value-$index-${values[index]}',
                ),
                width: index == 1 ? _dayWidth : _monthAndWeekdayWidth,
                height: _tileHeight,
                animate: animate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyCommandSummary extends StatelessWidget {
  const _DailyCommandSummary({
    required this.morningFact,
    required this.foodSummary,
    required this.trainingSummary,
    required this.activitySummary,
  });

  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final TrainingSummary? trainingSummary;
  final ActivitySummary activitySummary;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyCommandReadModel>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const OperationCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const OperationCard(
            child: Text('Current Operationを読み込めませんでした。'),
          );
        }
        final model = snapshot.requireData;
        return OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DailyCommandItem(
                icon: model.operationStatus == null
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
                label: 'OPERATION STATUS',
                value: model.operationStatus?.name.toUpperCase() ?? 'STANDBY',
                status: model.operationStatus,
              ),
              AppSpacing.gapMD,
              DailyCommandItem(
                icon: Icons.flag_outlined,
                label: 'COMMANDER INTENT',
                value: model.commanderIntent ?? '—',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<DailyCommandReadModel> _load() async {
    final state = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    final morningBrief = await AppRepositoryRegistry.container.morningBriefs
        .readByLocalDate(state.operationDate.value);
    final burnWeight =
        await RecentStatusWeightResolver(
          AppRepositoryRegistry.container.status,
        ).resolve(
          operationDate: state.operationDate.value,
          currentWeightKg: morningFact?.weight,
        );
    return DailyCommandReadModelBuilder.build(
      operationState: state,
      status: morningFact,
      food: foodSummary,
      training: trainingSummary,
      activity: activitySummary,
      morningBrief: morningBrief,
      burnWeightKg: burnWeight,
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
        trainingSummary?.totalEnergyCalculationStatus ??
        TrainingEnergyCalculationStatus.complete;
    final exerciseCalories =
        trainingSummary?.trainingEstimatedCaloriesKcal ?? 0;
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
                    exerciseCalories: exerciseCalories,
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
                  exerciseCalories: exerciseCalories,
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
    required double exerciseCalories,
    required TrainingEnergyCalculationStatus energyStatus,
    required double? estimatedTotalBurn,
    required bool large,
  }) {
    final metrics = [
      _ProgressSummaryMetric(
        label: 'WEIGHT',
        value: morningFact == null
            ? '--'
            : morningFact!.weight == null
            ? '未計測'
            : '${morningFact!.weight!.toStringAsFixed(1)} kg',
        labelFirst: large,
      ),
      _ProgressSummaryMetric(
        label: 'SLEEP',
        value: morningFact == null
            ? '--'
            : morningFact!.sleepDuration == null
            ? '未計測'
            : _formatSleep(morningFact!.sleepDuration!),
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
        label: 'EXERCISE',
        value: switch (energyStatus) {
          TrainingEnergyCalculationStatus.complete =>
            '${exerciseCalories.toStringAsFixed(0)} kcal',
          TrainingEnergyCalculationStatus.partial =>
            '${exerciseCalories.toStringAsFixed(0)} kcal\nPartial',
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
      trainingSummary?.totalEnergyCalculationStatus ??
      TrainingEnergyCalculationStatus.complete;
  if (status == TrainingEnergyCalculationStatus.notCalculated) return null;
  return baseBurn + (trainingSummary?.trainingEstimatedCaloriesKcal ?? 0);
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
                children: WaterQuickPresets.valuesMl
                    .map(
                      (amount) => OutlinedButton(
                        onPressed: _isSaving ? null : () => _save(amount),
                        child: Text('+$amount ml'),
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
