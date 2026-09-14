import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../report_sync/services/daily_brief_plantar_risk_review_service.dart';
import '../../training_analysis/services/recovery_evidence_shadow_v2_service.dart';
import '../models/information_notice.dart';
import '../services/app_metadata.dart';
import '../services/information_notice_service.dart';
import '../widgets/dashboard_information_strip.dart';

class SystemMonitoringPage extends StatefulWidget {
  const SystemMonitoringPage({super.key});

  @override
  State<SystemMonitoringPage> createState() => _SystemMonitoringPageState();
}

class _SystemMonitoringPageState extends State<SystemMonitoringPage> {
  late final Future<_ShadowSnapshot> _shadow = _loadShadow();
  late final Future<DailyBriefPlantarRiskReviewSummary> _dailyBriefReview =
      _loadDailyBriefReview();
  late final InformationNoticeService _informationService =
      InformationNoticeService();
  late Future<List<InformationNotice>> _informationHistory = _informationService
      .history();

  void _refreshInformation() => setState(() {
    _informationHistory = _informationService.history();
  });

  Future<void> _createTestNotice() async {
    final draft = await showDialog<_InformationDebugDraft>(
      context: context,
      builder: (_) => const _InformationDebugEditor(),
    );
    if (draft == null) return;
    await _informationService.createDebugNotice(
      title: draft.title,
      message: draft.message,
      priority: draft.priority,
    );
    if (mounted) _refreshInformation();
  }

  Future<void> _deleteTestNotice(InformationNotice notice) async {
    final confirmed = await _confirm(
      title: 'このテスト通知を削除しますか？',
      body: 'この操作は取り消せません。',
    );
    if (confirmed != true) return;
    await _informationService.deleteDebugNotice(notice.id);
    if (mounted) _refreshInformation();
  }

  Future<void> _clearTestNotices() async {
    final confirmed = await _confirm(
      title: 'テスト通知をすべて削除しますか？',
      body: '作成したテスト通知をすべて削除します。この操作は取り消せません。',
    );
    if (confirmed != true) return;
    await _informationService.clearDebugNotices();
    if (mounted) _refreshInformation();
  }

