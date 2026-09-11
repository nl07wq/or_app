import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/models/training_record_read_model.dart';
import '../../training/services/training_volume_formatter.dart';
import '../../training/training_plan_import_page.dart';
import '../../report_sync/widgets/report_sync_action_bar.dart';
import '../models/training_analysis_report.dart';
import '../services/training_analysis_service.dart';
import '../services/training_analysis_metrics_adapter.dart';

class TrainingAnalysisPage extends StatefulWidget {
  const TrainingAnalysisPage({super.key, this.targetRecordId});

  final String? targetRecordId;

  @override
  State<TrainingAnalysisPage> createState() => _TrainingAnalysisPageState();
}

class _TrainingAnalysisPageState extends State<TrainingAnalysisPage> {
  late Future<List<TrainingRecordReadModel>> _records;
  String? _targetRecordId;
  TrainingAnalysisReport? _report;
  bool? _reportIsCurrent;

  @override
  void initState() {
    super.initState();
    _targetRecordId = widget.targetRecordId;
    _records = AppRepositoryRegistry.container.training.findAllRecords();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final id = _targetRecordId;
    if (id == null) return;
    final report = await AppRepositoryRegistry.container.trainingAnalysisReports
        .read(id);
    final isCurrent = report == null
        ? null
        : await TrainingAnalysisService().isCurrent(report);
    if (mounted) {
      setState(() {
        _report = report;
        _reportIsCurrent = isCurrent;
      });
    }
  }

  void _select(TrainingRecordReadModel record) {
    setState(() {
      _targetRecordId = record.id;
      _report = null;
      _reportIsCurrent = null;
    });
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('TRAINING ANALYSIS REPORT'),
        ),
        actions: [
          if (_targetRecordId != null && widget.targetRecordId == null)
            IconButton(
              tooltip: 'SELECT TRAINING RECORD',
              onPressed: () => setState(() {
                _targetRecordId = null;
                _report = null;
                _reportIsCurrent = null;
              }),
              icon: const Icon(Icons.list_alt_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: FutureBuilder<List<TrainingRecordReadModel>>(
              future: _records,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_targetRecordId == null) {
                  return _RecordSelector(
                    records: snapshot.data!,
                    onSelected: _select,
                  );
                }
                final target = snapshot.data!.where(
                  (record) => record.id == _targetRecordId,
                );
                if (target.isEmpty) {
                  return const Center(
                    child: Text('Target Training Recordが見つかりません。'),
                  );
                }
                return _buildReportFlow(target.single, snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportFlow(
    TrainingRecordReadModel target,
    List<TrainingRecordReadModel> records,
  ) {
    final metrics = const TrainingAnalysisMetricsAdapter().build(
      target: target,
      records: records,
    );
    return ListView(
      padding: AppSpacing.cardPadding,
      children: [
        OperationCard(
          key: const ValueKey('training-analysis-action-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.analytics_outlined,
                title: 'TRAINING ANALYSIS REPORT',
              ),
              AppSpacing.gapXS,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${target.localDate} ・ ${target.displaySessionName ?? 'SESSION'}',
                  ),
                  if (_report != null)
                    Text(
                      _report!.revision >= 2
                          ? 'REV ${_report!.revision}  LATEST'
                          : 'LATEST',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  if (_report != null && _reportIsCurrent != true)
                    Text(
                      'STALE',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        AppSpacing.gapMD,
        if (_report != null && _reportIsCurrent != true) ...[
          _StaleAnalysisWarning(),
          AppSpacing.gapMD,
        ],
        if (_report != null)
          _ReportView(
            report: _report!,
            metrics: metrics,
            isCurrent: _reportIsCurrent == true,
          ),
        if (_report != null) ...[
          AppSpacing.gapMD,
          OperationCard(
            child: OperationButton(
              icon: Icons.event_note_outlined,
              text: 'CREATE NEXT PLAN',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TrainingPlanImportPage(sourceRecordId: target.id),
                ),
              ),
            ),
          ),
        ],
        AppSpacing.gapMD,
        OperationCard(
          child: OperationButton(
            key: const ValueKey('open-training-analysis-create'),
            icon: Icons.auto_awesome_outlined,
            text: 'CREATE ANALYSIS REPORT',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainingAnalysisCreatePage(
                    targetRecordId: target.id,
                    revisionMode: _report != null,
                  ),
                ),
              );
              await _loadReport();
            },
          ),
        ),
        if (_report?.previousRevisions.isNotEmpty == true) ...[
          AppSpacing.gapMD,
          _PreviousRevisionsCard(report: _report!),
        ],
        if (_report?.archivedRevisions.isNotEmpty == true) ...[
          AppSpacing.gapSM,
          const Text('OLDER REVISION DETAIL ARCHIVED / NOT AVAILABLE'),
        ],
      ],
    );
  }
}

class TrainingAnalysisCreatePage extends StatefulWidget {
  const TrainingAnalysisCreatePage({
    super.key,
    required this.targetRecordId,
    this.revisionMode = false,
    this.service,
  });

