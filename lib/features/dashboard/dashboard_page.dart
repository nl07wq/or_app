import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/operation_engine.dart';
import '../../core/engine/operation_input.dart';
import '../../core/engine/training_summary.dart';
import '../../core/models/meal_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/app_clock.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_flip_tile.dart';
import '../../core/widgets/section_header.dart';
import '../system/widgets/system_menu_button.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/state/app_initialization_state.dart';

import '../food/services/food_submit_service.dart';
import '../food/data/water_quick_presets.dart';
import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';

import '../food/models/food_summary_state.dart';
import '../activity/models/activity_summary_state.dart';

import '../training/models/training_summary_state.dart';
import '../training/services/training_status_weight_resolver.dart';
import '../command_center/models/daily_command_read_model.dart';
import '../command_center/services/daily_command_read_model_builder.dart';
import '../command_center/widgets/daily_command_item.dart';
import '../repositories/app_repository_container.dart';
import '../operation_date/models/operation_local_date.dart';
import '../operation_date/services/operation_date_service.dart';
import '../operation_date/widgets/operation_date_flip_calendar.dart';
import '../report_sync/models/morning_brief_state.dart';

import 'models/dynamic_daily_target.dart';
import 'services/dynamic_daily_target_service.dart';
import 'widgets/daily_log_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<OperationLocalDate> _operationDateFuture =
      const OperationDateService().current();
  int _operationDateTransitionToken = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                                key: const ValueKey('dashboard-scroll-view'),
                                controller: _scrollController,
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
                                            builder: (context, _, _) =>
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
                                            refreshToken:
                                                _operationDateTransitionToken,
                                            useLargeLayout: useLargeLayout,
                                            onWaterTap: isReadOnly
                                                ? null
                                                : () => _showQuickWaterInput(
                                                    context,
                                                  ),
                                          ),
                                          AppSpacing.gapXL,
                                          DailyLogSection(
                                            morningFact: morningFact,
                                            foodSummary: foodSummary,
                                            activitySummary: activitySummary,
                                            trainingSummary: trainingSummary,
                                            estimatedTotalBurn:
                                                _estimatedTotalBurn(
                                                  estimatedTDEE,
                                                  trainingSummary,
                                                ),
                                            onReviewCompleted:
                                                _showFinalizeDateTransition,
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

  Future<void> _showFinalizeDateTransition(
    OperationLocalDate previousOperationDate,
  ) async {
    final nextOperationDate = await const OperationDateService().current();
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _operationDateFuture = Future.value(previousOperationDate);
    });
    await _waitUntilDashboardIsVisible();
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _operationDateFuture = Future.value(nextOperationDate);
      _operationDateTransitionToken++;
    });
  }

  Future<void> _waitUntilDashboardIsVisible() async {
    final secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    if (secondaryAnimation == null ||
        secondaryAnimation.status == AnimationStatus.dismissed) {
      return;
    }
    final completer = Completer<void>();
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.dismissed && !completer.isCompleted) {
        secondaryAnimation.removeStatusListener(listener);
        completer.complete();
      }
    }

    secondaryAnimation.addStatusListener(listener);
    listener(secondaryAnimation.status);
    await completer.future;
  }

  void _showQuickWaterInput(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuickWaterSheet(dashboardContext: context),
    );
  }
}

