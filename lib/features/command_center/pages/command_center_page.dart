import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../activity/models/activity_summary_state.dart';
import '../../dashboard/widgets/daily_log_card.dart';
import '../../food/models/food_summary_state.dart';
import '../../morning/models/morning_fact_state.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/services/operation_date_service.dart';
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
import '../../report_sync/models/morning_brief_state.dart';
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

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({super.key, this.initialPage = 1});

  final int initialPage;

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  late final PageController _pageController;
  late int _currentPage;
  var _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int page) => _pageController.animateToPage(
    page,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );

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
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                const BriefDebriefPage(),
                _DailyCommandPage(
                  refreshToken: _refreshToken,
                  onRefresh: _refresh,
                ),
                const PeriodicReportWorkspace(),
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

class _DailyCommandPageState extends State<_DailyCommandPage> {
  late Future<OperationLocalDate> _operationDateFuture =
      const OperationDateService().current();
  late Future<({DailyCommandReadModel model, DailyAssessment assessment})>
  _modelFuture = _loadModel();
  late final List<Listenable> _modelSources = [
    morningFactNotifier,
    foodSummaryNotifier,
    trainingSummaryNotifier,
    activitySummaryNotifier,
    morningBriefRevisionNotifier,
  ];
  int _operationDateTransitionToken = 0;
  final ScrollController _scrollController = ScrollController();
  Completer<void>? _dateDisplayedCompleter;
  OperationLocalDate? _expectedDisplayedDate;

  @override
  void initState() {
    super.initState();
    for (final source in _modelSources) {
      source.addListener(_reloadModel);
    }
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
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorContent(onRetry: widget.onRefresh);
          }
          final result = snapshot.requireData;
          return _DailyCommandContent(
            model: result.model,
            assessment: result.assessment,
            operationDateFuture: _operationDateFuture,
            operationDateTransitionToken: _operationDateTransitionToken,
            scrollController: _scrollController,
            onReviewCompleted: _showFinalizeDateTransition,
            onOperationDateDisplayed: _handleOperationDateDisplayed,
          );
        },
      );

  void _reloadModel() {
    if (!mounted || !AppRepositoryRegistry.hasContainer) return;
    setState(() {
      _modelFuture = _loadModel();
    });
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
    final model = DailyCommandReadModelBuilder.build(
      operationState: state,
      status: status,
      food: foodSummaryNotifier.value,
      training: trainingSummaryNotifier.value,
      activity: activitySummaryNotifier.value,
      morningBrief: morningBrief,
      burnWeightKg: burnWeight,
    );
    final facts = await DailyAssessmentFactLoader(
      AppRepositoryRegistry.container,
    ).load(state);
    return (
      model: model,
      assessment: const DailyAssessmentRuleEngine().evaluate(facts),
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
    final dateDisplayedCompleter = Completer<void>();
    _dateDisplayedCompleter = dateDisplayedCompleter;
    _expectedDisplayedDate = previousOperationDate;
    setState(() {
      _operationDateFuture = Future.value(previousOperationDate);
    });
    await _waitUntilCommandCenterIsVisible();
    if (!mounted) return;
    await dateDisplayedCompleter.future;
    if (!mounted) return;
    setState(() {
      _operationDateFuture = Future.value(nextOperationDate);
      _operationDateTransitionToken++;
    });
    await Future<void>.delayed(
      OperationDateFlipCalendar.maximumTransitionDuration,
    );
    if (mounted) await _offerPeriodicReports(previousOperationDate);
    if (mounted) widget.onRefresh();
  }

  Future<void> _offerPeriodicReports(OperationLocalDate finalizedDate) async {
    final date = DateTime.parse(finalizedDate.value);
    final candidates = periodicReportTypesForFinalizedDate(date);
    for (final type in candidates) {
      if (!mounted) return;
      final create = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('CREATE ${type.stableId.toUpperCase()} REPORT?'),
          content: Text(
            'Completed ${type.stableId.toUpperCase()} formal facts are ready.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('NO'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('YES'),
            ),
          ],
        ),
      );
      if (create == true && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                PeriodicReportPage(initialType: type, initialAnchor: date),
          ),
        );
      }
    }
  }

  void _handleOperationDateDisplayed(OperationLocalDate date) {
    final completer = _dateDisplayedCompleter;
    if (date != _expectedDisplayedDate || completer == null) return;
    _dateDisplayedCompleter = null;
    _expectedDisplayedDate = null;
    if (!completer.isCompleted) completer.complete();
  }

  Future<void> _waitUntilCommandCenterIsVisible() async {
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
}

