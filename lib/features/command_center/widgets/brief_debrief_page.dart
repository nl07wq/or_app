import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/state/app_initialization_state.dart';
import '../../../core/services/daily_log_confirmation_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../report_sync/models/morning_brief_record.dart';
import '../../report_sync/models/daily_debrief_record.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/pages/report_sync_exchange_page.dart';
import '../../report_sync/services/report_human_presentation.dart';
import '../../repositories/app_repository_container.dart';
import '../../operation_date/models/operation_state.dart';
import '../../operation_date/models/daily_finalize_result.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/services/daily_finalize_coordinator_factory.dart';
import '../../periodic_report/models/periodic_report.dart';
import '../../periodic_report/pages/periodic_report_page.dart';
import '../services/daily_estimated_total_burn_service.dart';

typedef PrepareDailyDebrief =
    Future<void> Function(String localDate, double? estimatedTotalBurnKcal);

const _backNumberPreviewLimit = 3;

@visibleForTesting
IconData dailyDebriefLifecycleIconForStatus(
  DailyDebriefLifecycleStatus status,
) => switch (status) {
  DailyDebriefLifecycleStatus.active => Icons.verified_outlined,
  DailyDebriefLifecycleStatus.stale => Icons.history,
  DailyDebriefLifecycleStatus.invalidated => Icons.block,
};

@visibleForTesting
String dailyDebriefPresentationIdentity(String localDate, int revision) =>
    revision == 1 ? 'DD-$localDate' : 'DD-$localDate-Rev$revision';

typedef _CommanderIntentOutcomePresentation = ({
  IconData icon,
  Color color,
  String label,
});

_CommanderIntentOutcomePresentation _commanderIntentOutcomePresentation(
  BuildContext context,
  DailyDebriefCommanderIntentOutcome outcome,
) => switch (outcome) {
  DailyDebriefCommanderIntentOutcome.achieved => (
    icon: Icons.check_circle,
    color: Colors.green,
    label: 'GREEN',
  ),
  DailyDebriefCommanderIntentOutcome.partiallyAchieved => (
    icon: Icons.adjust,
    color: Colors.amber,
    label: 'YELLOW',
  ),
  DailyDebriefCommanderIntentOutcome.notAchieved => (
    icon: Icons.cancel,
    color: Theme.of(context).colorScheme.error,
    label: 'RED',
  ),
  DailyDebriefCommanderIntentOutcome.notAssessable => (
    icon: Icons.help_outline,
    color: Theme.of(context).colorScheme.outline,
    label: 'GRAY',
  ),
};

Color _morningBriefBackNumberColor(MorningBriefOperationStatus status) =>
    switch (status) {
      MorningBriefOperationStatus.green => Colors.green,
      MorningBriefOperationStatus.yellow => Colors.amber,
      MorningBriefOperationStatus.red => Colors.red,
    };

class BriefDebriefPage extends StatelessWidget {
  const BriefDebriefPage({
    super.key,
    this.dailyLogSourceLoader = DailyLogConfirmationService.loadSourceSnapshot,
    this.prepareDailyDebrief,
  });

  final Future<DailyLogSourceSnapshot> Function(String localDate)
  dailyLogSourceLoader;
  final PrepareDailyDebrief? prepareDailyDebrief;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SectionHeader(
            icon: Icons.article_outlined,
            title: 'BRIEF / DEBRIEF',
          ),
        ),
        const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'DAILY BRIEF'),
            Tab(text: 'DAILY DEBRIEF'),
            Tab(text: 'WEEKLY'),
            Tab(text: 'MONTHLY'),
            Tab(text: 'YEARLY'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              const _MorningBriefView(),
              _DailyDebriefView(
                sourceLoader: dailyLogSourceLoader,
                prepareDailyDebrief: prepareDailyDebrief,
              ),
              const PeriodicReportPanel(reportType: PeriodicReportType.weekly),
              const PeriodicReportPanel(reportType: PeriodicReportType.monthly),
              const PeriodicReportPanel(reportType: PeriodicReportType.yearly),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MorningBriefView extends StatefulWidget {
  const _MorningBriefView();

  @override
  State<_MorningBriefView> createState() => _MorningBriefViewState();
}

class _MorningBriefViewState extends State<_MorningBriefView> {
  late Future<_MorningBriefData> _data;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<_MorningBriefData> _load() async {
    final records = (await AppRepositoryRegistry.container.morningBriefs.list())
        .toList();
    records.sort((a, b) => b.localDate.compareTo(a.localDate));
    final operationState = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    return _MorningBriefData(
      operationDate: operationState.operationDate.value,
      records: records,
    );
  }

  Future<void> _openSync() async {
    var imported = false;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.morningBrief,
          onApplied: () => imported = true,
        ),
      ),
    );
    if (!mounted || !imported) return;
    _reload();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_MorningBriefData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) return _LoadError(onRetry: _reload);
      final data = snapshot.data!;
      final current = data.current;
      final backNumbers = data.backNumbers;
      return ListView(
        key: const ValueKey('morning-brief-content'),
        controller: _scrollController,
        padding: AppSpacing.cardPadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    icon: Icons.light_mode_outlined,
                    title: 'DAILY BRIEF',
                  ),
                  AppSpacing.gapSM,
                  if (current == null)
                    const OperationCard(child: Text('DAILY BRIEFはまだありません。'))
                  else
                    _MorningBriefCard(record: current),
                  AppSpacing.gapMD,
                  OperationButton(
                    key: const ValueKey('open-morning-brief-report-sync'),
                    text: 'CREATE DAILY BRIEF',
                    icon: Icons.sync,
                    onPressed: appInitializationController.value.isReadOnly
                        ? null
                        : _openSync,
                  ),
                  AppSpacing.gapXL,
                  const SectionHeader(
                    icon: Icons.auto_stories_outlined,
                    title: 'DAILY BRIEF BACK NUMBER',
                  ),
                  AppSpacing.gapSM,
                  _MorningBriefHistory(records: backNumbers),
                  if (backNumbers.length > _backNumberPreviewLimit) ...[
                    AppSpacing.gapSM,
                    _ArchiveButton(
                      key: const ValueKey(
                        'view-all-morning-brief-back-numbers',
                      ),
                      text: 'VIEW ALL BACK NUMBERS',
                      icon: Icons.list_alt,
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _MorningBriefArchivePage(records: backNumbers),
                        ),
                      ),
                    ),
                  ],
                  AppSpacing.gapLG,
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  void _reload() {
    final data = _load();
    setState(() {
      _data = data;
    });
  }
}

