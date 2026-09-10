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
              AppSpacing.gapMD,
              Text('Operation Date  ${target.localDate}'),
              Text('Training  ${target.displaySessionName ?? 'SESSION'}'),
              if (_report != null)
                Text(
                  _report!.revision >= 2
                      ? 'REV ${_report!.revision}  LATEST'
                      : 'LATEST',
                ),
              if (_report != null)
                Text(
                  _reportIsCurrent == true
                      ? 'ANALYSIS CURRENT'
                      : 'ANALYSIS OUTDATED',
                  style: TextStyle(
                    color: _reportIsCurrent == true
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
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
            ('RECENT HISTORY NOTES', report.analysis.previousComparison),
            ('PROGRESS', report.analysis.progressAnalysis),
          ],
        ),
        AppSpacing.gapXL,
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
            'ANALYSIS OUTDATED\n'
            '分析結果が現在のTraining Recordと一致していません。保存済みの内容は履歴として表示しています。再生成してください。',
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
      values: [
        _MetricValue('DURATION', _durationValue(metrics.duration), ''),
        _MetricValue('EXERCISES', '${metrics.exerciseCount}', ''),
        _MetricValue(
          'RECORDED SETS',
          _integerValue(metrics.recordedSetCount),
          '',
        ),
        _MetricValue('TOTAL REPS', _integerValue(metrics.totalReps), 'reps'),
        _volumeMetric('RECORDED VOLUME', metrics.recordedVolume),
        _volumeMetric('MAIN SET VOLUME', metrics.workingVolume),
        _MetricValue('AVERAGE RPE', _rpeValue(metrics.averageRpe), ''),
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
          const Text('EQUIPMENT NOT RECORDED'),
        ],
        AppSpacing.gapLG,
        if (metrics != null) ...[
          const Text('CURRENT METRICS'),
          AppSpacing.gapSM,
          _MetricGrid(values: _currentMetricValues(metrics!.current)),
          AppSpacing.gapLG,
          _ExerciseComparison(metrics: metrics!),
          AppSpacing.gapLG,
        ],
        _LabelText(label: 'CURRENT / ASSESSMENT', text: exercise.assessment),
        _LabelText(label: 'VS PREVIOUS', text: exercise.previousComparison),
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
      return const Text('PREVIOUS: NOT AVAILABLE');
    }
    final rows = <_ComparisonRow>[
      _comparisonRow(
        'MAX WEIGHT',
        metrics.current.maxWeight,
        previous.maxWeight,
        'kg',
      ),
      _comparisonRow(
        'TOTAL REPS',
        metrics.current.totalReps?.toDouble(),
        previous.totalReps?.toDouble(),
        'reps',
      ),
      _comparisonRow(
        'RECORDED SETS',
        metrics.current.recordedSetCount?.toDouble(),
        previous.recordedSetCount?.toDouble(),
        '',
      ),
      _comparisonRow(
        'RECORDED VOLUME',
        metrics.current.recordedVolume,
        previous.recordedVolume,
        'volume',
      ),
      _comparisonRow(
        'MAIN SET VOLUME',
        metrics.current.workingVolume,
        previous.workingVolume,
        'volume',
      ),
      _comparisonRow(
        'AVERAGE RPE',
        metrics.current.averageRpe,
        previous.averageRpe,
        'rpe',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PREVIOUS — SAME EXERCISE / EQUIPMENT'),
        if (metrics.recentHistory.isNotEmpty) ...[
          AppSpacing.gapXS,
          Text(
            'RECENT HISTORY  ${metrics.recentHistory.map((value) => value.operationDate).join(' / ')}',
          ),
        ],
        AppSpacing.gapSM,
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
            3: FlexColumnWidth(),
          },
          children: [
            const TableRow(
              children: [
                _ComparisonHeader('METRIC'),
                _ComparisonHeader('CURRENT'),
                _ComparisonHeader('PREVIOUS'),
                _ComparisonHeader('CHANGE'),
              ],
            ),
            for (final row in rows) row.toTableRow(),
          ],
        ),
      ],
    );
  }
}

class _ComparisonHeader extends StatelessWidget {
  const _ComparisonHeader(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xs),
    child: Text(value, style: Theme.of(context).textTheme.labelSmall),
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
      _ComparisonCell(_comparisonValue(current, kind)),
      _ComparisonCell(_comparisonValue(previous, kind)),
      _ComparisonCell(
        current == null || previous == null
            ? '—'
            : _comparisonValue(current! - previous!, kind, signed: true),
      ),
    ],
  );
}

class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xs),
    child: Text(value, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});
  final List<_MetricValue> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 620 ? 3 : 2;
      final width =
          (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: _MetricTile(value: value),
            ),
        ],
      );
    },
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value});
  final _MetricValue value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value.label, style: Theme.of(context).textTheme.labelSmall),
        AppSpacing.gapXS,
        Text(
          value.display,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (value.unit.isNotEmpty)
          Text(value.unit, style: Theme.of(context).textTheme.labelSmall),
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
  _MetricValue('MAX WEIGHT', _weightValue(values.maxWeight), 'kg'),
  _MetricValue('TOTAL REPS', _integerValue(values.totalReps), 'reps'),
  _MetricValue('RECORDED SETS', _integerValue(values.recordedSetCount), ''),
  _volumeMetric('RECORDED VOLUME', values.recordedVolume),
  _volumeMetric('MAIN SET VOLUME', values.workingVolume),
  _MetricValue('AVERAGE RPE', _rpeValue(values.averageRpe), ''),
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
    'reps' => '$prefix${value.round()} reps',
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
