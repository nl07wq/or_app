import 'package:flutter/material.dart';

import '../../../core/state/app_initialization_state.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/daily_log_confirmation_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../report_sync/models/morning_brief_record.dart';
import '../../report_sync/models/daily_debrief_record.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/pages/report_sync_exchange_page.dart';
import '../../repositories/app_repository_container.dart';
import '../../operation_date/models/operation_state.dart';
import '../../dashboard/log_confirmation_review_page.dart';
import '../services/daily_estimated_total_burn_service.dart';

class BriefDebriefPage extends StatelessWidget {
  const BriefDebriefPage({
    super.key,
    this.dailyLogSourceLoader = DailyLogConfirmationService.loadSourceSnapshot,
  });

  final Future<DailyLogSourceSnapshot> Function(String localDate)
  dailyLogSourceLoader;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
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
          tabs: [
            Tab(text: 'DAILY BRIEF'),
            Tab(text: 'DAILY DEBRIEF'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              const _MorningBriefView(),
              _DailyDebriefView(sourceLoader: dailyLogSourceLoader),
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

  @override
  void initState() {
    super.initState();
    _data = _load();
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.morningBrief,
        ),
      ),
    );
    if (mounted) _reload();
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
                  if (backNumbers.isNotEmpty) ...[
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
  const _DailyDebriefView({required this.sourceLoader});

  final Future<DailyLogSourceSnapshot> Function(String localDate) sourceLoader;

  @override
  State<_DailyDebriefView> createState() => _DailyDebriefViewState();
}

class _DailyDebriefViewState extends State<_DailyDebriefView> {
  late Future<_DailyDebriefViewData> _records = _load();
  _DailyDebriefViewData? _loadedData;
  String? _selectedTargetDate;

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
    if (data.operationState.phase == OperationPhase.open &&
        selected == data.operationState.operationDate.value) {
      final sourceSnapshot = await widget.sourceLoader(selected);
      final container = AppRepositoryRegistry.container;
      final estimatedTotalBurn = await DailyEstimatedTotalBurnService(
        statusRepository: container.status,
        trainingRepository: container.training,
      ).calculate(selected);
      if (!mounted) return;
      final changed = await Navigator.pushNamed(
        context,
        AppRoutes.logConfirmationReview,
        arguments: LogConfirmationReviewPage(
          morning: sourceSnapshot.morning,
          food: sourceSnapshot.food,
          activity: sourceSnapshot.activity,
          training: sourceSnapshot.training,
          estimatedTotalBurn: estimatedTotalBurn,
          targetDate: DateTime.parse(selected),
        ),
      );
      if (changed != true || !mounted) return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.dailyDebrief,
          initialTargetDate: selected,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _selectTargetDate(_DailyDebriefViewData data) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('ELIGIBLE DATE'),
        children: [
          for (final date in data.eligibleDates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, date),
              child: Text(date),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedTargetDate = selected);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_DailyDebriefViewData>(
    future: _records,
    builder: (context, snapshot) => ListView(
      key: const ValueKey('daily-debrief-content'),
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
        else if (snapshot.data!.records.isEmpty)
          const OperationCard(child: Text('DAILY DEBRIEFはまだありません。'))
        else
          _DailyDebriefDetail(
            key: const ValueKey('current-daily-debrief'),
            record: snapshot.data!.records.first.record,
            status: snapshot.data!.records.first.status,
            includeAuditSections: false,
          ),
        AppSpacing.gapMD,
        if (snapshot.hasData) ...[
          OutlinedButton.icon(
            key: const ValueKey('daily-debrief-target-date'),
            onPressed: snapshot.data!.eligibleDates.isEmpty
                ? null
                : () => _selectTargetDate(snapshot.data!),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(_selectedTargetDate ?? 'SELECT ELIGIBLE DATE'),
          ),
          AppSpacing.gapSM,
        ],
        OperationButton(
          key: const ValueKey('open-daily-debrief-report-sync'),
          text: 'CREATE DAILY DEBRIEF',
          icon: Icons.add_circle_outline,
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
        else if (snapshot.data!.records.length <= 1)
          const OperationCard(child: Text('NO DAILY DEBRIEF BACK NUMBER'))
        else
          OperationCard(
            child: Column(
              children: [
                for (
                  var index = 1;
                  index < snapshot.data!.records.length;
                  index++
                ) ...[
                  ListTile(
                    key: ValueKey(
                      'daily-debrief-history-${snapshot.data!.records[index].record.localDate}',
                    ),
                    leading: const Icon(Icons.nightlight_outlined),
                    title: Text(
                      'OPERATION DATE  ${snapshot.data!.records[index].record.localDate}',
                    ),
                    subtitle: Text(
                      'REVISION  ${snapshot.data!.records[index].record.revision}  '
                      'STATUS  ${snapshot.data!.records[index].status.name.toUpperCase()}\n'
                      'IMPORTED AT  ${snapshot.data!.records[index].record.updatedAt.toLocal()}',
                    ),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _DailyDebriefDetailPage(
                          record: snapshot.data!.records[index].record,
                          status: snapshot.data!.records[index].status,
                        ),
                      ),
                    ),
                  ),
                  if (index != snapshot.data!.records.length - 1)
                    const Divider(),
                ],
              ],
            ),
          ),
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
    return OperationCard(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DailyDebriefHeader(record: record, status: status),
              const SizedBox(height: 28),
              _CommanderIntentEvaluationSection(
                evaluation: analysis.commanderIntentEvaluation,
              ),
              const _DailyDebriefMajorDivider(),
              _DebriefListSection(
                icon: Icons.checklist_outlined,
                title: 'EXECUTION EVALUATION',
                groups: [
                  ('SUCCESSES', analysis.executionEvaluation.successes),
                  ('ADJUSTMENTS', analysis.executionEvaluation.adjustments),
                ],
              ),
              const _DailyDebriefMajorDivider(),
              _DebriefListSection(
                icon: Icons.hub_outlined,
                title: 'CROSS ANALYSIS',
                groups: [
                  ('KEY FACTORS', analysis.crossAnalysis.keyFactors),
                  ('INTERACTIONS', analysis.crossAnalysis.interactions),
                  ('CONSTRAINTS', analysis.crossAnalysis.constraints),
                  ('RESOURCES', analysis.crossAnalysis.resources),
                ],
              ),
              const _DailyDebriefMajorDivider(),
              _DomainEvaluationsSection(
                evaluations: analysis.domainEvaluations,
              ),
              const _DailyDebriefMajorDivider(),
              _DebriefListSection(
                icon: Icons.visibility_outlined,
                title: 'NEXT-DAY HANDOFF',
                groups: [('WATCH POINTS', analysis.nextDayHandoff.watchPoints)],
              ),
              if (includeAuditSections) ...[
                const SizedBox(height: 24),
                _DebriefAuditSection(
                  title: 'SOURCE REFERENCES',
                  values: [
                    'DAILY AGGREGATE  ${record.sources.dailyAggregate.recordDigest}',
                    'CONFIRMATION  ${record.sources.confirmation.recordDigest}',
                    'MORNING BRIEF  '
                        '${record.sources.morningBrief?.recordDigest ?? 'NOT RECORDED'}',
                  ],
                ),
                const SizedBox(height: 16),
                _DebriefAuditSection(
                  title: 'PREVIOUS REVISIONS',
                  values: record.previousRevisions.isEmpty
                      ? const ['NONE']
                      : [
                          for (final revision in record.previousRevisions)
                            'REVISION ${revision.revision}  ${revision.createdAt.toLocal()}',
                        ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyDebriefHeader extends StatelessWidget {
  const _DailyDebriefHeader({required this.record, required this.status});

  final DailyDebriefRecord record;
  final DailyDebriefLifecycleStatus status;

  @override
  Widget build(BuildContext context) => Container(
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
              Text('DD-${record.localDate}'),
              Text(
                '${status.name.toUpperCase()}  ·  REVISION ${record.revision}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CommanderIntentEvaluationSection extends StatelessWidget {
  const _CommanderIntentEvaluationSection({required this.evaluation});

  final DailyDebriefCommanderIntentEvaluation? evaluation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _BriefSectionTitle(
        icon: Icons.flag_outlined,
        title: 'COMMANDER INTENT EVALUATION',
      ),
      const SizedBox(height: 16),
      if (evaluation == null)
        const _DebriefMetadata(text: 'NOT RECORDED')
      else ...[
        _CommanderIntentOutcomeIndicator(outcome: evaluation!.outcome),
        const SizedBox(height: 18),
        const _DebriefSubsectionLabel('評価理由'),
        const SizedBox(height: 8),
        _ReadableText(evaluation!.rationale),
        const SizedBox(height: 18),
        _DebriefListGroup(label: '判定根拠', values: evaluation!.evidence),
      ],
    ],
  );
}

class _CommanderIntentOutcomeIndicator extends StatelessWidget {
  const _CommanderIntentOutcomeIndicator({required this.outcome});

  final DailyDebriefCommanderIntentOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (outcome) {
      DailyDebriefCommanderIntentOutcome.achieved => (
        Icons.check_circle,
        Colors.green,
      ),
      DailyDebriefCommanderIntentOutcome.partiallyAchieved => (
        Icons.adjust,
        Colors.amber,
      ),
      DailyDebriefCommanderIntentOutcome.notAchieved => (
        Icons.cancel,
        Theme.of(context).colorScheme.error,
      ),
      DailyDebriefCommanderIntentOutcome.notAssessable => (
        Icons.help_outline,
        Theme.of(context).colorScheme.outline,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Icon(
        icon,
        key: ValueKey('daily-debrief-outcome-${outcome.name}'),
        size: 30,
        color: color,
      ),
    );
  }
}

class _DailyDebriefMajorDivider extends StatelessWidget {
  const _DailyDebriefMajorDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Divider(height: 1),
  );
}

class _DebriefListSection extends StatelessWidget {
  const _DebriefListSection({
    required this.icon,
    required this.title,
    required this.groups,
  });

  final IconData icon;
  final String title;
  final List<(String, List<String>)> groups;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BriefSectionTitle(icon: icon, title: title),
      const SizedBox(height: 16),
      for (var index = 0; index < groups.length; index++) ...[
        _DebriefListGroup(label: groups[index].$1, values: groups[index].$2),
        if (index != groups.length - 1) const SizedBox(height: 18),
      ],
    ],
  );
}

class _DebriefListGroup extends StatelessWidget {
  const _DebriefListGroup({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DebriefSubsectionLabel(label),
      if (values.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(width: 10),
                Expanded(child: _ReadableText(value)),
              ],
            ),
          ),
      ],
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
      ('CONDITION', Icons.health_and_safety_outlined, evaluations.condition),
      ('WORK', Icons.work_outline, evaluations.work),
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
        const SizedBox(height: 8),
        for (var index = 0; index < domains.length; index++)
          _DebriefDomainBlock(
            icon: domains[index].$2,
            title: domains[index].$1,
            body: domains[index].$3!,
            showDivider: index != domains.length - 1,
          ),
      ],
    );
  }
}

class _DebriefDomainBlock extends StatelessWidget {
  const _DebriefDomainBlock({
    required this.icon,
    required this.title,
    required this.body,
    required this.showDivider,
  });

