import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/models/training_set_v2.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../report_sync/widgets/report_sync_action_bar.dart';
import 'models/training_plan_proposal.dart';
import 'services/training_plan_service.dart';
import 'training_entry_page.dart';

class TrainingPlanImportPage extends StatefulWidget {
  const TrainingPlanImportPage({super.key, this.sourceRecordId, this.service});

  final String? sourceRecordId;
  final TrainingPlanService? service;

  @override
  State<TrainingPlanImportPage> createState() => _TrainingPlanImportPageState();
}

class _TrainingPlanImportPageState extends State<TrainingPlanImportPage> {
  final _response = TextEditingController();
  late final TrainingPlanService _service;
  late Future<TrainingPlanPreparation> _preparation;
  TrainingPlanPreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? TrainingPlanService();
    _preparation = _service.prepare(targetRecordId: widget.sourceRecordId);
  }

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _copy(TrainingPlanPreparation preparation) async {
    await Clipboard.setData(ClipboardData(text: preparation.prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TRAINING PLAN PROMPTをコピーしました')),
    );
  }

  Future<void> _validate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await _service.preview(_response.text);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    if (_busy) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    setState(() {
      _response.text = data!.text!;
      _preview = null;
      _error = null;
    });
  }

  void _clear() {
    if (_busy) return;
    setState(() {
      _response.clear();
      _preview = null;
      _error = null;
    });
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.apply(preview);
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrainingEntryPage()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TRAINING PLAN')),
    body: FutureBuilder<TrainingPlanPreparation>(
      future: _preparation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Text('PLAN PROMPTを準備できませんでした: ${snapshot.error}'),
          );
        }
        final preparation = snapshot.data!;
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    icon: Icons.event_note_outlined,
                    title: 'PLAN PROMPT',
                  ),
                  AppSpacing.gapMD,
                  Text('OPERATION DATE  ${preparation.operationDate}'),
                  AppSpacing.gapMD,
                  OperationButton(
                    icon: Icons.content_copy_outlined,
                    text: 'COPY CHATGPT PROMPT',
                    onPressed: _busy ? null : () => _copy(preparation),
                  ),
                ],
              ),
            ),
            AppSpacing.gapMD,
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    icon: Icons.download_outlined,
                    title: 'IMPORT PLAN',
                  ),
                  AppSpacing.gapMD,
                  TextField(
                    controller: _response,
                    minLines: 8,
                    maxLines: 16,
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
              AppSpacing.gapXL,
              if (_preview!.plan.planType == TrainingPlanType.rest) ...[
                const SectionHeader(
                  icon: Icons.bedtime_outlined,
                  title: 'REST PLAN',
                ),
                AppSpacing.gapMD,
                _RestPlanCard(preview: _preview!),
              ] else ...[
                const SectionHeader(
                  icon: Icons.preview_outlined,
                  title: 'TRAINING PLAN',
                ),
                AppSpacing.gapMD,
                for (final exercise in _preview!.plan.exercises) ...[
                  _PlanExerciseCard(exercise: exercise),
                  AppSpacing.gapMD,
                ],
                OperationCard(
                  child: OperationButton(
                    icon: Icons.playlist_add_check_outlined,
                    text: 'APPLY PLAN',
                    onPressed: _busy ? null : _apply,
                  ),
                ),
              ],
            ],
            if (_error != null) ...[
              AppSpacing.gapMD,
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _PlanExerciseCard extends StatelessWidget {
  const _PlanExerciseCard({required this.exercise});

  final TrainingPlanExercise exercise;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          exercise.name.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final type in const [TrainingSetType.warmUp, TrainingSetType.main])
          if (exercise.sets.any((set) => set.setType == type)) ...[
            AppSpacing.gapMD,
            Text(
              type == TrainingSetType.warmUp ? 'WARM-UP' : 'MAIN',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpacing.gapXS,
            for (final set in exercise.sets.where((set) => set.setType == type))
              Text(
                '${_number(set.plannedWeightKg)}kg × '
                '${set.targetMinReps == set.targetMaxReps ? set.targetMinReps : '${set.targetMinReps}–${set.targetMaxReps}'}',
              ),
          ],
      ],
    ),
  );
}

class _RestPlanCard extends StatelessWidget {
  const _RestPlanCard({required this.preview});

  final TrainingPlanPreview preview;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'REST / NO TRAINING',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        AppSpacing.gapSM,
        Text('OPERATION DATE  ${preview.plan.operationDate}'),
        AppSpacing.gapMD,
        Text(preview.plan.note!),
        AppSpacing.gapLG,
        OperationButton(
          icon: Icons.arrow_back_outlined,
          text: 'BACK TO TRAINING',
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
    ),
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
