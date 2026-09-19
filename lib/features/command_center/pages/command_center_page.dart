import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/models/operation_calendar_period.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../activity/models/activity_summary_state.dart';
import '../../dashboard/widgets/daily_log_card.dart';
import '../../food/models/food_summary_state.dart';
import '../../morning/models/morning_fact_state.dart';
import '../../morning/models/morning_fact.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/models/operation_state.dart';
import '../../operation_date/services/daily_finalize_coordinator_factory.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../../operation_date/state/finalize_date_transition.dart';
import '../../operation_date/widgets/operation_date_flip_calendar.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/models/training_summary_state.dart';
import '../../training/services/training_status_weight_resolver.dart';
import '../models/daily_command_read_model.dart';
import '../core/daily_assessment_rule_engine.dart';
import '../models/daily_assessment.dart';
import '../services/daily_assessment_fact_loader.dart';
import '../services/daily_command_read_model_builder.dart';
import '../widgets/daily_assessment_card.dart';
import '../widgets/data_center_page.dart';
import '../widgets/brief_debrief_page.dart';
import '../widgets/semantic_help_popover.dart';
import '../../report_sync/models/morning_brief_state.dart';
import '../../report_sync/models/daily_debrief_record.dart';
import '../../report_sync/models/daily_debrief_state.dart';
import '../../periodic_report/models/periodic_report.dart';
import '../../periodic_report/pages/periodic_report_page.dart';

@visibleForTesting
List<PeriodicReportType> periodicReportTypesForFinalizedDate(DateTime date) => [
  if (date.weekday == DateTime.sunday) PeriodicReportType.weekly,
  if (date.day == DateTime(date.year, date.month + 1, 0).day)
    PeriodicReportType.monthly,
  if (date.month == DateTime.december && date.day == 31)
    PeriodicReportType.yearly,
];

@visibleForTesting
Future<List<PeriodicReportType>> pendingPeriodicReportTypesForFinalizedDate(
  DateTime date,
  Future<bool> Function(String periodId) reportExists,
) async {
  final pending = <PeriodicReportType>[];
  for (final type in periodicReportTypesForFinalizedDate(date)) {
    final period = switch (type) {
      PeriodicReportType.weekly => OperationCalendarPeriod.week(date),
      PeriodicReportType.monthly => OperationCalendarPeriod.month(date),
      PeriodicReportType.yearly => OperationCalendarPeriod.year(date),
    };
    if (!await reportExists(period.id)) pending.add(type);
  }
  return pending;
}

@visibleForTesting
Future<void> runPeriodicReportWorkflowForFinalizedDate({
  required DateTime finalizedDate,
  required Future<bool> Function(PeriodicReportType type) openReport,
}) async {
  // The report workspace resolves both states: it displays an existing record
  // directly or opens the formal creation/import flow when it is missing.
  // Skipping an existing period here used to suppress the required Sunday
  // navigation entirely.
  for (final type in periodicReportTypesForFinalizedDate(finalizedDate)) {
    if (!await openReport(type)) return;
  }
}

String cycleStateHelp(DailyCommandCycleState state) => switch (state) {
  DailyCommandCycleState.standby =>
    '有効なSTATUSがまだありません。STATUSが確定すると当日の運用を開始します。',
  DailyCommandCycleState.active => '当日の記録を進めています。必要な日次項目が揃うと日次確定準備へ進みます。',
  DailyCommandCycleState.reviewReady =>
    '必要な日次項目が揃いました。DAILY DEBRIEFを作成して日次確定へ進めます。',
  DailyCommandCycleState.awaitingDebrief =>
    'DAILY DEBRIEFの作成または更新が必要です。内容が最新になるとFINALIZEできます。',
  DailyCommandCycleState.finalizeReady =>
    'DAILY DEBRIEFは最新です。FINALIZE DAYで当日の記録を確定できます。',
  DailyCommandCycleState.finalizing =>
    '日次確認とDAILY AGGREGATEを作成・保存しています。完了するとDAILY DEBRIEF待ちへ進みます。',
  DailyCommandCycleState.recoveryRequired =>
    '日次確定のバックアップまたは日付更新の復旧が必要です。復旧完了後に通常運用へ戻ります。',
};