  final IconData icon;
  final String title;
  final String body;
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
                  _DebriefSubsectionLabel(title),
                  const SizedBox(height: 8),
                  _ReadableText(body),
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

class _DebriefSubsectionLabel extends StatelessWidget {
  const _DebriefSubsectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
    ),
  );
}

class _DebriefMetadata extends StatelessWidget {
  const _DebriefMetadata({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);
}

class _DebriefAuditSection extends StatelessWidget {
  const _DebriefAuditSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        AppSpacing.gapSM,
        for (final value in values) SelectableText(value),
      ],
    ),
  );
}

class _MorningBriefCard extends StatelessWidget {
  const _MorningBriefCard({required this.record});
  final MorningBriefRecord record;

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
              _BriefHeader(record: record),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefHeader extends StatelessWidget {
  const _BriefHeader({required this.record});

  final MorningBriefRecord record;

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
                    'MB-${record.localDate}',
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
        icon: Icons.health_and_safety_outlined,
        title: 'CONDITION',
        body: analysis.condition,
        display: analysis.conditionDisplay,
      ),
      _AnalysisBlock(
        icon: Icons.work_outline,
        title: 'WORK',
        body: analysis.work,
        display: analysis.workDisplay,
        showDivider: false,
      ),
    ],
  );
}

class _AnalysisBlock extends StatelessWidget {
  const _AnalysisBlock({
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
  const _BriefSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
  });

  final String text;
  final bool emphasized;
  final bool supporting;

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
              for (var index = 0; index < records.take(5).length; index++) ...[
                ListTile(
                  key: ValueKey(
                    'morning-brief-back-number-${records[index].localDate}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  leading: _BackNumberLeading(
                    status: records[index].operationStatus,
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
                if (index != records.take(5).length - 1) const Divider(),
              ],
            ],
          ),
  );
}

class _BackNumberLeading extends StatelessWidget {
  const _BackNumberLeading({required this.status});

  final MorningBriefOperationStatus status;

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
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: switch (status) {
                MorningBriefOperationStatus.green => Colors.green,
                MorningBriefOperationStatus.yellow => Colors.amber,
                MorningBriefOperationStatus.red => Colors.red,
              },
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
        leading: _BackNumberLeading(status: records[index].operationStatus),
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