  final String targetRecordId;
  final bool revisionMode;
  final TrainingAnalysisService? service;

  @override
  State<TrainingAnalysisCreatePage> createState() =>
      _TrainingAnalysisCreatePageState();
}

class _TrainingAnalysisCreatePageState
    extends State<TrainingAnalysisCreatePage> {
  final _response = TextEditingController();
  late final TrainingAnalysisService _service =
      widget.service ?? TrainingAnalysisService();
  TrainingAnalysisPreparation? _preparation;
  TrainingAnalysisPreview? _preview;
  bool _busy = false;
  bool _invalid = false;
  String? _error;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preparation = await _service.prepare(widget.targetRecordId);
      await Clipboard.setData(ClipboardData(text: preparation.prompt));
      if (!mounted) return;
      setState(() => _preparation = preparation);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TRAINING ANALYSIS PROMPTをコピーしました')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    setState(() {
      _response.text = data!.text!;
      _preview = null;
      _invalid = false;
      _error = null;
    });
  }

  void _clear() => setState(() {
    _response.clear();
    _preview = null;
    _invalid = false;
    _error = null;
  });

  Future<void> _validate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _invalid = false;
      _preview = null;
    });
    try {
      final preview = await _service.preview(
        widget.targetRecordId,
        _response.text,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) {
        setState(() {
          _invalid = true;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.apply(preview);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.result.name == 'noChange'
                ? 'NO CHANGES'
                : 'TRAINING ANALYSIS REPORTを保存しました',
          ),
        ),
      );
      if (result.result.name != 'noChange') Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _readyLabel {
    final preview = _preview!;
    if (preview.disposition.name == 'noChange') return 'NO CHANGES';
    final nextRevision = (preview.current?.revision ?? 0) + 1;
    return nextRevision >= 2 ? 'REV $nextRevision  READY' : 'READY';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CREATE ANALYSIS REPORT')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: AppSpacing.cardPadding,
            children: [
              OperationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      icon: Icons.auto_awesome_outlined,
                      title: 'CREATE ANALYSIS REPORT',
                    ),
                    AppSpacing.gapMD,
                    OperationButton(
                      icon: Icons.content_copy_outlined,
                      text: widget.revisionMode
                          ? 'COPY REVISION PROMPT'
                          : 'COPY CHATGPT PROMPT',
                      onPressed: _busy ? null : _copyPrompt,
                    ),
                    if (_preparation != null) ...[
                      AppSpacing.gapMD,
                      const Text('PromptをChatGPTへ貼り付け、返却JSONを下へ貼り付けてください。'),
                    ],
                    AppSpacing.gapMD,
                    TextField(
                      key: const ValueKey('training-analysis-response-json'),
                      controller: _response,
                      minLines: 6,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'RESPONSE JSON',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    AppSpacing.gapMD,
                    ReportSyncActionBar(
                      enabled: !_busy,
                      onPaste: _paste,
                      onClear: _clear,
                      onValidate: _validate,
                    ),
                  ],
                ),
              ),
              if (_preview != null) ...[
                AppSpacing.gapMD,
                OperationCard(
                  key: const ValueKey('training-analysis-import-preview'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_readyLabel),
                      AppSpacing.gapMD,
                      _LabelText(
                        label: 'SUMMARY',
                        text: _preview!.analysis.sessionSummary,
                      ),
                      _LabelText(
                        label: 'PROGRESS',
                        text: _preview!.analysis.progressAnalysis,
                      ),
                      _LabelText(
                        label: 'NEXT',
                        text: _preview!.analysis.nextSessionProposal,
                        isLast: true,
                      ),
                      AppSpacing.gapMD,
                      OperationButton(
                        icon: Icons.download_done_outlined,
                        text: 'IMPORT ANALYSIS',
                        onPressed:
                            _busy || _preview!.disposition.name == 'noChange'
                            ? null
                            : _import,
                      ),
                    ],
                  ),
                ),
              ],
              if (_invalid || _error != null) ...[
                AppSpacing.gapMD,
                OperationCard(
                  key: const ValueKey('training-analysis-invalid'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_invalid) const Text('INVALID'),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _RecordSelector extends StatelessWidget {
  const _RecordSelector({required this.records, required this.onSelected});

  final List<TrainingRecordReadModel> records;
  final ValueChanged<TrainingRecordReadModel> onSelected;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('No Training Records'));
    }
    return ListView.separated(
      padding: AppSpacing.cardPadding,
      itemCount: records.length,
      separatorBuilder: (_, _) => AppSpacing.gapMD,
      itemBuilder: (context, index) {
        final record = records[index];
        return OperationCard(
          selectable: true,
          onTap: () => onSelected(record),
          child: Row(
            children: [
              const Icon(Icons.fitness_center),
              AppSpacing.gapMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.localDate),
                    Text(
                      record.displaySessionName ??
                          '${record.exerciseCount} Exercises',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        );
      },
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.metrics,
    required this.isCurrent,
  });

  final TrainingAnalysisReport report;
  final TrainingAnalysisMetrics metrics;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ReportSectionTitle(
          key: ValueKey('training-analysis-summary-section'),
          icon: Icons.summarize_outlined,
          title: 'SESSION SUMMARY',
        ),
        AppSpacing.gapMD,
        _SessionMetricsCard(metrics: metrics.session),
        AppSpacing.gapLG,
        _NarrativeCard(
          title: isCurrent ? 'SESSION ANALYSIS' : 'SAVED ANALYSIS SNAPSHOT',
          values: [
            ('SESSION SUMMARY', report.analysis.sessionSummary),
            ('PERFORMANCE', report.analysis.performanceAnalysis),
            ('PROGRESS', report.analysis.progressAnalysis),
          ],
        ),
        AppSpacing.gapLG,
        const _ReportSectionTitle(
          key: ValueKey('training-analysis-exercise-section'),
          icon: Icons.fitness_center,
          title: 'EXERCISE BREAKDOWN',
        ),
        for (final exercise in report.analysis.exerciseAnalyses) ...[
          AppSpacing.gapMD,
          _ExerciseAnalysisCard(
            exercise: exercise,
            metrics: _metricsFor(exercise.exerciseIdentity),
          ),
        ],
        AppSpacing.gapXL,
        const _ReportSectionTitle(
          key: ValueKey('training-analysis-next-actions-section'),
          icon: Icons.next_plan_outlined,
          title: 'NEXT ACTIONS',
        ),
        AppSpacing.gapMD,
        _AnalysisCard(
          key: const ValueKey('training-analysis-next-session'),
          icon: Icons.event_available_outlined,
          title: 'NEXT SESSION',
          text: report.analysis.nextSessionProposal,
        ),
        AppSpacing.gapMD,
        _AnalysisCard(
          key: const ValueKey('training-analysis-recovery'),
          icon: Icons.bedtime_outlined,
          title: 'RECOVERY / FREQUENCY NOTES',
          text: report.analysis.recoveryFrequencyComment,
        ),
        AppSpacing.gapMD,
        _AnalysisCard(
          key: const ValueKey('training-analysis-risk'),
          icon: Icons.health_and_safety_outlined,
          title: 'RISK / ATTENTION',
          text: report.analysis.riskAttentionNotes,
        ),
      ],
    );
  }

  TrainingAnalysisExerciseMetrics? _metricsFor(String identity) {
    for (final value in metrics.exercises) {
      if ('${value.identity.exerciseKey}|${value.identity.equipmentKey}' ==
          identity) {
        return value;
      }
    }
    return null;
  }
}

