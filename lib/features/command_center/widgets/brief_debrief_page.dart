import 'package:flutter/material.dart';

import '../../../core/state/app_initialization_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../report_sync/models/daily_debrief_record.dart';
import '../../report_sync/models/morning_brief_record.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/pages/report_sync_exchange_page.dart';
import '../../repositories/app_repository_container.dart';

class BriefDebriefPage extends StatelessWidget {
  const BriefDebriefPage({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 2,
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SectionHeader(
            icon: Icons.article_outlined,
            title: 'BRIEF / DEBRIEF',
          ),
        ),
        TabBar(
          tabs: [
            Tab(text: 'MORNING BRIEF'),
            Tab(text: 'DAILY DEBRIEF'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [_MorningBriefView(), _DailyDebriefView()],
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
  late Future<List<MorningBriefRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = _load();
  }

  Future<List<MorningBriefRecord>> _load() async {
    final records = (await AppRepositoryRegistry.container.morningBriefs.list())
        .toList();
    records.sort((a, b) => b.localDate.compareTo(a.localDate));
    return records;
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
  Widget build(BuildContext context) => FutureBuilder<List<MorningBriefRecord>>(
    future: _records,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) return _LoadError(onRetry: _reload);
      final records = snapshot.data ?? const [];
      return ListView(
        key: const ValueKey('morning-brief-content'),
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.wb_sunny_outlined,
            title: 'MORNING BRIEF',
          ),
          AppSpacing.gapSM,
          if (records.isEmpty)
            const OperationCard(child: Text('MORNING BRIEFはまだありません。'))
          else
            _MorningBriefCard(record: records.first),
          AppSpacing.gapMD,
          OperationButton(
            key: const ValueKey('open-morning-brief-report-sync'),
            text: 'REPORT SYNC',
            icon: Icons.sync,
            onPressed: appInitializationController.value.isReadOnly
                ? null
                : _openSync,
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.history, title: 'HISTORY'),
          AppSpacing.gapSM,
          _MorningBriefHistory(records: records),
          AppSpacing.gapLG,
        ],
      );
    },
  );

  void _reload() {
    final records = _load();
    setState(() {
      _records = records;
    });
  }
}

class _DailyDebriefView extends StatefulWidget {
  const _DailyDebriefView();

  @override
  State<_DailyDebriefView> createState() => _DailyDebriefViewState();
}

class _DailyDebriefViewState extends State<_DailyDebriefView> {
  late Future<List<DailyDebriefRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = _load();
  }

  Future<List<DailyDebriefRecord>> _load() async {
    final records = (await AppRepositoryRegistry.container.dailyDebriefs.list())
        .toList();
    records.sort((a, b) => b.localDate.compareTo(a.localDate));
    return records;
  }

  Future<void> _openSync() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.dailyDebrief,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DailyDebriefRecord>>(
    future: _records,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) return _LoadError(onRetry: _reload);
      final records = snapshot.data ?? const [];
      return ListView(
        key: const ValueKey('daily-debrief-content'),
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.nightlight_outlined,
            title: 'DAILY DEBRIEF',
          ),
          AppSpacing.gapSM,
          if (records.isEmpty)
            const OperationCard(child: Text('DAILY DEBRIEFはまだありません。'))
          else
            _DailyDebriefCard(record: records.first),
          AppSpacing.gapMD,
          OperationButton(
            key: const ValueKey('open-daily-debrief-report-sync'),
            text: 'REPORT SYNC',
            icon: Icons.sync,
            onPressed: appInitializationController.value.isReadOnly
                ? null
                : _openSync,
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.history, title: 'HISTORY'),
          AppSpacing.gapSM,
          _DailyDebriefHistory(records: records),
          AppSpacing.gapLG,
        ],
      );
    },
  );

  void _reload() {
    final records = _load();
    setState(() {
      _records = records;
    });
  }
}

class _MorningBriefCard extends StatelessWidget {
  const _MorningBriefCard({required this.record});
  final MorningBriefRecord record;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(record.localDate, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        Text('SITUATION ANALYSIS\n${record.situationAnalysis}'),
        AppSpacing.gapSM,
        Text(
          'OPERATION STATUS\n${record.operationStatus.stableId.toUpperCase()}',
        ),
        AppSpacing.gapSM,
        Text('COMMANDER INTENT\n${record.commanderIntent}'),
        AppSpacing.gapSM,
        Text('ARGO COMMENT\n${record.argoComment}'),
        AppSpacing.gapSM,
        Text(
          'STRATEGIC RESOURCE DECISION\n${record.strategicResourceDecision}',
        ),
        AppSpacing.gapSM,
        const Text('ACTIONS'),
        for (final action in record.actions)
          Text('・${action.text} [${action.priority}]'),
      ],
    ),
  );
}

class _DailyDebriefCard extends StatelessWidget {
  const _DailyDebriefCard({required this.record});
  final DailyDebriefRecord record;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(record.localDate, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        Text('DAILY SUMMARY\n${record.dailySummary}'),
        AppSpacing.gapSM,
        Text(
          'COMMANDER INTENT EVALUATION\n${record.commanderIntentEvaluation}',
        ),
        AppSpacing.gapSM,
        Text('SUCCESSES\n${record.successes.join('\n')}'),
        AppSpacing.gapSM,
        Text('ISSUES\n${record.issues.join('\n')}'),
        AppSpacing.gapSM,
        Text('NUTRITION\n${record.nutritionEvaluation}'),
        AppSpacing.gapSM,
        Text('ACTIVITY\n${record.activityEvaluation}'),
        AppSpacing.gapSM,
        Text('TRAINING\n${record.trainingEvaluation}'),
        AppSpacing.gapSM,
        Text('RECOVERY\n${record.recoveryEvaluation}'),
        AppSpacing.gapSM,
        Text('CARRYOVER\n${record.carryover.join('\n')}'),
        AppSpacing.gapSM,
        Text('TOMORROW\n${record.tomorrowConsiderations.join('\n')}'),
        AppSpacing.gapSM,
        Text('CONFIRMATION DIGEST\n${record.confirmationDigest}'),
      ],
    ),
  );
}

class _MorningBriefHistory extends StatelessWidget {
  const _MorningBriefHistory({required this.records});
  final List<MorningBriefRecord> records;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: records.isEmpty
        ? const Text('NO MORNING BRIEF HISTORY')
        : Column(
            children: [
              for (var index = 0; index < records.length; index++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: Text(records[index].localDate),
                  subtitle: Text(
                    '${records[index].operationStatus.stableId.toUpperCase()} ・ '
                    '${records[index].importedAt.toLocal()}',
                  ),
                ),
                if (index != records.length - 1) const Divider(),
              ],
            ],
          ),
  );
}

class _DailyDebriefHistory extends StatelessWidget {
  const _DailyDebriefHistory({required this.records});
  final List<DailyDebriefRecord> records;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: records.isEmpty
        ? const Text('NO DAILY DEBRIEF HISTORY')
        : Column(
            children: [
              for (var index = 0; index < records.length; index++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.nightlight_outlined),
                  title: Text(records[index].localDate),
                  subtitle: Text('${records[index].importedAt.toLocal()}'),
                ),
                if (index != records.length - 1) const Divider(),
              ],
            ],
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