class _OperationDateCard extends StatelessWidget {
  const _OperationDateCard({
    required this.operationDateFuture,
    required this.transitionToken,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;

  @override
  Widget build(BuildContext context) => OperationCard(
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
        Wrap(
          key: const ValueKey('dashboard-date-time-row'),
          spacing: 0,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: OperationDateFlipCalendar(
                operationDateFuture: operationDateFuture,
                transitionToken: transitionToken,
                tileWidth: 42,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: SizedBox(
                    height:
                        OperationDateFlipCalendar.defaultTileHeight +
                        AppSpacing.xs * 2,
                    child: VerticalDivider(
                      key: const ValueKey('dashboard-date-time-divider'),
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: _DashboardLiveFlipClock(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _DashboardLiveFlipClock extends StatefulWidget {
  const _DashboardLiveFlipClock();

  static const tileWidth = 24.0;
  static const tileHeight = OperationDateFlipCalendar.defaultTileHeight;
  static const tileGap = 6.0;
  static const pairGap = 3.0;

  @override
  State<_DashboardLiveFlipClock> createState() =>
      _DashboardLiveFlipClockState();
}

class _DashboardLiveFlipClockState extends State<_DashboardLiveFlipClock>
    with WidgetsBindingObserver {
  late DateTime _displayedTime = AppClock.now();
  Timer? _timer;
  Animation<double>? _secondaryAnimation;
  bool _routeVisible = true;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAnimation = ModalRoute.of(context)?.secondaryAnimation;
    if (_secondaryAnimation != nextAnimation) {
      _secondaryAnimation?.removeStatusListener(_handleRouteStatus);
      _secondaryAnimation = nextAnimation;
      _secondaryAnimation?.addStatusListener(_handleRouteStatus);
    }
    _routeVisible =
        nextAnimation == null ||
        nextAnimation.status == AnimationStatus.dismissed;
    if (_routeVisible && _appActive) {
      _displayedTime = AppClock.now();
      _scheduleNextTick();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive && _routeVisible) {
      _syncAndSchedule();
    } else {
      _timer?.cancel();
    }
  }

  void _handleRouteStatus(AnimationStatus status) {
    final visible = status == AnimationStatus.dismissed;
    if (_routeVisible == visible) return;
    _routeVisible = visible;
    if (visible && _appActive) {
      _syncAndSchedule();
    } else {
      _timer?.cancel();
    }
  }

  void _syncAndSchedule() {
    if (!mounted) return;
    final now = AppClock.now();
    if (_secondStamp(now) != _secondStamp(_displayedTime)) {
      setState(() => _displayedTime = now);
    }
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    if (!_routeVisible || !_appActive) return;
    final now = AppClock.now();
    final delay = Duration(milliseconds: 1000 - now.millisecond);
    _timer = Timer(delay, _syncAndSchedule);
  }

  int _secondStamp(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

  @override
  void dispose() {
    _timer?.cancel();
    _secondaryAnimation?.removeStatusListener(_handleRouteStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = [
      _displayedTime.hour.toString().padLeft(2, '0'),
      _displayedTime.minute.toString().padLeft(2, '0'),
      _displayedTime.second.toString().padLeft(2, '0'),
    ].expand((value) => value.split('')).toList(growable: false);
    return Semantics(
      label:
          'CURRENT TIME ${values[0]}${values[1]}:'
          '${values[2]}${values[3]}:${values[4]}${values[5]}',
      child: ExcludeSemantics(
        child: Row(
          key: const ValueKey('dashboard-live-flip-clock'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0)
                SizedBox(
                  width: index.isOdd
                      ? _DashboardLiveFlipClock.pairGap
                      : _DashboardLiveFlipClock.tileGap,
                  child: index == 2 || index == 4
                      ? Center(
                          child: Text(
                            ':',
                            key: ValueKey('dashboard-time-colon-${index ~/ 2}'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                          ),
                        )
                      : null,
                ),
              OperationMechanicalFlipTile(
                key: ValueKey('dashboard-time-tile-$index'),
                value: values[index],
                width: _DashboardLiveFlipClock.tileWidth,
                height: _DashboardLiveFlipClock.tileHeight,
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
    final burnWeight = await TrainingStatusWeightResolver(
      repository: AppRepositoryRegistry.container.status,
    ).resolve(state.operationDate.value);
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

class _ProgressCard extends StatefulWidget {
  final MorningFact? morningFact;
  final double? estimatedTDEE;
  final FoodSummary? foodSummary;
  final TrainingSummary? trainingSummary;
  final ActivitySummary activitySummary;
  final int refreshToken;
  final bool useLargeLayout;
  final VoidCallback? onWaterTap;

  const _ProgressCard({
    required this.morningFact,
    required this.estimatedTDEE,
    required this.foodSummary,
    required this.trainingSummary,
    required this.activitySummary,
    required this.refreshToken,
    required this.useLargeLayout,
    required this.onWaterTap,
  });

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  late Future<DynamicDailyTargetResult> _targets = _loadDynamicTargets();

  @override
  void didUpdateWidget(covariant _ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.morningFact != widget.morningFact ||
        oldWidget.foodSummary != widget.foodSummary ||
        oldWidget.trainingSummary != widget.trainingSummary ||
        oldWidget.activitySummary != widget.activitySummary ||
        oldWidget.refreshToken != widget.refreshToken) {
      _targets = _loadDynamicTargets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final morningComplete = widget.morningFact != null;
    final mealCount = widget.foodSummary?.mealCount ?? 0;
    final calories = widget.foodSummary?.calories ?? 0;
    final protein = widget.foodSummary?.protein ?? 0;
    final hydrationMl = widget.foodSummary?.hydrationMl ?? 0;
    final digestiveSummary = widget.activitySummary.digestiveSummary;
    final activityDetails = !widget.activitySummary.isRecorded
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
        widget.trainingSummary?.totalEnergyCalculationStatus ??
        TrainingEnergyCalculationStatus.complete;
    final exerciseCalories =
        widget.trainingSummary?.trainingEstimatedCaloriesKcal ?? 0;
    return FutureBuilder<DynamicDailyTargetResult>(
      future: _targets,
      builder: (context, snapshot) {
        final targets = snapshot.data;
        final estimatedTotalBurn =
            targets?.estimatedTotalBurnKcal ??
            _estimatedTotalBurn(widget.estimatedTDEE, widget.trainingSummary);
        return OperationCard(
          child: widget.useLargeLayout
              ? Row(
                  key: const ValueKey('operation-progress-large-layout'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildSummary(
                        context,
                        estimatedBaseBurn:
                            targets?.estimatedBaseBurnKcal ??
                            widget.estimatedTDEE,
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
                        targets: targets,
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
                      estimatedBaseBurn:
                          targets?.estimatedBaseBurnKcal ??
                          widget.estimatedTDEE,
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
                          targets: targets,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<DynamicDailyTargetResult> _loadDynamicTargets() async {
    final operationDate = await const OperationDateService().current();
    final repositories = AppRepositoryRegistry.container;
    return DynamicDailyTargetService(
      statusRepository: repositories.status,
      trainingRepository: repositories.training,
    ).load(
      operationDate: operationDate.value,
      currentStatus: widget.morningFact,
      food: widget.foodSummary,
      activity: widget.activitySummary,
      training: widget.trainingSummary,
    );
  }

  Widget _buildSummary(
    BuildContext context, {
    required double? estimatedBaseBurn,
    required double exerciseCalories,
    required TrainingEnergyCalculationStatus energyStatus,
    required double? estimatedTotalBurn,
    required bool large,
  }) {
    final metrics = [
      _ProgressSummaryMetric(
        label: 'WEIGHT',
        value: widget.morningFact == null
            ? '--'
            : widget.morningFact!.weight == null
            ? '未計測'
            : '${widget.morningFact!.weight!.toStringAsFixed(1)} kg',
        labelFirst: true,
      ),
      _ProgressSummaryMetric(
        label: 'SLEEP',
        value: widget.morningFact == null
            ? '--'
            : widget.morningFact!.sleepDuration == null
            ? '未計測'
            : _formatSleep(widget.morningFact!.sleepDuration!),
        labelFirst: true,
      ),
      _ProgressSummaryMetric(
        label: 'BASE BURN',
        value: estimatedBaseBurn == null
            ? '--'
            : '${estimatedBaseBurn.toStringAsFixed(0)} kcal',
        labelFirst: true,
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
        labelFirst: true,
      ),
      _ProgressSummaryMetric(
        label: 'EST. TOTAL BURN',
        value: estimatedTotalBurn == null
            ? 'Not calculated'
            : energyStatus == TrainingEnergyCalculationStatus.partial
            ? '${estimatedTotalBurn.toStringAsFixed(0)} kcal\nPartial'
            : '${estimatedTotalBurn.toStringAsFixed(0)} kcal',
        labelFirst: true,
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
    required DynamicDailyTargetResult? targets,
    bool forceTwoColumns = false,
  }) {
    final foodSummaryAvailable = widget.foodSummary != null && mealCount > 0;
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
          DynamicTargetState? targetState,
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
              targetState: targetState,
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
              status: _rangeStatus(
                targets?.calories,
                unit: 'kcal',
                displayTarget:
                    DynamicDailyTargetPresentation.caloriesTargetKcal(
                      targets?.calories,
                    ),
                formatCurrent: _formatIntegerValue,
                fallbackCurrent: foodSummaryAvailable ? calories : null,
              ),
              progress: _rangeProgress(targets?.calories),
              targetState: targets?.calories.state,
            ),
            tile(
              label: 'PROTEIN',
              status: _rangeStatus(
                targets?.protein,
                unit: 'g',
                displayTarget: DynamicDailyTargetPresentation.proteinTargetG(
                  targets?.protein,
                ),
                formatCurrent: _formatProtein,
                fallbackCurrent: foodSummaryAvailable ? protein : null,
              ),
              progress: _rangeProgress(targets?.protein),
              targetState: targets?.protein.state,
            ),
            tile(
              label: 'WATER',
              status: _waterStatus(
                targets?.water,
                fallbackCurrent: widget.foodSummary?.waterRecorded == true
                    ? hydrationMl
                    : null,
              ),
              progress: _waterProgress(targets?.water),
              targetState: targets?.water.state,
              onTap: widget.onWaterTap,
            ),
            tile(
              label: 'TRAINING',
              status: widget.trainingSummary?.completed == true
                  ? 'Recorded'
                  : 'Not recorded',
              progress: widget.trainingSummary?.completed == true ? 1.0 : 0.0,
            ),
            tile(
              label: 'ACTIVITY',
              status: widget.activitySummary.isRecorded
                  ? '${_formatInteger(widget.activitySummary.steps)} steps'
                  : 'Not recorded',
              progress: widget.activitySummary.isRecorded ? 1.0 : 0.0,
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

  String _formatInteger(int value) => value.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );

  String _rangeStatus(
    DynamicRangeTarget? target, {
    required String unit,
    required int? displayTarget,
    required String Function(double) formatCurrent,
    required double? fallbackCurrent,
  }) {
    final current = target?.current ?? fallbackCurrent ?? 0;
    final targetLabel = displayTarget == null
        ? '--'
        : _formatInteger(displayTarget);
    return '${formatCurrent(current)} / $targetLabel $unit';
  }

  double _rangeProgress(DynamicRangeTarget? target) {
    final current = target?.current;
    final low = target?.low;
    if (current == null || low == null || low <= 0) return 0;
    return (current / low).clamp(0.0, 1.0).toDouble();
  }

  String _waterStatus(
    DynamicWaterTarget? target, {
    required double? fallbackCurrent,
  }) {
    final current = target?.current ?? fallbackCurrent ?? 0;
    final displayTarget = DynamicDailyTargetPresentation.waterTargetMl(target);
    final targetLabel = displayTarget == null
        ? '--'
        : _formatInteger(displayTarget);
    return '${_formatIntegerValue(current)} / $targetLabel ml';
  }

  String _formatIntegerValue(double value) => _formatInteger(value.round());

  String _formatProtein(double value) => value == value.roundToDouble()
      ? _formatInteger(value.round())
      : value.toStringAsFixed(1);

  double _waterProgress(DynamicWaterTarget? target) {
    final current = target?.current;
    final goal = target?.finalTargetMl;
    if (current == null || goal == null || goal <= 0) return 0;
    return (current / goal).clamp(0.0, 1.0).toDouble();
  }
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          )
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
  final DynamicTargetState? targetState;

  const _ProgressRow({
    required this.label,
    required this.status,
    required this.progress,
    this.onTap,
    this.details = const [],
    this.targetState,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = targetState == null
        ? progress >= 1
        : targetState == DynamicTargetState.green ||
              targetState == DynamicTargetState.greenHigh;
    final semanticColor = switch (targetState) {
      DynamicTargetState.green ||
      DynamicTargetState.greenHigh => AppColors.success,
      DynamicTargetState.yellowLow ||
      DynamicTargetState.yellowHigh => AppColors.warning,
      DynamicTargetState.redLow ||
      DynamicTargetState.redHigh => AppColors.danger,
      _ => null,
    };
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
        LinearProgressIndicator(
          value: progress,
          color: semanticColor ?? (completed ? AppColors.success : null),
        ),
      ],
    );

    return Material(
      color: completed
          ? (semanticColor ?? AppColors.success).withValues(alpha: 0.12)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: completed
              ? semanticColor ?? AppColors.success
              : semanticColor ??
                    colorScheme.outlineVariant.withValues(alpha: 0.6),
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
  int _recordSequence = 0;
  String? _validationMessage;

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _addDraftAmount(int amountMl) {
    final input = _customAmountController.text.trim();
    final currentAmount = input.isEmpty ? 0 : int.tryParse(input);
    if (currentAmount == null || currentAmount < 0) return;

    final nextAmount = currentAmount + amountMl;
    final nextText = nextAmount.toString();
    _customAmountController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
    }
  }

  Future<void> _saveCustomAmount() async {
    final amountMl = int.tryParse(_customAmountController.text.trim());

    if (amountMl == null || amountMl <= 0) {
      setState(() => _validationMessage = '正の整数の ml を入力してください。');
      return;
    }

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    try {
      final operationDate = await const OperationDateService().current();
      await FoodSubmitService.save(
        MealData(
          id: '${DateTime.now().microsecondsSinceEpoch}-${_recordSequence++}',
          date: operationDate.value,
          mealType: 'Water',
          items: const [],
          memo: '',
          waterMl: amountMl.toDouble(),
        ),
        operationLocalDate: operationDate.value,
      );

      if (!mounted || !widget.dashboardContext.mounted) return;

      _customAmountController.clear();
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        widget.dashboardContext,
      ).showSnackBar(SnackBar(content: Text('Water +$amountMl ml recorded')));
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
              ValueListenableBuilder<FoodSummary?>(
                valueListenable: foodSummaryNotifier,
                builder: (context, summary, _) => Text(
                  'CURRENT WATER  ${(summary?.hydrationMl ?? 0).toStringAsFixed(0)} ml',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              AppSpacing.gapMD,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WaterQuickPresets.valuesMl
                    .map(
                      (amount) => OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _addDraftAmount(amount),
                        child: Text('+$amount ml'),
                      ),
                    )
                    .toList(),
              ),
              AppSpacing.gapLG,
              OperationTextField(
                controller: _customAmountController,
                label: 'Amount (ml)',
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