class _StaleAnalysisWarning extends StatelessWidget {
  const _StaleAnalysisWarning();

  @override
  Widget build(BuildContext context) => OperationCard(
    key: const ValueKey('training-analysis-stale-warning'),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        AppSpacing.gapSM,
        const Expanded(
          child: Text(
            '現在のTraining Recordと一致しない保存済みスナップショットです。'
            '最新の分析を確認するには再生成してください。',
          ),
        ),
      ],
    ),
  );
}

class _SessionMetricsCard extends StatelessWidget {
  const _SessionMetricsCard({required this.metrics});

  final TrainingAnalysisSessionMetrics metrics;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: const ValueKey('training-analysis-session-metrics'),
    child: _MetricGrid(
      compact: true,
      keyPrefix: 'session',
      values: [
        _MetricValue(
          _AnalysisLabels.duration,
          _durationValue(metrics.duration),
          '',
        ),
        _MetricValue(
          _AnalysisLabels.exerciseCount,
          '${metrics.exerciseCount}',
          '',
        ),
        _MetricValue(
          _AnalysisLabels.totalSets,
          _integerValue(metrics.recordedSetCount),
          '',
        ),
        _MetricValue(
          _AnalysisLabels.totalReps,
          _integerValue(metrics.totalReps),
          '回',
        ),
        _volumeMetric(_AnalysisLabels.totalVolume, metrics.recordedVolume),
        _volumeMetric(_AnalysisLabels.mainSetVolume, metrics.workingVolume),
        _MetricValue(
          _AnalysisLabels.averageRpe,
          _rpeValue(metrics.averageRpe),
          '',
        ),
      ],
    ),
  );
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.title, required this.values});

  final String title;
  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardTitle(icon: Icons.article_outlined, title: title),
        AppSpacing.gapMD,
        for (final (label, text) in values)
          _LabelText(label: label, text: text, isLast: label == values.last.$1),
      ],
    ),
  );
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardTitle(icon: icon, title: title),
        AppSpacing.gapMD,
        _ReadableAnalysisText(text),
      ],
    ),
  );
}