class _MorningBriefData {
  const _MorningBriefData({required this.operationDate, required this.records});

  final String operationDate;
  final List<MorningBriefRecord> records;

  MorningBriefRecord? get current {
    for (final record in records) {
      if (record.localDate == operationDate) return record;
    }
    return null;
  }

  List<MorningBriefRecord> get backNumbers => records
      .where((record) => record.localDate != operationDate)
      .toList(growable: false);
}

class _ArchiveButton extends StatelessWidget {
  const _ArchiveButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
    ),
  );
}

class _DailyDebriefView extends StatefulWidget {
  const _DailyDebriefView({
    required this.sourceLoader,
    required this.prepareDailyDebrief,
  });

  final Future<DailyLogSourceSnapshot> Function(String localDate) sourceLoader;
  final PrepareDailyDebrief? prepareDailyDebrief;

  @override
  State<_DailyDebriefView> createState() => _DailyDebriefViewState();
}

class _DailyDebriefViewState extends State<_DailyDebriefView> {
  late Future<_DailyDebriefViewData> _records = _load();
  _DailyDebriefViewData? _loadedData;
  String? _selectedTargetDate;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<_DailyDebriefViewData> _load() async {
    final container = AppRepositoryRegistry.container;
    final records = await container.dailyDebriefs.list();
    final projected = await Future.wait([
      for (final record in records)
        (() async => (
          record: record,
          status: await container.dailyDebriefSources.projectLifecycle(record),
        ))(),
    ]);
    final operationState = await container.operationState.requireCurrent();
    final currentSnapshot = operationState.phase == OperationPhase.open
        ? await widget.sourceLoader(operationState.operationDate.value)
        : null;
    final eligibleDates = await container.dailyDebriefSources.eligibleDates(
      currentOperationDateValidation: currentSnapshot?.validation,
    );
    final defaultTargetDate = await container.dailyDebriefSources
        .defaultEligibleDate(
          currentOperationDateValidation: currentSnapshot?.validation,
        );
    final data = _DailyDebriefViewData(
      records: projected,
      operationState: operationState,
      eligibleDates: eligibleDates,
      defaultTargetDate: defaultTargetDate,
    );
    _loadedData = data;
    _selectedTargetDate ??= defaultTargetDate;
    return data;
  }

  void _refresh() {
    final records = _load();
    if (mounted) {
      setState(() {
        _records = records;
      });
    }
  }