  Future<bool?> _confirm({required String title, required String body}) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除'),
            ),
          ],
        ),
      );

  Future<_ShadowSnapshot> _loadShadow() async {
    final records = await AppRepositoryRegistry.container.training
        .findAllRecords();
    if (records.isEmpty) return const _ShadowSnapshot.empty();
    const shadow = RecoveryEvidenceShadowV2Service();
    final results = shadow.buildRecurring(
      records: records,
      now: DateTime.now(),
    );
    final progress = [
      for (final result in results) shadow.validationProgress(result),
    ];
    return _ShadowSnapshot.results(
      results,
      progress,
      shadow.validationOverall(progress),
    );
  }

  Future<DailyBriefPlantarRiskReviewSummary> _loadDailyBriefReview() async =>
      const DailyBriefPlantarRiskReviewService().summarize(
        await AppRepositoryRegistry.container.morningBriefs.list(),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SYSTEM MONITORING')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.monitor_heart_outlined,
          title: 'SYSTEM MONITORING',
        ),
        AppSpacing.gapSM,
        FutureBuilder<_ShadowSnapshot>(
          future: _shadow,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const OperationCard(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            return _RecoveryEvidenceShadowCard(snapshot: snapshot.data!);
          },
        ),
        AppSpacing.gapSM,
        FutureBuilder<DailyBriefPlantarRiskReviewSummary>(
          future: _dailyBriefReview,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const OperationCard(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            return _DailyBriefV2ReviewCard(summary: snapshot.data!);
          },
        ),
        AppSpacing.gapSM,
        FutureBuilder<List<InformationNotice>>(
          future: _informationHistory,
          builder: (context, snapshot) {
            final notices = snapshot.data ?? const [];
            if (notices.isEmpty) return const SizedBox.shrink();
            return _InformationHistoryCard(notices: notices);
          },
        ),
        AppSpacing.gapSM,
        FutureBuilder<List<InformationNotice>>(
          future: _informationHistory,
          builder: (context, snapshot) => _InformationDebugCard(
            notices: snapshot.data ?? const [],
            onCreate: _createTestNotice,
            onDelete: _deleteTestNotice,
            onClear: _clearTestNotices,
          ),
        ),
        AppSpacing.gapSM,
        const OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('復元履歴とデータ整合性の確認機能を今後追加します。'),
              AppSpacing.gapMD,
              _ComingLaterItem(label: 'IMPORT HISTORY'),
              AppSpacing.gapSM,
              _ComingLaterItem(label: 'CONFLICTS'),
              AppSpacing.gapSM,
              _ComingLaterItem(label: 'QUARANTINE'),
            ],
          ),
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _InformationMarqueeRuntimeDiagnostics extends StatelessWidget {
  const _InformationMarqueeRuntimeDiagnostics();

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<InformationMarqueeRuntimeSnapshot?>(
    valueListenable: InformationMarqueeRuntimeDiagnostics.snapshot,
    builder: (context, snapshot, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          'INFORMATION MARQUEE RUNTIME',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('RUNNING BUILD  ${AppMetadata.releaseMetadata.releaseCommit}'),
        Text(
          'SPEED  ${InformationMarqueeConfiguration.scrollSpeedPxPerSecond.toStringAsFixed(0)} px/s',
        ),
        Text(
          'EXIT MARGIN  ${InformationMarqueeConfiguration.exitSafetyMargin.toStringAsFixed(0)} px',
        ),
        if (snapshot == null)
          const Text('ACTIVE TICKER  未計測')
        else ...[
          Text('VIEWPORT  ${_px(snapshot.viewportWidth)} px'),
          Text('TEXT MEASURED  ${_px(snapshot.measuredTextWidth)} px'),
          Text(
            'TEXT RENDERED  ${snapshot.renderedTextWidth == null ? '計測中' : '${_px(snapshot.renderedTextWidth!)} px'}',
          ),
          Text('DISTANCE  ${_px(snapshot.travelDistance)} px'),
          Text('DURATION  ${snapshot.travelDuration.inMilliseconds} ms'),
          Text(
            'START / END  ${_px(snapshot.startLeft)} / ${_px(snapshot.endLeft)} px',
          ),
        ],
      ],
    ),
  );

  String _px(double value) => value.toStringAsFixed(1);
}

class _DailyBriefV2ReviewCard extends StatelessWidget {
  const _DailyBriefV2ReviewCard({required this.summary});

  final DailyBriefPlantarRiskReviewSummary summary;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY BRIEF V2 REVIEW',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('VERSION  ${summary.evaluationVersion}'),
        Text(
          'OBSERVATIONS  ${summary.observationCount} / ${DailyBriefPlantarRiskReviewService.targetObservationCount}',
        ),
        Text('STATE  ${_stateLabel(summary.state)}'),
        const Divider(),
        Text(
          'GREEN ${summary.greenCount}  /  YELLOW ${summary.yellowCount}  /  RED ${summary.redCount}',
        ),
      ],
    ),
  );

  String _stateLabel(DailyBriefPlantarRiskReviewState state) => switch (state) {
    DailyBriefPlantarRiskReviewState.collecting => 'COLLECTING',
    DailyBriefPlantarRiskReviewState.reviewBuilding => 'REVIEW BUILDING',
    DailyBriefPlantarRiskReviewState.reviewReady => 'REVIEW READY',
  };
}

class _InformationHistoryCard extends StatelessWidget {
  const _InformationHistoryCard({required this.notices});