class _ExerciseAnalysisCard extends StatelessWidget {
  const _ExerciseAnalysisCard({required this.exercise, required this.metrics});

  final TrainingExerciseAnalysis exercise;
  final TrainingAnalysisExerciseMetrics? metrics;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: ValueKey('training-analysis-exercise-${exercise.exerciseIdentity}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardTitle(
          icon: Icons.fitness_center,
          title: metrics?.exerciseName ?? exercise.exerciseName.toUpperCase(),
          prominent: true,
        ),
        if (metrics?.equipmentLabel != null) ...[
          AppSpacing.gapXS,
          Text(
            metrics!.equipmentLabel!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ] else ...[
          AppSpacing.gapXS,
          const Text('器具未記録'),
        ],
        AppSpacing.gapMD,
        if (metrics != null) ...[
          const Text('現在の指標'),
          AppSpacing.gapSM,
          _MetricGrid(
            values: _currentMetricValues(metrics!.current),
            compact: true,
            keyPrefix: 'exercise',
          ),
          AppSpacing.gapMD,
          _ExerciseComparison(metrics: metrics!),
          AppSpacing.gapMD,
        ],
        _LabelText(label: '現在 / 評価', text: exercise.assessment),
        _LabelText(label: '前回比較', text: exercise.previousComparison),
        _LabelText(label: 'ANALYSIS / PROGRESS', text: exercise.progress),
        _LabelText(label: 'NEXT', text: exercise.nextProposal, isLast: true),
      ],
    ),
  );
}