  Future<void> _openCreateFlow() async {
    final data = _loadedData;
    if (data == null || data.eligibleDates.isEmpty) return;
    final selected = _selectedTargetDate;
    if (selected == null) return;
    if ((data.operationState.phase == OperationPhase.open ||
            data.operationState.phase == OperationPhase.awaitingDebrief) &&
        selected == data.operationState.operationDate.value) {
      try {
        final sourceSnapshot = await widget.sourceLoader(selected);
        if (!sourceSnapshot.validation.canFinalize) {
          throw DailyLogValidationException(
            sourceSnapshot.validation.blockingModules,
          );
        }
        final container = AppRepositoryRegistry.container;
        final estimatedTotalBurn = await DailyEstimatedTotalBurnService(
          statusRepository: container.status,
          trainingRepository: container.training,
        ).calculate(selected);
        final prepare = widget.prepareDailyDebrief;
        if (prepare == null) {
          await DailyFinalizeCoordinatorFactory.production()
              .prepareDailyDebrief(
                targetLocalDate: OperationLocalDate.parse(selected),
                estimatedTotalBurnKcal: estimatedTotalBurn,
              );
        } else {
          await prepare(selected, estimatedTotalBurn);
        }
      } on DailyLogValidationException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
        return;
      } on DailyFinalizeException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CREATE DAILY DEBRIEF failed: ${error.code.name}'),
          ),
        );
        return;
      }
      if (!mounted) return;
    }
    var imported = false;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.dailyDebrief,
          initialTargetDate: selected,
          onApplied: () => imported = true,
          onTargetDateChanged: (value) {
            if (mounted) setState(() => _selectedTargetDate = value);
          },
        ),
      ),
    );
    if (!mounted) return;
    _refresh();
    if (imported && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_DailyDebriefViewData>(
    future: _records,
    builder: (context, snapshot) => ListView(
      key: const ValueKey('daily-debrief-content'),
      controller: _scrollController,
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.nightlight_outlined,
          title: 'DAILY DEBRIEF',
        ),
        AppSpacing.gapSM,
        if (snapshot.hasError)
          OperationCard(child: Text('LOAD FAILED: ${snapshot.error}'))
        else if (!snapshot.hasData)
          const Center(child: CircularProgressIndicator())
        else if (snapshot.data!.current == null)
          const OperationCard(child: Text('DAILY DEBRIEFはまだありません。'))
        else
          _DailyDebriefDetail(
            key: const ValueKey('current-daily-debrief'),
            record: snapshot.data!.current!.record,
            status: snapshot.data!.current!.status,
            includeAuditSections: false,
          ),
        AppSpacing.gapMD,
        _DailyDebriefCreateButton(
          key: const ValueKey('open-daily-debrief-report-sync'),
          onPressed:
              appInitializationController.value.isReadOnly ||
                  snapshot.data?.defaultTargetDate == null
              ? null
              : _openCreateFlow,
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.auto_stories_outlined,
          title: 'DAILY DEBRIEF BACK NUMBER',
        ),
        AppSpacing.gapSM,
        if (snapshot.hasError)
          OperationCard(child: Text('LOAD FAILED: ${snapshot.error}'))
        else if (!snapshot.hasData)
          const Center(child: CircularProgressIndicator())
        else if (snapshot.data!.backNumbers.isEmpty)
          const OperationCard(child: Text('NO DAILY DEBRIEF BACK NUMBER'))
        else ...[
          _DailyDebriefHistory(
            records: snapshot.data!.backNumbers
                .take(_backNumberPreviewLimit)
                .toList(growable: false),
          ),
          if (snapshot.data!.backNumbers.length > _backNumberPreviewLimit) ...[
            AppSpacing.gapSM,
            _ArchiveButton(
              key: const ValueKey('view-all-daily-debrief-back-numbers'),
              text: 'VIEW ALL BACK NUMBERS',
              icon: Icons.list_alt,
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => _DailyDebriefArchivePage(
                    records: snapshot.data!.backNumbers,
                  ),
                ),
              ),
            ),
          ],
        ],
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _DailyDebriefViewData {
  const _DailyDebriefViewData({
    required this.records,
    required this.operationState,
    required this.eligibleDates,
    required this.defaultTargetDate,
  });

  final List<({DailyDebriefRecord record, DailyDebriefLifecycleStatus status})>
  records;
  final OperationState operationState;
  final List<String> eligibleDates;
  final String? defaultTargetDate;

  ({DailyDebriefRecord record, DailyDebriefLifecycleStatus status})?
  get current {
    for (final value in records) {
      if (value.record.localDate == operationState.operationDate.value) {
        return value;
      }
    }
    return null;
  }

  List<({DailyDebriefRecord record, DailyDebriefLifecycleStatus status})>
  get backNumbers => records
      .where(
        (value) => value.record.localDate != operationState.operationDate.value,
      )
      .toList(growable: false);
}

class _DailyDebriefDetailPage extends StatelessWidget {
  const _DailyDebriefDetailPage({required this.record, required this.status});

  final DailyDebriefRecord record;
  final DailyDebriefLifecycleStatus status;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DAILY DEBRIEF')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [_DailyDebriefDetail(record: record, status: status)],
    ),
  );
}

class _DailyDebriefDetail extends StatelessWidget {
  const _DailyDebriefDetail({
    super.key,
    required this.record,
    required this.status,
    this.includeAuditSections = true,
  });

  final DailyDebriefRecord record;
  final DailyDebriefLifecycleStatus status;
  final bool includeAuditSections;