class _DailyCommandContent extends StatelessWidget {
  const _DailyCommandContent({
    required this.model,
    required this.assessment,
    required this.operationDateFuture,
    required this.operationDateTransitionToken,
    required this.scrollController,
    required this.onReviewCompleted,
    required this.onOperationDateDisplayed,
  });

  final DailyCommandReadModel model;
  final DailyAssessment assessment;
  final Future<OperationLocalDate> operationDateFuture;
  final int operationDateTransitionToken;
  final ScrollController scrollController;
  final DailyLogReviewCompleted onReviewCompleted;
  final ValueChanged<OperationLocalDate> onOperationDateDisplayed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('daily-command-list'),
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
          operationDateTransitionToken: operationDateTransitionToken,
          cycleState: model.cycleState,
          onOperationDateDisplayed: onOperationDateDisplayed,
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
          morningFact: morningFactNotifier.value,
          foodSummary: foodSummaryNotifier.value,
          activitySummary: activitySummaryNotifier.value,
          trainingSummary: trainingSummaryNotifier.value,
          estimatedTotalBurn: model.estimatedTotalBurnKcal,
          onReviewCompleted: onReviewCompleted,
        ),
        AppSpacing.gapLG,
      ],
    );
  }
}

class _CurrentOperationCard extends StatelessWidget {
  const _CurrentOperationCard({
    required this.operationDateFuture,
    required this.operationDateTransitionToken,
    required this.cycleState,
    required this.onOperationDateDisplayed,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int operationDateTransitionToken;
  final DailyCommandCycleState cycleState;
  final ValueChanged<OperationLocalDate> onOperationDateDisplayed;

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
            Text(
              'OPERATION DATE',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            AppSpacing.gapSM,
            OperationDateFlipCalendar(
              operationDateFuture: operationDateFuture,
              transitionToken: operationDateTransitionToken,
              onDateDisplayed: onOperationDateDisplayed,
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            key: const ValueKey('current-operation-cycle-group'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'CYCLE STATE',
                maxLines: 1,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              AppSpacing.gapSM,
              Semantics(
                label: 'CYCLE STATE ${cycleStateShortLabelFor(cycleState)}',
                child: SizedBox(
                  key: const ValueKey('current-operation-cycle-value'),
                  width: double.infinity,
                  height: OperationDateFlipCalendar.defaultTileHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cycleStateIconFor(cycleState),
                                key: const ValueKey(
                                  'current-operation-cycle-icon',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                cycleStateShortLabelFor(cycleState),
                                key: const ValueKey(
                                  'current-operation-cycle-label',
                                ),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.currentPage,
    required this.onSelectPage,
  });
  final int currentPage;
  final ValueChanged<int> onSelectPage;
  @override
  Widget build(BuildContext context) {
    const labels = [
      'BRIEF / DEBRIEF',
      'DAILY COMMAND',
      'PERIODIC REPORT',
      'DATA CENTER',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: List.generate(
          labels.length,
          (index) => AnimatedContainer(
            key: ValueKey('command-center-tab-$index'),
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: index == currentPage
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: TextButton(
              onPressed: () => onSelectPage(index),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: index == currentPage
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  fontWeight: index == currentPage ? FontWeight.bold : null,
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
  DailyCommandCycleState.reviewReady => 'DONE',
  DailyCommandCycleState.awaitingDebrief => 'WAIT',
  DailyCommandCycleState.finalizing => 'LOAD',
  DailyCommandCycleState.recoveryRequired => 'ERROR',
};

IconData cycleStateIconFor(DailyCommandCycleState state) => switch (state) {
  DailyCommandCycleState.standby => Icons.radio_button_unchecked,
  DailyCommandCycleState.active => Icons.change_circle,
  DailyCommandCycleState.reviewReady => Icons.task_alt,
  DailyCommandCycleState.awaitingDebrief => Icons.pending_actions,
  DailyCommandCycleState.finalizing => Icons.autorenew,
  DailyCommandCycleState.recoveryRequired => Icons.build_circle,
};
