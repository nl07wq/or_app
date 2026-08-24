import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/models/training_record_read_model.dart';
import '../../training/training_plan_import_page.dart';
import '../models/training_analysis_report.dart';
import '../services/training_analysis_service.dart';

class TrainingAnalysisPage extends StatefulWidget {
  const TrainingAnalysisPage({super.key, this.targetRecordId});

  final String? targetRecordId;

  @override
  State<TrainingAnalysisPage> createState() => _TrainingAnalysisPageState();
}

class _TrainingAnalysisPageState extends State<TrainingAnalysisPage> {
  final _response = TextEditingController();
  late final TrainingAnalysisService _service;
  late Future<List<TrainingRecordReadModel>> _records;
  String? _targetRecordId;
  TrainingAnalysisPreparation? _preparation;
  TrainingAnalysisPreview? _preview;
  TrainingAnalysisReport? _report;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = TrainingAnalysisService();
    _targetRecordId = widget.targetRecordId;
    _records = AppRepositoryRegistry.container.training.findAllRecords();
    _loadReport();
  }

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    final id = _targetRecordId;
    if (id == null) return;
    final report = await AppRepositoryRegistry.container.trainingAnalysisReports
        .read(id);
    if (mounted) setState(() => _report = report);
  }

  Future<void> _copyPrompt() async {
    final id = _targetRecordId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preparation = await _service.prepare(id);
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

  Future<void> _validate() async {
    final id = _targetRecordId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await _service.preview(id, _response.text);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
      setState(() {
        _report = result.report;
        _preview = null;
        _response.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.result.name == 'noChange'
                ? 'NO CHANGES'
                : 'TRAINING ANALYSIS REPORTを保存しました',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(TrainingRecordReadModel record) {
    setState(() {
      _targetRecordId = record.id;
      _preparation = null;
      _preview = null;
      _report = null;
      _error = null;
      _response.clear();
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
                _preparation = null;
                _preview = null;
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
              if (_report != null) Text('REV ${_report!.revision}  LATEST'),
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
        if (_report != null) AppSpacing.gapXL,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                icon: Icons.auto_awesome_outlined,
                title: 'CREATE ANALYSIS',
              ),
              AppSpacing.gapMD,
              OperationButton(
                icon: Icons.content_copy_outlined,
                text: _report == null
                    ? 'COPY CHATGPT PROMPT'
                    : 'COPY REVISION PROMPT',
                onPressed: _busy ? null : _copyPrompt,
              ),
              if (_preparation != null) ...[
                AppSpacing.gapMD,
                const Text('PromptをChatGPTへ貼り付け、返却JSONを下へ貼り付けてください。'),
              ],
              AppSpacing.gapMD,
              TextField(
                controller: _response,
                minLines: 6,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'RESPONSE JSON',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapMD,
              OutlinedButton.icon(
                onPressed: _busy ? null : _validate,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('VALIDATE'),
              ),
              if (_preview != null) ...[
                AppSpacing.gapMD,
                Text(
                  _preview!.disposition.name == 'noChange'
                      ? 'NO CHANGES'
                      : 'REV ${(_preview!.current?.revision ?? 0) + 1} READY',
                ),
                AppSpacing.gapMD,
                OperationButton(
                  icon: Icons.download_done_outlined,
                  text: 'IMPORT ANALYSIS',
                  onPressed: _busy ? null : _import,
                ),
              ],
              if (_error != null) ...[
                AppSpacing.gapMD,
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        if (_report?.previousRevisions.isNotEmpty == true) ...[
          AppSpacing.gapMD,
          _PreviousRevisionsCard(report: _report!),
        ],
      ],
    );
  }
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