  @override
  Widget build(BuildContext context) {
    final analysis = record.analysis;
    final sections = <Widget>[
      if (_hasDomainEvaluations(analysis.domainEvaluations))
        _DomainEvaluationsSection(evaluations: analysis.domainEvaluations),
      if (analysis.commanderIntentEvaluation != null)
        _CommanderIntentEvaluationSection(
          evaluation: analysis.commanderIntentEvaluation!,
        ),
      if (analysis.executionEvaluation.successes.isNotEmpty ||
          analysis.executionEvaluation.adjustments.isNotEmpty)
        _DebriefGroupedSection(
          key: const ValueKey('daily-debrief-panel-execution-evaluation'),
          icon: Icons.checklist_outlined,
          title: 'EXECUTION EVALUATION',
          tone: _DebriefPanelTone.secondary,
          groups: [
            ('SUCCESSES', analysis.executionEvaluation.successes),
            ('ADJUSTMENTS', analysis.executionEvaluation.adjustments),
          ],
        ),
      if (analysis.crossAnalysis.keyFactors.isNotEmpty ||
          analysis.crossAnalysis.interactions.isNotEmpty ||
          analysis.crossAnalysis.constraints.isNotEmpty ||
          analysis.crossAnalysis.resources.isNotEmpty)
        _DebriefGroupedSection(
          key: const ValueKey('daily-debrief-panel-cross-analysis'),
          icon: Icons.hub_outlined,
          title: 'CROSS ANALYSIS',
          tone: _DebriefPanelTone.neutral,
          groups: [
            ('KEY FACTORS', analysis.crossAnalysis.keyFactors),
            ('INTERACTIONS', analysis.crossAnalysis.interactions),
            ('CONSTRAINTS', analysis.crossAnalysis.constraints),
            ('RESOURCES', analysis.crossAnalysis.resources),
          ],
        ),
      if (analysis.nextDayHandoff.watchPoints.isNotEmpty)
        _DebriefGroupedSection(
          key: const ValueKey('daily-debrief-panel-next-day-handoff'),
          icon: Icons.visibility_outlined,
          title: 'NEXT-DAY HANDOFF',
          tone: _DebriefPanelTone.subtle,
          groups: [('WATCH POINTS', analysis.nextDayHandoff.watchPoints)],
        ),
      if (includeAuditSections)
        _PreviousRevisionsSection(
          values: record.previousRevisions.isEmpty
              ? const ['NONE']
              : [
                  for (final revision in record.previousRevisions)
                    'REVISION ${revision.revision}  ${revision.createdAt.toLocal()}',
                ],
        ),
    ];
    return OperationCard(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DailyDebriefHeader(record: record, status: status),
              for (var index = 0; index < sections.length; index++) ...[
                const SizedBox(height: 24),
                sections[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasDomainEvaluations(DailyDebriefDomainEvaluations evaluations) =>
    evaluations.body != null ||
    evaluations.recovery != null ||
    evaluations.condition != null ||
    evaluations.work != null ||
    evaluations.nutrition != null ||
    evaluations.hydration != null ||
    evaluations.activity != null ||
    evaluations.training != null;

class _DailyDebriefHeader extends StatelessWidget {
  const _DailyDebriefHeader({required this.record, required this.status});

  final DailyDebriefRecord record;
  final DailyDebriefLifecycleStatus status;

  @override
  Widget build(BuildContext context) {
    final outcome = record.analysis.commanderIntentEvaluation?.outcome;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.nightlight_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          AppSpacing.gapSM,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY DEBRIEF',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        dailyDebriefPresentationIdentity(
                          record.localDate,
                          record.revision,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      dailyDebriefLifecycleIconForStatus(status),
                      key: ValueKey('daily-debrief-lifecycle-${status.name}'),
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (outcome != null) ...[
                  const SizedBox(height: 8),
                  _CommanderIntentOutcomeIndicator(
                    outcome: outcome,
                    keyPrefix: 'daily-debrief-header-outcome',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommanderIntentEvaluationSection extends StatelessWidget {
  const _CommanderIntentEvaluationSection({required this.evaluation});

  final DailyDebriefCommanderIntentEvaluation evaluation;

  @override
  Widget build(BuildContext context) => _DebriefPanel(
    key: const ValueKey('daily-debrief-panel-commander-intent'),
    tone: _DebriefPanelTone.primary,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BriefSectionTitle(
          icon: Icons.flag_outlined,
          title: 'COMMANDER INTENT EVALUATION',
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(height: 16),
        _CommanderIntentOutcomeIndicator(outcome: evaluation.outcome),
        const SizedBox(height: 18),
        _DebriefSubsectionLabel(
          '評価理由',
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        const SizedBox(height: 8),
        _ReadableText(
          evaluation.rationale,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        if (evaluation.evidence.isNotEmpty) ...[
          const SizedBox(height: 18),
          _DebriefSubsectionLabel(
            '判定根拠',
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 8),
          _DebriefBulletList(
            values: evaluation.evidence,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ],
      ],
    ),
  );
}

class _CommanderIntentOutcomeIndicator extends StatelessWidget {
  const _CommanderIntentOutcomeIndicator({
    required this.outcome,
    this.keyPrefix = 'daily-debrief-outcome',
  });

  final DailyDebriefCommanderIntentOutcome outcome;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final presentation = _commanderIntentOutcomePresentation(context, outcome);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            presentation.icon,
            key: ValueKey('$keyPrefix-${outcome.name}'),
            size: 30,
            color: presentation.color,
          ),
          const SizedBox(width: 8),
          Text(
            presentation.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: presentation.color,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebriefGroupedSection extends StatelessWidget {
  const _DebriefGroupedSection({
    super.key,
    required this.icon,
    required this.title,
    required this.tone,
    required this.groups,
  });

  final IconData icon;
  final String title;
  final _DebriefPanelTone tone;
  final List<(String, List<String>)> groups;

  @override
  Widget build(BuildContext context) {
    final visibleGroups = groups
        .where((group) => group.$2.isNotEmpty)
        .toList(growable: false);
    if (visibleGroups.isEmpty) return const SizedBox.shrink();
    return _DebriefPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BriefSectionTitle(icon: icon, title: title),
          const SizedBox(height: 16),
          for (var index = 0; index < visibleGroups.length; index++) ...[
            _DebriefListGroup(
              label: visibleGroups[index].$1,
              values: visibleGroups[index].$2,
            ),
            if (index != visibleGroups.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _DebriefListGroup extends StatelessWidget {
  const _DebriefListGroup({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) => values.isEmpty
      ? const SizedBox.shrink()
      : Column(
          key: ValueKey(
            'daily-debrief-group-${label.toLowerCase().replaceAll(' ', '-')}',
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DebriefSubsectionLabel(label),
            const SizedBox(height: 8),
            _DebriefBulletList(values: values),
          ],
        );
}

class _DebriefBulletList extends StatelessWidget {
  const _DebriefBulletList({required this.values, this.color});

  final List<String> values;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < values.length; index++)
        Padding(
          padding: EdgeInsets.only(bottom: index == values.length - 1 ? 0 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '•',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: _ReadableText(values[index], color: color)),
            ],
          ),
        ),
    ],
  );
}

class _DomainEvaluationsSection extends StatelessWidget {
  const _DomainEvaluationsSection({required this.evaluations});

  final DailyDebriefDomainEvaluations evaluations;

  @override
  Widget build(BuildContext context) {
    final domains = <(String, IconData, String?)>[
      ('BODY', Icons.monitor_weight_outlined, evaluations.body),
      ('RECOVERY', Icons.bedtime_outlined, evaluations.recovery),
      ('CONDITION', Symbols.barefoot, evaluations.condition),
      (
        'WORK',
        Icons.work_outline,
        evaluations.work == null
            ? null
            : ReportHumanPresentation.workText(evaluations.work!),
      ),
      ('NUTRITION', Icons.restaurant_outlined, evaluations.nutrition),
      ('HYDRATION', Icons.water_drop_outlined, evaluations.hydration),
      ('ACTIVITY', Icons.directions_walk_outlined, evaluations.activity),
      ('TRAINING', Icons.fitness_center_outlined, evaluations.training),
    ].where((domain) => domain.$3 != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BriefSectionTitle(
          icon: Icons.analytics_outlined,
          title: 'DOMAIN EVALUATIONS',
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < domains.length; index++) ...[
          _AnalysisBlock(
            key: ValueKey(
              'daily-debrief-domain-${domains[index].$1.toLowerCase()}',
            ),
            icon: domains[index].$2,
            title: domains[index].$1,
            body: domains[index].$3!,
            display: null,
            showDivider: index != domains.length - 1,
          ),
        ],
      ],
    );
  }
}

enum _DebriefPanelTone { primary, secondary, neutral, subtle }

class _DebriefPanel extends StatelessWidget {
  const _DebriefPanel({
    super.key,
    required this.child,
    required this.tone,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final _DebriefPanelTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: switch (tone) {
          _DebriefPanelTone.primary => colors.primaryContainer,
          _DebriefPanelTone.secondary => colors.secondaryContainer.withValues(
            alpha: 0.55,
          ),
          _DebriefPanelTone.neutral => colors.surfaceContainerLow,
          _DebriefPanelTone.subtle => colors.surfaceContainerHighest,
        },
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _DebriefSubsectionLabel extends StatelessWidget {
  const _DebriefSubsectionLabel(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: color,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
    ),
  );
}

class _PreviousRevisionsSection extends StatelessWidget {
  const _PreviousRevisionsSection({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('daily-debrief-previous-revisions'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _BriefSectionTitle(
        icon: Icons.history_outlined,
        title: 'PREVIOUS REVISIONS',
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < values.length; index++)
        Padding(
          padding: EdgeInsets.only(bottom: index == values.length - 1 ? 0 : 8),
          child: SelectableText(values[index]),
        ),
    ],
  );
}

class _MorningBriefCard extends StatelessWidget {
  const _MorningBriefCard({
    required this.record,
    this.revisionOverride,
    this.showRevisionHistory = true,
  });
  final MorningBriefRecord record;
  final int? revisionOverride;
  final bool showRevisionHistory;

  @override
  Widget build(BuildContext context) {
    final analysis = record.situationAnalysisV2;
    final decision = record.strategicResourceDecisionV2;
    return OperationCard(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BriefHeader(
                record: record,
                revision: revisionOverride ?? record.revision,
              ),
              const SizedBox(height: 28),
              if (analysis == null)
                _BriefSection(
                  icon: Icons.analytics_outlined,
                  title: 'SITUATION ANALYSIS',
                  body: record.situationAnalysis,
                )
              else
                _SituationAnalysisSection(analysis: analysis),
              const SizedBox(height: 8),
              _OperationStatusSection(
                status: record.operationStatus,
                reason: analysis?.overall,
              ),
              const SizedBox(height: 24),
              if (record.operatingPolicy != null)
                _BriefSection(
                  icon: Icons.route_outlined,
                  title: 'OPERATING POLICY',
                  body: record.operatingPolicy!,
                  emphasized: true,
                )
              else if (record.argoComment != null)
                _BriefSection(
                  icon: Icons.psychology_outlined,
                  title: 'ARGO COMMENT',
                  body: record.argoComment!,
                  emphasized: true,
                ),
              const SizedBox(height: 8),
              if (decision == null)
                _BriefSection(
                  icon: Icons.track_changes_outlined,
                  title: 'STRATEGIC RESOURCE DECISION',
                  body: record.strategicResourceDecision,
                )
              else
                _StrategicResourceSection(decision: decision),
              const SizedBox(height: 8),
              _CommanderIntentBlock(text: record.commanderIntent),
              const SizedBox(height: 24),
              _TodayActions(actions: record.actions),
              if (showRevisionHistory &&
                  record.previousRevisions.isNotEmpty) ...[
                const SizedBox(height: 24),
                _MorningBriefRevisionHistory(
                  revisions: record.previousRevisions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefHeader extends StatelessWidget {
  const _BriefHeader({required this.record, required this.revision});

  final MorningBriefRecord record;
  final int revision;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.light_mode_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY BRIEF',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MB-${record.localDate}-Rev$revision',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              _OperationStatusLamp(status: record.operationStatus),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            _OperationStatusLamp(status: record.operationStatus),
          ],
        );
      },
    ),
  );
}

class _MorningBriefRevisionHistory extends StatelessWidget {
  const _MorningBriefRevisionHistory({required this.revisions});

  final List<MorningBriefRevision> revisions;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('morning-brief-previous-revisions'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _BriefSectionTitle(
        icon: Icons.history_outlined,
        title: 'PREVIOUS REVISIONS',
      ),
      const SizedBox(height: 12),
      for (final revision in revisions)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('REV ${revision.revision}'),
          subtitle: Text(
            revision.record.commanderIntent,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: Text('DAILY BRIEF REV ${revision.revision}'),
                ),
                body: ListView(
                  padding: AppSpacing.cardPadding,
                  children: [
                    _MorningBriefCard(
                      record: revision.record,
                      revisionOverride: revision.revision,
                      showRevisionHistory: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _SituationAnalysisSection extends StatelessWidget {
  const _SituationAnalysisSection({required this.analysis});

  final MorningBriefSituationAnalysis analysis;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BriefSectionTitle(
        icon: Icons.analytics_outlined,
        title: 'SITUATION ANALYSIS',
      ),
      const SizedBox(height: 12),
      _AnalysisBlock(
        icon: Icons.monitor_weight_outlined,
        title: 'BODY',
        body: analysis.body,
        display: analysis.bodyDisplay,
      ),
      _AnalysisBlock(
        icon: Icons.bedtime_outlined,
        title: 'RECOVERY',
        body: analysis.recovery,
        display: analysis.recoveryDisplay,
      ),
      _AnalysisBlock(
        icon: Symbols.barefoot,
        title: 'CONDITION',
        body: analysis.condition,
        display: analysis.conditionDisplay,
      ),
      _AnalysisBlock(
        icon: Icons.work_outline,
        title: 'WORK',
        body: ReportHumanPresentation.workText(analysis.work),
        display: ReportHumanPresentation.workDisplay(
          analysis.workDisplay,
          analysis.work,
        ),
        showDivider: false,
      ),
    ],
  );
}

class _AnalysisBlock extends StatelessWidget {
  const _AnalysisBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.display,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String body;
  final MorningBriefSectionDisplay? display;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (display == null)
                    _ReadableText(body)
                  else
                    _StructuredAnalysisText(display: display!),
                ],
              ),
            ),
          ],
        ),
      ),
      if (showDivider) const Divider(height: 1),
    ],
  );
}

class _StructuredAnalysisText extends StatelessWidget {
  const _StructuredAnalysisText({required this.display});

  final MorningBriefSectionDisplay display;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ReadableText(display.primaryText),
      if (display.supportingText != null) ...[
        const SizedBox(height: 8),
        _ReadableText(display.supportingText!, supporting: true),
      ],
    ],
  );
}

class _BriefSection extends StatelessWidget {
  const _BriefSection({
    required this.icon,
    required this.title,
    required this.body,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: emphasized
          ? Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.55)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BriefSectionTitle(icon: icon, title: title),
        const SizedBox(height: 12),
        _ReadableText(body),
      ],
    ),
  );
}

class _BriefSectionTitle extends StatelessWidget {
  const _BriefSectionTitle({
    required this.icon,
    required this.title,
    this.color,
  });

  final IconData icon;
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 22,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ],
  );
}

class _ReadableText extends StatelessWidget {
  const _ReadableText(
    this.text, {
    this.emphasized = false,
    this.supporting = false,
    this.color,
  });

  final String text;
  final bool emphasized;
  final bool supporting;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paragraphs = _visualParagraphs(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < paragraphs.length; index++) ...[
          Text(
            paragraphs[index],
            style:
                (supporting
                        ? Theme.of(context).textTheme.bodyMedium
                        : Theme.of(context).textTheme.bodyLarge)
                    ?.copyWith(
                      color: color,
                      height: 1.65,
                      fontSize: emphasized ? 17 : null,
                      fontWeight: emphasized ? FontWeight.w600 : null,
                    ),
          ),
          if (index != paragraphs.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

List<String> _visualParagraphs(String text) {
  final result = <String>[];
  for (final explicitLine in text.split(RegExp(r'\r?\n+'))) {
    final buffer = StringBuffer();
    for (final rune in explicitLine.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(character);
      if ('。！？'.contains(character)) {
        final value = buffer.toString().trim();
        if (value.isNotEmpty) result.add(value);
        buffer.clear();
      }
    }
    final remainder = buffer.toString().trim();
    if (remainder.isNotEmpty) result.add(remainder);
  }
  return result.isEmpty ? [text] : result;
}

class _OperationStatusSection extends StatelessWidget {
  const _OperationStatusSection({required this.status, required this.reason});

  final MorningBriefOperationStatus status;
  final String? reason;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPERATION STATUS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _OperationStatusLamp(status: status, prominent: true),
        if (reason != null) ...[
          const SizedBox(height: 14),
          Text('判定理由', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          _ReadableText(reason!),
        ],
      ],
    ),
  );
}

class _OperationStatusLamp extends StatelessWidget {
  const _OperationStatusLamp({required this.status, this.prominent = false});

  final MorningBriefOperationStatus status;
  final bool prominent;

  Color get _color => switch (status) {
    MorningBriefOperationStatus.green => Colors.green,
    MorningBriefOperationStatus.yellow => Colors.amber,
    MorningBriefOperationStatus.red => Colors.red,
  };

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        key: ValueKey('morning-brief-status-lamp-${status.stableId}'),
        width: prominent ? 20 : 18,
        height: prominent ? 20 : 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
          boxShadow: [
            BoxShadow(color: _color.withValues(alpha: 0.35), blurRadius: 6),
          ],
        ),
      ),
      const SizedBox(width: 9),
      Text(
        status.stableId.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: prominent ? 19 : 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

class _StrategicResourceSection extends StatelessWidget {
  const _StrategicResourceSection({required this.decision});

  final MorningBriefStrategicResourceDecision decision;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BriefSectionTitle(
          icon: Icons.track_changes_outlined,
          title: 'STRATEGIC RESOURCE DECISION',
        ),
        const SizedBox(height: 16),
        _DecisionField(label: '判断', value: decision.decision, prominent: true),
        if (decision.targetResource != null)
          _DecisionField(label: '重点資源', value: decision.targetResource!),
        _DecisionField(label: '理由', value: decision.rationale),
        if (decision.execution != null)
          _DecisionField(
            label: '実行方針',
            value: decision.execution!,
            prominent: true,
          ),
      ],
    ),
  );
}

class _DecisionField extends StatelessWidget {
  const _DecisionField({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        _ReadableText(value, emphasized: prominent),
      ],
    ),
  );
}