  final List<InformationNotice> notices;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INFORMATION HISTORY',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final notice in notices) ...[
          const Divider(),
          Text('${notice.isDebug ? 'TEST  ' : ''}${notice.title}'),
          Text('${notice.category} / ${notice.parameterVersion}'),
          Text('状態: ${_stateLabel(notice.state)}'),
          Text('発生: ${_format(notice.createdAt)}'),
          if (notice.readAt != null) Text('既読: ${_format(notice.readAt!)}'),
          if (notice.dismissedAt != null)
            Text('表示から消去: ${_format(notice.dismissedAt!)}'),
        ],
      ],
    ),
  );

  String _stateLabel(InformationNoticeState state) => switch (state) {
    InformationNoticeState.unread => '未読',
    InformationNoticeState.read => '既読',
    InformationNoticeState.dismissed => '表示から消去',
  };

  String _format(DateTime value) =>
      '${value.year}/${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _InformationDebugCard extends StatelessWidget {
  const _InformationDebugCard({
    required this.notices,
    required this.onCreate,
    required this.onDelete,
    required this.onClear,
  });

  final List<InformationNotice> notices;
  final VoidCallback onCreate;
  final ValueChanged<InformationNotice> onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final testNotices = notices.where((notice) => notice.isDebug).toList();
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMATION DEBUG',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('TEST通知は通常のINFORMATIONパイプラインで表示されます。'),
          const _InformationMarqueeRuntimeDiagnostics(),
          const SizedBox(height: AppSpacing.md),
          OperationButton(
            text: 'CREATE TEST NOTICE',
            onPressed: onCreate,
            role: OperationActionRole.primary,
          ),
          if (testNotices.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('CLEAR TEST NOTICES'),
            ),
            for (final notice in testNotices) ...[
              const Divider(),
              Row(
                children: [
                  const Text('TEST'),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'テスト通知を削除',
                    onPressed: () => onDelete(notice),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Text(
                '${_priorityLabel(notice.priority)} / ${notice.state.name.toUpperCase()}',
              ),
              Text(
                'ID: ${notice.id}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '作成: ${_format(notice.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _priorityLabel(InformationNoticePriority priority) =>
      switch (priority) {
        InformationNoticePriority.safety => '安全・整合性',
        InformationNoticePriority.actionRequired => '対応が必要',
        InformationNoticePriority.review => 'レビュー',
        InformationNoticePriority.informational => '情報',
      };

  String _format(DateTime value) =>
      '${value.year}/${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _InformationDebugDraft {
  const _InformationDebugDraft({
    required this.title,
    required this.message,
    required this.priority,
  });

  final String title;
  final String message;
  final InformationNoticePriority priority;
}

class _InformationDebugEditor extends StatefulWidget {
  const _InformationDebugEditor();

  @override
  State<_InformationDebugEditor> createState() =>
      _InformationDebugEditorState();
}

class _InformationDebugEditorState extends State<_InformationDebugEditor> {
  final _title = TextEditingController(text: 'INFORMATION TEST');
  final _message = TextEditingController(
    text: 'Dashboard INFORMATION表示確認用のテスト通知です。',
  );
  var _priority = InformationNoticePriority.informational;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('CREATE TEST NOTICE'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'TITLE'),
          ),
          TextField(
            controller: _message,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'MESSAGE'),
          ),
          DropdownButtonFormField<InformationNoticePriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'PRIORITY'),
            items: [
              for (final priority in InformationNoticePriority.values)
                DropdownMenuItem(
                  value: priority,
                  child: Text(_priorityLabel(priority)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(
          context,
          _InformationDebugDraft(
            title: _title.text,
            message: _message.text,
            priority: _priority,
          ),
        ),
        child: const Text('作成'),
      ),
    ],
  );

  String _priorityLabel(InformationNoticePriority priority) =>
      switch (priority) {
        InformationNoticePriority.safety => '安全・整合性',
        InformationNoticePriority.actionRequired => '対応が必要',
        InformationNoticePriority.review => 'レビュー',
        InformationNoticePriority.informational => '情報',
      };
}

class _RecoveryEvidenceShadowCard extends StatelessWidget {
  const _RecoveryEvidenceShadowCard({required this.snapshot});

  final _ShadowSnapshot snapshot;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECOVERY EVIDENCE V2',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text('BETA / SHADOW — NOT OFFICIAL'),
        const SizedBox(height: 8),
        const Text('V1の回復・頻度判定は変更されません。最新の正式トレーニング記録を読み取り専用で比較します。'),
        if (snapshot.isEmpty) ...[
          const SizedBox(height: 8),
          const Text('比較できるトレーニング記録がありません。'),
        ],
        for (final result in snapshot.results) ...[
          const Divider(),
          Text(result.identity.exerciseKey),
          Text(
            'V1: eligible ${result.v1EligibleCount} / supported ${result.v1SupportedCount} / ${result.v1Status?.name ?? 'unavailable'}',
          ),
          Text(
            'V2: ${result.latestObservation?.loadContext.name ?? 'unavailable'} / ${result.latestObservation?.performanceBand.name ?? 'unavailable'} / ${result.latestObservation?.intervalZone.name ?? 'unavailable'}',
          ),
          Text(
            'Evidence: ${result.latestObservation?.recoveryEvidence.name ?? 'unavailable'}  Estimate: ${_estimate(result)}',
          ),
        ],
        if (snapshot.progress.isNotEmpty) ...[
          const Divider(),
          Text(
            'RECOVERY V2 SHADOW VALIDATION',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text('v2-beta-1 / BETA / SHADOW — NOT OFFICIAL'),
          Text('Overall: ${_overallLabel(snapshot.overall)}'),
          for (final progress in snapshot.progress) ...[
            const SizedBox(height: 8),
            Text(
              '${progress.identity.exerciseKey} / ${progress.identity.equipmentKey}',
            ),
            if (!progress.isCompatible)
              const Text('PARAMETER VERSION MISMATCH — NOT COUNTED')
            else ...[
              Text('${progress.newBetaInformativeCount} / 5'),
              Text(_milestoneLabel(progress.milestone)),
              Text(
                'Historical shadow evidence: ${progress.historicalInformativeCount}',
              ),
            ],
          ],
        ],
      ],
    ),
  );

  String _estimate(RecoveryEvidenceShadowV2Result result) {
    final estimate = result.estimate;
    if (!estimate.available) return 'INSUFFICIENT';
    return '${estimate.lowerHours!.round()}–${estimate.upperHours!.round()}h';
  }

  String _milestoneLabel(RecoveryEvidenceShadowValidationMilestone value) =>
      switch (value) {
        RecoveryEvidenceShadowValidationMilestone.collecting => 'COLLECTING',
        RecoveryEvidenceShadowValidationMilestone.firstReview => 'FIRST REVIEW',
        RecoveryEvidenceShadowValidationMilestone.reviewReady => 'REVIEW READY',
      };

  String _overallLabel(RecoveryEvidenceShadowValidationOverall value) =>
      switch (value) {
        RecoveryEvidenceShadowValidationOverall.collecting => 'COLLECTING',
        RecoveryEvidenceShadowValidationOverall.firstReviewAvailable =>
          'FIRST REVIEW AVAILABLE',
        RecoveryEvidenceShadowValidationOverall.reviewReady => 'REVIEW READY',
      };
}

class _ShadowSnapshot {
  const _ShadowSnapshot.empty()
    : results = const [],
      progress = const [],
      overall = RecoveryEvidenceShadowValidationOverall.collecting;
  const _ShadowSnapshot.results(this.results, this.progress, this.overall);
  final List<RecoveryEvidenceShadowV2Result> results;
  final List<RecoveryEvidenceShadowValidationProgress> progress;
  final RecoveryEvidenceShadowValidationOverall overall;
  bool get isEmpty => results.isEmpty;
}

class _ComingLaterItem extends StatelessWidget {
  const _ComingLaterItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      );
      if (constraints.maxWidth < 300) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelRow, AppSpacing.gapXS, const Text('COMING LATER')],
        );
      }
      return Row(
        children: [
          Expanded(child: labelRow),
          const SizedBox(width: 8),
          const Text('COMING LATER'),
        ],
      );
    },
  );
}