enum CommandCenterSection {
  periodicReport,
  briefDebrief,
  dailyCommand,
  dataCenter,
}

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({
    super.key,
    this.initialSection = CommandCenterSection.dailyCommand,
    this.initialBriefDebriefTab = BriefDebriefTab.dailyBrief,
  });

  final CommandCenterSection initialSection;
  final BriefDebriefTab initialBriefDebriefTab;

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  late final PageController _pageController;
  late final ScrollController _tabScrollController;
  late int _currentPage;
  var _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialSection.index;
    _pageController = PageController(initialPage: _currentPage);
    _tabScrollController = ScrollController(
      initialScrollOffset: _WorkspaceHeader.initialPriorityOffset,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _selectPage(int page) {
    if (_currentPage != page) setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _refresh() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COMMAND CENTER')),
      body: Column(
        children: [
          _WorkspaceHeader(
            currentPage: _currentPage,
            onSelectPage: _selectPage,
            scrollController: _tabScrollController,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                const PeriodicReportWorkspace(),
                BriefDebriefPage(initialTab: widget.initialBriefDebriefTab),
                _DailyCommandPage(
                  refreshToken: _refreshToken,
                  onRefresh: _refresh,
                ),
                const DataCenterPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCommandPage extends StatefulWidget {
  const _DailyCommandPage({
    required this.refreshToken,
    required this.onRefresh,
  });

  final int refreshToken;
  final VoidCallback onRefresh;

  @override
  State<_DailyCommandPage> createState() => _DailyCommandPageState();
}

class _DailyCommandPresentation {
  const _DailyCommandPresentation({
    required this.result,
    required this.morningFact,
    required this.foodSummary,
    required this.activitySummary,
    required this.trainingSummary,
  });

  final ({DailyCommandReadModel model, DailyAssessment assessment}) result;
  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final ActivitySummary activitySummary;
  final TrainingSummary? trainingSummary;
}

class _DailyCommandPageState extends State<_DailyCommandPage> {
  late final Future<OperationLocalDate> _operationDateFuture =
      const OperationDateService().current();
  late Future<({DailyCommandReadModel model, DailyAssessment assessment})>
  _modelFuture = _loadModel();
  _DailyCommandPresentation? _visiblePresentation;
  var _freezeFinalizeViewport = false;
  late final List<Listenable> _modelSources = [
    morningFactNotifier,
    foodSummaryNotifier,
    trainingSummaryNotifier,
    activitySummaryNotifier,
    morningBriefRevisionNotifier,
  ];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    for (final source in _modelSources) {
      source.addListener(_reloadModel);
    }
    dailyDebriefRevisionNotifier.addListener(_reloadForDailyDebriefChange);
  }

  @override
  void didUpdateWidget(covariant _DailyCommandPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _modelFuture = _loadModel();
    }
  }

  @override
  void dispose() {
    for (final source in _modelSources) {
      source.removeListener(_reloadModel);
    }
    dailyDebriefRevisionNotifier.removeListener(_reloadForDailyDebriefChange);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<
        ({DailyCommandReadModel model, DailyAssessment assessment})
      >(
        future: _modelFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              (snapshot.hasError || !snapshot.hasData)) {
            return _ErrorContent(onRetry: widget.onRefresh);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // DailyStateRestore refreshes these facts after FINALIZE. Keep the
          // existing ListView mounted while that replacement future resolves:
          // the Backup modal can then close over the same operating viewport
          // instead of exposing a loading frame followed by PageStorage's
          // scroll restoration.
          final loadedPresentation = _DailyCommandPresentation(
            result: snapshot.requireData,
            morningFact: morningFactNotifier.value,
            foodSummary: foodSummaryNotifier.value,
            activitySummary: activitySummaryNotifier.value,
            trainingSummary: trainingSummaryNotifier.value,
          );
          if (!_freezeFinalizeViewport) {
            _visiblePresentation = loadedPresentation;
          }
          final presentation = _freezeFinalizeViewport
              ? _visiblePresentation ?? loadedPresentation
              : loadedPresentation;
          return _DailyCommandContent(
            model: presentation.result.model,
            assessment: presentation.result.assessment,
            operationDateFuture: _operationDateFuture,
            scrollController: _scrollController,
            morningFact: presentation.morningFact,
            foodSummary: presentation.foodSummary,
            activitySummary: presentation.activitySummary,
            trainingSummary: presentation.trainingSummary,
            onFinalizeStarted: _freezeViewportForFinalize,
            onFinalizePresentationReleased: _releaseFinalizeViewport,
            onReviewCompleted: _handoffFinalizeDateTransition,
          );
        },
      );

  void _reloadModel() {
    if (!mounted || !AppRepositoryRegistry.hasContainer) return;
    setState(() {
      _modelFuture = _loadModel();
    });
  }

  void _reloadForDailyDebriefChange() {
    final currentOperationDate =
        _visiblePresentation?.result.model.operationDate;
    if (currentOperationDate != null &&
        currentOperationDate !=
            dailyDebriefRevisionNotifier.value.operationDate) {
      return;
    }
    _reloadModel();
  }

  void _freezeViewportForFinalize() {
    if (!mounted || _freezeFinalizeViewport) return;
    setState(() => _freezeFinalizeViewport = true);
  }

  void _releaseFinalizeViewport() {
    if (!mounted || !_freezeFinalizeViewport) return;
    setState(() => _freezeFinalizeViewport = false);
  }

  Future<({DailyCommandReadModel model, DailyAssessment assessment})>
  _loadModel() async {
    final state = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    final morningBrief = await AppRepositoryRegistry.container.morningBriefs
        .readByLocalDate(state.operationDate.value);
    final status = morningFactNotifier.value;
    final burnWeight = await TrainingStatusWeightResolver(
      repository: AppRepositoryRegistry.container.status,
    ).resolve(state.operationDate.value);
    final dailyDebriefFinalizeReady = await _dailyDebriefFinalizeReady(state);
    final model = DailyCommandReadModelBuilder.build(
      operationState: state,
      status: status,
      food: foodSummaryNotifier.value,
      training: trainingSummaryNotifier.value,
      activity: activitySummaryNotifier.value,
      morningBrief: morningBrief,
      burnWeightKg: burnWeight,
      dailyDebriefFinalizeReady: dailyDebriefFinalizeReady,
    );
    final facts = await DailyAssessmentFactLoader(
      AppRepositoryRegistry.container,
    ).load(state);
    return (
      model: model,
      assessment: const DailyAssessmentRuleEngine().evaluate(facts),
    );
  }

  Future<bool> _dailyDebriefFinalizeReady(OperationState state) async {
    if (state.phase != OperationPhase.awaitingDebrief) return false;
    final container = AppRepositoryRegistry.container;
    final debrief = await container.dailyDebriefs.readByLocalDate(
      state.operationDate.value,
    );
    if (debrief == null ||
        await container.dailyDebriefSources.projectLifecycle(debrief) !=
            DailyDebriefLifecycleStatus.active) {
      return false;
    }
    try {
      await DailyFinalizeCoordinatorFactory.production()
          .validateCurrentSourceSnapshot(state);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handoffFinalizeDateTransition(
    OperationLocalDate previousOperationDate,
  ) async {
    final nextOperationDate = await const OperationDateService().current();
    if (!mounted) return;
    FinalizeDateTransitionStore.publish(
      FinalizeDateTransition(
        fromDate: previousOperationDate,
        toDate: nextOperationDate,
      ),
    );
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.finalizedDashboard, (_) => false);
  }
}

class _DailyCommandContent extends StatelessWidget {
  const _DailyCommandContent({
    required this.model,
    required this.assessment,
    required this.operationDateFuture,
    required this.scrollController,
    required this.morningFact,
    required this.foodSummary,
    required this.activitySummary,
    required this.trainingSummary,
    required this.onFinalizeStarted,
    required this.onFinalizePresentationReleased,
    required this.onReviewCompleted,
  });

  final DailyCommandReadModel model;
  final DailyAssessment assessment;
  final Future<OperationLocalDate> operationDateFuture;
  final ScrollController scrollController;
  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final ActivitySummary activitySummary;
  final TrainingSummary? trainingSummary;
  final VoidCallback onFinalizeStarted;
  final VoidCallback onFinalizePresentationReleased;
  final DailyLogReviewCompleted onReviewCompleted;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // FINALIZE refreshes daily summaries while the Backup dialog is open.
      // Keep the operator's current Daily Log viewport when that refresh
      // temporarily replaces this ListView, until Dashboard takes over.
      key: const PageStorageKey('daily-command-list'),
      controller: scrollController,
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.radar_outlined,
          title: 'CURRENT OPERATION',
        ),
        AppSpacing.gapSM,
        _CurrentOperationCard(
          operationDateFuture: operationDateFuture,
          cycleState: model.cycleState,
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.assessment_outlined,
          title: 'DAILY ASSESSMENT',
        ),
        AppSpacing.gapSM,
        DailyAssessmentView(assessment: assessment),
        AppSpacing.gapXL,
        DailyLogSection(
          morningFact: morningFact,
          foodSummary: foodSummary,
          activitySummary: activitySummary,
          trainingSummary: trainingSummary,
          estimatedTotalBurn: model.estimatedTotalBurnKcal,
          onFinalizeStarted: onFinalizeStarted,
          onFinalizePresentationReleased: onFinalizePresentationReleased,
          onReviewCompleted: onReviewCompleted,
        ),
        AppSpacing.gapLG,
      ],
    );
  }
}