class _CommanderIntentBlock extends StatelessWidget {
  const _CommanderIntentBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'COMMANDER INTENT',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ReadableText(text, emphasized: true),
      ],
    ),
  );
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final normalized = priority.toLowerCase();
    final color = switch (normalized) {
      'critical' => Colors.red.shade800,
      'high' => Colors.deepOrange,
      'medium' => Colors.amber.shade800,
      'low' => Colors.blue,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Chip(
      label: Text(priority.toUpperCase()),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _TodayActions extends StatelessWidget {
  const _TodayActions({required this.actions});

  final List<MorningBriefAction> actions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _BriefSectionTitle(
        icon: Icons.checklist_outlined,
        title: 'TODAY’S ACTION',
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < actions.length; index++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _ReadableText(actions[index].text)),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: _PriorityChip(priority: actions[index].priority),
              ),
            ],
          ),
        ),
    ],
  );
}

class _MorningBriefHistory extends StatelessWidget {
  const _MorningBriefHistory({required this.records});
  final List<MorningBriefRecord> records;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: records.isEmpty
        ? const Row(
            children: [
              Icon(Icons.auto_stories_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('BACK NUMBERはありません')),
            ],
          )
        : Column(
            children: [
              for (
                var index = 0;
                index < records.take(_backNumberPreviewLimit).length;
                index++
              ) ...[
                _BackNumberRow(
                  key: ValueKey(
                    'morning-brief-back-number-${records[index].localDate}',
                  ),
                  date: records[index].localDate,
                  preview: records[index].commanderIntent,
                  indicatorColor: _morningBriefBackNumberColor(
                    records[index].operationStatus,
                  ),
                  onTap: () => _openMorningBriefDetail(context, records[index]),
                ),
                if (index != records.take(_backNumberPreviewLimit).length - 1)
                  const Divider(),
              ],
            ],
          ),
  );
}