class _ExerciseComparison extends StatelessWidget {
  const _ExerciseComparison({required this.metrics});

  final TrainingAnalysisExerciseMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final previous = metrics.previous;
    if (previous == null) {
      return const Text('前回: 利用不可');
    }
    final rows = <_ComparisonRow>[
      _comparisonRow(
        _AnalysisLabels.maxWeight,
        metrics.current.maxWeight,
        previous.maxWeight,
        'kg',
      ),
      _comparisonRow(
        _AnalysisLabels.totalReps,
        metrics.current.totalReps?.toDouble(),
        previous.totalReps?.toDouble(),
        'reps',
      ),
      _comparisonRow(
        _AnalysisLabels.totalSets,
        metrics.current.recordedSetCount?.toDouble(),
        previous.recordedSetCount?.toDouble(),
        '',
      ),
      _comparisonRow(
        _AnalysisLabels.totalVolume,
        metrics.current.recordedVolume,
        previous.recordedVolume,
        'volume',
      ),
      _comparisonRow(
        _AnalysisLabels.mainSetVolume,
        metrics.current.workingVolume,
        previous.workingVolume,
        'volume',
      ),
      _comparisonRow(
        _AnalysisLabels.averageRpe,
        metrics.current.averageRpe,
        previous.averageRpe,
        'rpe',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('前回比較 — 同一種目 / 同一器具'),
        if (metrics.recentHistory.isNotEmpty) ...[
          AppSpacing.gapXS,
          Text(
            '直近履歴  ${metrics.recentHistory.map((value) => value.operationDate).join(' / ')}',
          ),
        ],
        AppSpacing.gapSM,
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(.95),
            2: FlexColumnWidth(.95),
            3: FlexColumnWidth(.95),
          },
          children: [
            const TableRow(
              children: [
                _ComparisonHeader('指標'),
                _ComparisonHeader('現在', align: TextAlign.right),
                _ComparisonHeader('前回', align: TextAlign.right),
                _ComparisonHeader('変化', align: TextAlign.right),
              ],
            ),
            for (final row in rows) row.toTableRow(),
          ],
        ),
        _ExerciseTrendGraphs(metrics: metrics),
      ],
    );
  }
}

class _ExerciseTrendGraphs extends StatefulWidget {
  const _ExerciseTrendGraphs({required this.metrics});

  final TrainingAnalysisExerciseMetrics metrics;

  @override
  State<_ExerciseTrendGraphs> createState() => _ExerciseTrendGraphsState();
}

class _ExerciseTrendGraphsState extends State<_ExerciseTrendGraphs> {
  String? _selectedMetricKey;
  String? _selectedVolumeKey;