class _CurrentOperationCard extends StatelessWidget {
  _CurrentOperationCard({
    required this.operationDateFuture,
    required this.cycleState,
  }) : _visibleAnchorKey = GlobalKey();

  final Future<OperationLocalDate> operationDateFuture;
  final DailyCommandCycleState cycleState;
  final GlobalKey _visibleAnchorKey;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Row(
      key: const ValueKey('current-operation-card-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          key: const ValueKey('current-operation-date-group'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.calendar_today,
                  key: const ValueKey('current-operation-date-heading-icon'),
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'OPERATION DATE',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            AppSpacing.gapSM,
            OperationDateFlipCalendar(
              operationDateFuture: operationDateFuture,
              transitionToken: 0,
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            key: const ValueKey('current-operation-cycle-group'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.page_info,
                      key: const ValueKey(
                        'current-operation-cycle-heading-icon',
                      ),
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'CYCLE STATE',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXS,
              SemanticHelpPopover(
                id: 'cycle-${cycleState.name}',
                title: cycleStateShortLabelFor(cycleState),
                description: cycleStateHelp(cycleState),
                visibleAnchorKey: _visibleAnchorKey,
                child: Semantics(
                  button: true,
                  label: 'CYCLE STATE ${cycleStateShortLabelFor(cycleState)}',
                  child: FittedBox(
                    key: const ValueKey('current-operation-cycle-value'),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KeyedSubtree(
                          key: _visibleAnchorKey,
                          child: Icon(
                            cycleStateIconFor(cycleState),
                            key: const ValueKey('current-operation-cycle-icon'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          cycleStateShortLabelFor(cycleState),
                          key: const ValueKey('current-operation-cycle-label'),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: OperationCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Current Operationを読み込めませんでした。'),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.refresh,
            text: 'RETRY',
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceHeader extends StatefulWidget {
  const _WorkspaceHeader({
    required this.currentPage,
    required this.onSelectPage,
    required this.scrollController,
  });

  static const initialPriorityOffset = 132.0;
  static const _periodicTabWidth = 150.0;
  static const _priorityTabWidth = 110.0;
  static const _dataCenterTabWidth = 100.0;

  final int currentPage;
  final ValueChanged<int> onSelectPage;

  final ScrollController scrollController;

  @override
  State<_WorkspaceHeader> createState() => _WorkspaceHeaderState();
}

class _WorkspaceHeaderState extends State<_WorkspaceHeader> {
  @override
  void initState() {
    super.initState();
    if (widget.currentPage != CommandCenterSection.dailyCommand.index) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureCurrentTabVisible(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _WorkspaceHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureCurrentTabVisible(),
      );
    }
  }

  void _ensureCurrentTabVisible() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    final section = CommandCenterSection.values[widget.currentPage];
    final target = switch (section) {
      CommandCenterSection.periodicReport ||
      CommandCenterSection.briefDebrief => position.minScrollExtent,
      CommandCenterSection.dailyCommand ||
      CommandCenterSection.dataCenter => position.maxScrollExtent,
    };
    if ((position.pixels - target).abs() < 0.5) return;
    widget.scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'PERIODIC REPORT',
      'BRIEF / DEBRIEF',
      'DAILY COMMAND',
      'DATA CENTER',
    ];
    return SingleChildScrollView(
      key: const ValueKey('command-center-tab-scroll'),
      controller: widget.scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: List.generate(
          labels.length,
          (index) => SizedBox(
            width: index == CommandCenterSection.periodicReport.index
                ? _WorkspaceHeader._periodicTabWidth
                : index == CommandCenterSection.dataCenter.index
                ? _WorkspaceHeader._dataCenterTabWidth
                : _WorkspaceHeader._priorityTabWidth,
            height: 48,
            child: AnimatedContainer(
              key: ValueKey('command-center-tab-$index'),
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: index == widget.currentPage
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                onPressed: () => widget.onSelectPage(index),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    style: TextStyle(
                      color: index == widget.currentPage
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      fontWeight: index == widget.currentPage
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String cycleStateShortLabelFor(DailyCommandCycleState state) => switch (state) {
  DailyCommandCycleState.standby => 'IDLE',
  DailyCommandCycleState.active => 'RUN',
  DailyCommandCycleState.reviewReady => 'PASS',
  DailyCommandCycleState.awaitingDebrief => 'WAIT',
  DailyCommandCycleState.finalizeReady => 'READY',
  DailyCommandCycleState.finalizing => 'LOAD',
  DailyCommandCycleState.recoveryRequired => 'ERROR',
};

IconData cycleStateIconFor(DailyCommandCycleState state) => switch (state) {
  DailyCommandCycleState.standby => Icons.radio_button_unchecked,
  DailyCommandCycleState.active => Icons.change_circle,
  DailyCommandCycleState.reviewReady => Icons.task_alt,
  DailyCommandCycleState.awaitingDebrief => Icons.pending_actions,
  DailyCommandCycleState.finalizeReady => Icons.task_alt,
  DailyCommandCycleState.finalizing => Icons.autorenew,
  DailyCommandCycleState.recoveryRequired => Icons.build_circle,
};