class _DailyDebriefHistory extends StatelessWidget {
  const _DailyDebriefHistory({required this.records});

  final List<({DailyDebriefRecord record, DailyDebriefLifecycleStatus status})>
  records;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      children: [
        for (var index = 0; index < records.length; index++) ...[
          _DailyDebriefBackNumberRow(
            key: ValueKey(
              'daily-debrief-history-${records[index].record.localDate}',
            ),
            historical: records[index],
          ),
          if (index != records.length - 1) const Divider(),
        ],
      ],
    ),
  );
}

class _DailyDebriefBackNumberRow extends StatelessWidget {
  const _DailyDebriefBackNumberRow({super.key, required this.historical});

  final ({DailyDebriefRecord record, DailyDebriefLifecycleStatus status})
  historical;

  @override
  Widget build(BuildContext context) {
    final evaluation = historical.record.analysis.commanderIntentEvaluation;
    final preview = evaluation?.rationale.trim();
    return _BackNumberRow(
      date: historical.record.localDate,
      preview: preview == null || preview.isEmpty ? null : preview,
      indicatorColor: evaluation == null
          ? null
          : _commanderIntentOutcomePresentation(
              context,
              evaluation.outcome,
            ).color,
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => _DailyDebriefDetailPage(
            record: historical.record,
            status: historical.status,
          ),
        ),
      ),
    );
  }
}