  @override
  Widget build(BuildContext context) {
    final graphs = [
      _TrendMetric(
        key: 'max-weight',
        title: _AnalysisLabels.maxWeight,
        unit: 'kg',
        kind: 'kg',
        valueOf: (value) => value.maxWeight,
      ),
      _TrendMetric(
        key: 'total-reps',
        title: _AnalysisLabels.totalReps,
        unit: '回',
        kind: 'reps',
        valueOf: (value) => value.totalReps?.toDouble(),
      ),
      _TrendMetric(
        key: 'recorded-volume',
        title: _AnalysisLabels.totalVolume,
        unit: 'kg / t',
        kind: 'volume',
        valueOf: (value) => value.recordedVolume,
      ),
      _TrendMetric(
        key: 'main-set-volume',
        title: _AnalysisLabels.mainSetVolume,
        unit: 'kg / t',
        kind: 'volume',
        valueOf: (value) => value.workingVolume,
      ),
      _TrendMetric(
        key: 'average-rpe',
        title: _AnalysisLabels.averageRpe,
        unit: '',
        kind: 'rpe',
        valueOf: (value) => value.averageRpe,
      ),
    ];
    final dataByKey = {
      for (final metric in graphs)
        metric.key: _TrendGraphData.tryCreate(metric, widget.metrics),
    };
    final available = [
      for (final metric in graphs)
        if (dataByKey[metric.key] != null) metric,
    ];
    final categoryOrder = ['max-weight', 'total-reps', 'volume', 'average-rpe'];
    final availableCategories = [
      for (final category in categoryOrder)
        if (category == 'volume'
            ? dataByKey['recorded-volume'] != null ||
                  dataByKey['main-set-volume'] != null
            : dataByKey[category] != null)
          category,
    ];
    if (available.isEmpty || availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedCategory = availableCategories.contains(_selectedMetricKey)
        ? _selectedMetricKey!
        : availableCategories.first;
    final volumeOptions = [
      for (final key in ['recorded-volume', 'main-set-volume'])
        if (dataByKey[key] != null) key,
    ];
    final selectedKey = selectedCategory == 'volume'
        ? volumeOptions.contains(_selectedVolumeKey)
              ? _selectedVolumeKey!
              : volumeOptions.first
        : selectedCategory;
    final graph = dataByKey[selectedKey]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.gapSM,
        const Text('推移 — 直近履歴'),
        AppSpacing.gapXS,
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final category in availableCategories)
              ChoiceChip(
                label: Text(_trendSelectorLabel(category)),
                selected: selectedCategory == category,
                onSelected: (_) =>
                    setState(() => _selectedMetricKey = category),
              ),
          ],
        ),
        if (selectedCategory == 'volume' && volumeOptions.length > 1) ...[
          AppSpacing.gapXS,
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final key in volumeOptions)
                ChoiceChip(
                  label: Text(key == 'recorded-volume' ? '総ボリューム' : 'メインセット'),
                  selected: selectedKey == key,
                  onSelected: (_) => setState(() => _selectedVolumeKey = key),
                ),
            ],
          ),
        ],
        AppSpacing.gapXS,
        _ExerciseTrendGraph(data: graph),
      ],
    );
  }
}

class _ExerciseTrendGraph extends StatelessWidget {
  const _ExerciseTrendGraph({required this.data});

  final _TrendGraphData data;

