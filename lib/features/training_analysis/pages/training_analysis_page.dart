import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/models/training_record_read_model.dart';
import '../../training/training_plan_import_page.dart';
import '../../report_sync/widgets/report_sync_action_bar.dart';
import '../models/training_analysis_report.dart';
import '../services/training_analysis_service.dart';

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
    if (mounted) setState(() => _report = report);
  }

  void _select(TrainingRecordReadModel record) {
    setState(() {
      _targetRecordId = record.id;
      _report = null;
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
                return _buildReportFlow(target.single);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportFlow(TrainingRecordReadModel target) {
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
            ],
          ),
        ),
        AppSpacing.gapMD,
        if (_report != null) _ReportView(report: _report!),
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
  const _ReportView({required this.report});

  final TrainingAnalysisReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ReportSectionTitle(
          key: ValueKey('training-analysis-summary-section'),
          icon: Icons.summarize_outlined,
          title: 'SUMMARY',
        ),
        AppSpacing.gapMD,
        _AnalysisCard(
          key: const ValueKey('training-analysis-session-summary'),
          icon: Icons.article_outlined,
          title: 'SESSION SUMMARY',
          text: report.analysis.sessionSummary,
        ),
        AppSpacing.gapMD,
        _AnalysisCard(
          key: const ValueKey('training-analysis-performance'),
          icon: Icons.analytics_outlined,
          title: 'PERFORMANCE',
          text: report.analysis.performanceAnalysis,
        ),
        AppSpacing.gapMD,
        _AnalysisCard(
          key: const ValueKey('training-analysis-previous-session'),
          icon: Icons.history_outlined,
          title: 'PREVIOUS SESSION',
          text: report.analysis.previousComparison,
        ),
        AppSpacing.gapMD,
        _AnalysisCard(
          key: const ValueKey('training-analysis-progress'),
          icon: Icons.trending_up_outlined,
          title: 'PROGRESS',
          text: report.analysis.progressAnalysis,
        ),
        AppSpacing.gapXL,
        const _ReportSectionTitle(
          key: ValueKey('training-analysis-exercise-section'),
          icon: Icons.fitness_center,
          title: 'EXERCISE BREAKDOWN',
        ),
        for (final exercise in report.analysis.exerciseAnalyses) ...[
          AppSpacing.gapMD,
          _ExerciseAnalysisCard(exercise: exercise),
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
          title: 'RECOVERY / FREQUENCY',
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
  const _ExerciseAnalysisCard({required this.exercise});

  final TrainingExerciseAnalysis exercise;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: ValueKey('training-analysis-exercise-${exercise.exerciseIdentity}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardTitle(
          icon: Icons.fitness_center,
          title: exercise.exerciseName.toUpperCase(),
          prominent: true,
        ),
        AppSpacing.gapLG,
        _LabelText(label: 'CURRENT / ASSESSMENT', text: exercise.assessment),
        _LabelText(label: 'VS PREVIOUS', text: exercise.previousComparison),
        _LabelText(label: 'ANALYSIS / PROGRESS', text: exercise.progress),
        _LabelText(label: 'NEXT', text: exercise.nextProposal, isLast: true),
      ],
    ),
  );
}

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