class _BackNumberRow extends StatelessWidget {
  const _BackNumberRow({
    super.key,
    required this.date,
    required this.preview,
    required this.indicatorColor,
    required this.onTap,
  });

  final String date;
  final String? preview;
  final Color? indicatorColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: _BackNumberLeading(indicatorColor: indicatorColor),
    title: Text(date),
    subtitle: preview == null
        ? null
        : Text(preview!, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _BackNumberLeading extends StatelessWidget {
  const _BackNumberLeading({required this.indicatorColor});

  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 34,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.description_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        if (indicatorColor != null)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              key: const ValueKey('back-number-outcome-dot'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: indicatorColor,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

void _openMorningBriefDetail(BuildContext context, MorningBriefRecord record) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => _MorningBriefDetailPage(record: record)),
  );
}

class _MorningBriefDetailPage extends StatelessWidget {
  const _MorningBriefDetailPage({required this.record});

  final MorningBriefRecord record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DAILY BRIEF')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [_MorningBriefCard(record: record)],
    ),
  );
}

class _MorningBriefArchivePage extends StatelessWidget {
  const _MorningBriefArchivePage({required this.records});

  final List<MorningBriefRecord> records;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DAILY BRIEF BACK NUMBER')),
    body: ListView.separated(
      padding: AppSpacing.cardPadding,
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) => ListTile(
        key: ValueKey(
          'all-morning-brief-back-number-${records[index].localDate}',
        ),
        leading: _BackNumberLeading(
          indicatorColor: _morningBriefBackNumberColor(
            records[index].operationStatus,
          ),
        ),
        title: Text(records[index].localDate),
        subtitle: Text(
          records[index].commanderIntent,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openMorningBriefDetail(context, records[index]),
      ),
    ),
  );
}

class _DailyDebriefArchivePage extends StatelessWidget {
  const _DailyDebriefArchivePage({required this.records});

  final List<({DailyDebriefRecord record, DailyDebriefLifecycleStatus status})>
  records;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DAILY DEBRIEF BACK NUMBER')),
    body: ListView.separated(
      padding: AppSpacing.cardPadding,
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) => _DailyDebriefBackNumberRow(
        key: ValueKey(
          'all-daily-debrief-back-number-${records[index].record.localDate}',
        ),
        historical: records[index],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: OperationButton(
      text: 'RETRY',
      icon: Icons.refresh,
      onPressed: onRetry,
    ),
  );
}

class _DailyDebriefCreateButton extends StatelessWidget {
  const _DailyDebriefCreateButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 320;
      final button = OperationButton(
        text: 'CREATE DAILY DEBRIEF',
        icon: isCompact ? null : Icons.add_circle_outline,
        onPressed: onPressed,
      );
      if (!isCompact) return button;
      return Theme(
        data: Theme.of(context).copyWith(
          elevatedButtonTheme: const ElevatedButtonThemeData(
            style: ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
            ),
          ),
        ),
        child: button,
      );
    },
  );
}