  @override
  Widget build(BuildContext context) {
    final values = data.points.map((point) => point.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = maxValue == minValue
        ? maxValue.abs() * .15 + 1
        : (maxValue - minValue).abs() * .15;
    final minY = (minValue - padding).clamp(0.0, double.infinity);
    final maxY = maxValue + padding;
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('training-analysis-trend-${data.metric.key}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${data.metric.title}  ${data.metric.unit}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Text(
                '現在  ${_comparisonValue(data.currentValue, data.metric.kind)}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.tertiary),
              ),
            ],
          ),
          SizedBox(
            height: 104,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (data.points.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 2,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: .10),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: _trendLabelInterval(data.points.length),
                      getTitlesWidget: (value, _) {
                        final index = value.round();
                        if (index < 0 || index >= data.points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _shortDate(data.points[index].operationDate),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var index = 0; index < data.points.length; index++)
                        FlSpot(index.toDouble(), data.points[index].value),
                    ],
                    isCurved: false,
                    color: colors.primary,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: spot.x.round() == data.points.length - 1
                            ? 4
                            : 2.5,
                        color: spot.x.round() == data.points.length - 1
                            ? colors.tertiary
                            : colors.primary,
                        strokeColor: colors.surface,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendMetric {
  const _TrendMetric({
    required this.key,
    required this.title,
    required this.unit,
    required this.kind,
    required this.valueOf,
  });

  final String key;
  final String title;
  final String unit;
  final String kind;
  final double? Function(TrainingAnalysisExerciseMetricValues) valueOf;
}

class _TrendGraphData {
  const _TrendGraphData({required this.metric, required this.points});

  static _TrendGraphData? tryCreate(
    _TrendMetric metric,
    TrainingAnalysisExerciseMetrics metrics,
  ) {
    final currentValue = metric.valueOf(metrics.current);
    if (currentValue == null) return null;
    final points = <_TrendPoint>[
      for (final evidence in metrics.recentHistory.reversed)
        if (metric.valueOf(evidence.metrics) case final value?)
          _TrendPoint(evidence.operationDate, value),
      _TrendPoint(metrics.operationDate, currentValue),
    ];
    if (points.length < 2) return null;
    return _TrendGraphData(metric: metric, points: points);
  }

  final _TrendMetric metric;
  final List<_TrendPoint> points;
  double get currentValue => points.last.value;
}

class _TrendPoint {
  const _TrendPoint(this.operationDate, this.value);

  final String operationDate;
  final double value;
}

class _ComparisonHeader extends StatelessWidget {
  const _ComparisonHeader(this.value, {this.align = TextAlign.left});
  final String value;
  final TextAlign align;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xs),
    child: Text(
      value,
      textAlign: align,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}

class _ComparisonRow {
  const _ComparisonRow(this.label, this.current, this.previous, this.kind);
  final String label;
  final double? current;
  final double? previous;
  final String kind;

  TableRow toTableRow() => TableRow(
    children: [
      _ComparisonCell(label),
      _ComparisonCell(_comparisonValue(current, kind), align: TextAlign.right),
      _ComparisonCell(_comparisonValue(previous, kind), align: TextAlign.right),
      _ComparisonCell(
        current == null || previous == null
            ? '—'
            : _comparisonValue(current! - previous!, kind, signed: true),
        align: TextAlign.right,
      ),
    ],
  );
}

class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell(this.value, {this.align = TextAlign.left});
  final String value;
  final TextAlign align;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xs),
    child: Text(
      value,
      textAlign: align,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.values,
    this.compact = false,
    this.keyPrefix,
  });
  final List<_MetricValue> values;
  final bool compact;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = compact && constraints.maxWidth >= 300
          ? 3
          : constraints.maxWidth >= 620
          ? 3
          : 2;
      final width =
          (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: _MetricTile(
                key: keyPrefix == null
                    ? null
                    : ValueKey(
                        'training-analysis-$keyPrefix-metric-${_metricKey(value.label)}',
                      ),
                value: value,
                compact: compact,
              ),
            ),
        ],
      );
    },
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({super.key, required this.value, required this.compact});
  final _MetricValue value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.label,
          style: Theme.of(context).textTheme.labelSmall,
          maxLines: 2,
        ),
        SizedBox(height: compact ? 2 : AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value.display,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (value.unit.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(value.unit, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ],
    ),
  );
}

class _MetricValue {
  const _MetricValue(this.label, this.display, this.unit);
  final String label;
  final String display;
  final String unit;
}

List<_MetricValue> _currentMetricValues(
  TrainingAnalysisExerciseMetricValues values,
) => [
  _MetricValue(_AnalysisLabels.maxWeight, _weightValue(values.maxWeight), 'kg'),
  _MetricValue(_AnalysisLabels.totalReps, _integerValue(values.totalReps), '回'),
  _MetricValue(
    _AnalysisLabels.totalSets,
    _integerValue(values.recordedSetCount),
    '',
  ),
  _volumeMetric(_AnalysisLabels.totalVolume, values.recordedVolume),
  _volumeMetric(_AnalysisLabels.mainSetVolume, values.workingVolume),
  _MetricValue(_AnalysisLabels.averageRpe, _rpeValue(values.averageRpe), ''),
];

