import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../training_analysis/services/recovery_evidence_shadow_v2_service.dart';

class SystemMonitoringPage extends StatefulWidget {
  const SystemMonitoringPage({super.key});

  @override
  State<SystemMonitoringPage> createState() => _SystemMonitoringPageState();
}

class _SystemMonitoringPageState extends State<SystemMonitoringPage> {
  late final Future<_ShadowSnapshot> _shadow = _loadShadow();

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
            Text(progress.identity.exerciseKey),
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