_MetricValue _volumeMetric(String label, double? value) {
  if (value == null) return _MetricValue(label, '—', '');
  final display = TrainingVolumeFormatter.display(value);
  return _MetricValue(label, display.value, display.unit);
}

_ComparisonRow _comparisonRow(
  String label,
  double? current,
  double? previous,
  String kind,
) => _ComparisonRow(label, current, previous, kind);

String _comparisonValue(double? value, String kind, {bool signed = false}) {
  if (value == null) return '—';
  final prefix = signed && value > 0 ? '+' : '';
  return switch (kind) {
    'kg' => '$prefix${_weightValue(value)} kg',
    'reps' => '$prefix${value.round()} 回',
    'volume' => '$prefix${TrainingVolumeFormatter.format(value)}',
    'rpe' => '$prefix${_rpeValue(value)}',
    _ => '$prefix${value.round()}',
  };
}

String _integerValue(int? value) => value?.toString() ?? '—';
String _weightValue(double? value) => value == null
    ? '—'
    : value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
String _rpeValue(double? value) => value?.toStringAsFixed(1) ?? '—';
String _durationValue(Duration? value) => value == null
    ? '—'
    : '${value.inHours.toString().padLeft(2, '0')}:'
          '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
          '${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';

String _metricKey(String value) => switch (value) {
  _AnalysisLabels.duration => 'duration',
  _AnalysisLabels.exerciseCount => 'exercises',
  _AnalysisLabels.maxWeight => 'max-weight',
  _AnalysisLabels.totalReps => 'total-reps',
  _AnalysisLabels.totalSets => 'recorded-sets',
  _AnalysisLabels.totalVolume => 'recorded-volume',
  _AnalysisLabels.mainSetVolume => 'main-set-volume',
  _AnalysisLabels.averageRpe => 'average-rpe',
  _ => value.toLowerCase().replaceAll('\n', '-').replaceAll(' ', '-'),
};

double _trendLabelInterval(int count) => count <= 2 ? 1 : (count - 1) / 2;

String _trendSelectorLabel(String category) => switch (category) {
  'max-weight' => '重量',
  'total-reps' => '回数',
  'volume' => 'ボリューム',
  'average-rpe' => 'RPE',
  _ => category,
};

class _AnalysisLabels {
  const _AnalysisLabels._();

  static const maxWeight = '最大重量';
  static const duration = '実施時間';
  static const exerciseCount = '種目数';
  static const totalReps = '総回数';
  static const totalSets = '総セット数';
  static const totalVolume = '総\nボリューム';
  static const mainSetVolume = 'メインセット\nボリューム';
  static const averageRpe = '平均RPE';
}

String _shortDate(String operationDate) => operationDate.length >= 10
    ? operationDate.substring(5, 10).replaceAll('-', '/')
    : operationDate;

class _ReportSectionTitle extends StatelessWidget {
  const _ReportSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => SectionHeader(icon: icon, title: title);
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    this.prominent = false,
  });

  final IconData icon;
  final String title;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: prominent ? 24 : 20, color: colors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style:
                (prominent
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ReadableAnalysisText extends StatelessWidget {
  const _ReadableAnalysisText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
  );
}

class _LabelText extends StatelessWidget {
  const _LabelText({
    required this.label,
    required this.text,
    this.isLast = false,
  });

  final String label;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        AppSpacing.gapSM,
        _ReadableAnalysisText(text),
      ],
    ),
  );
}

class _PreviousRevisionsCard extends StatelessWidget {
  const _PreviousRevisionsCard({required this.report});

  final TrainingAnalysisReport report;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: const ValueKey('training-analysis-previous-revisions'),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('PREVIOUS REVISIONS'),
      children: [
        for (final revision in report.previousRevisions)
          ListTile(
            title: Text('REV ${revision.revision}'),
            subtitle: Text(revision.analysis.sessionSummary),
          ),
      ],
    ),
  );
}
