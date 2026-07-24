import 'package:flutter/material.dart';

import '../../../core/models/training_set.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/training_set_controller.dart';
import '../models/training_summary.dart';
import '../services/training_summary_engine.dart';
import 'training_history_preview.dart';
import 'training_personal_record_card.dart';
import 'training_progression_card.dart';
import 'training_statistics_card.dart';

class TrainingSummarySection extends StatefulWidget {
  final TextEditingController exerciseController;
  final ValueNotifier<String?> equipmentController;
  final List<TrainingSetController> sets;

  const TrainingSummarySection({
    super.key,
    required this.exerciseController,
    required this.equipmentController,
    required this.sets,
  });

  @override
  State<TrainingSummarySection> createState() => _TrainingSummarySectionState();
}

class _TrainingSummarySectionState extends State<TrainingSummarySection> {
  final List<TrainingSetController> _listenedSets = [];
  late Future<TrainingSummary> _summary;

  @override
  void initState() {
    super.initState();
    widget.exerciseController.addListener(_refresh);
    widget.equipmentController.addListener(_refresh);
    _syncSetListeners();
    _summary = _load();
  }

  @override
  void didUpdateWidget(covariant TrainingSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.exerciseController, widget.exerciseController)) {
      oldWidget.exerciseController.removeListener(_refresh);
      widget.exerciseController.addListener(_refresh);
    }
    if (!identical(oldWidget.equipmentController, widget.equipmentController)) {
      oldWidget.equipmentController.removeListener(_refresh);
      widget.equipmentController.addListener(_refresh);
    }
    _syncSetListeners();
    _summary = _load();
  }

  @override
  void dispose() {
    widget.exerciseController.removeListener(_refresh);
    widget.equipmentController.removeListener(_refresh);
    _removeSetListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrainingSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) {
          return Text(
            'Loading…',
            key: const Key('training-summary-loading'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrainingHistoryPreview(summary: summary),
            AppSpacing.gapXS,
            TrainingProgressionCard(summary: summary),
            AppSpacing.gapXS,
            TrainingStatisticsCard(summary: summary),
            AppSpacing.gapXS,
            TrainingPersonalRecordCard(summary: summary),
          ],
        );
      },
    );
  }

  void _syncSetListeners() {
    _removeSetListeners();
    _listenedSets.addAll(widget.sets);
    for (final set in _listenedSets) {
      set.weightController.addListener(_refresh);
      set.repsController.addListener(_refresh);
    }
  }

  void _removeSetListeners() {
    for (final set in _listenedSets) {
      set.weightController.removeListener(_refresh);
      set.repsController.removeListener(_refresh);
    }
    _listenedSets.clear();
  }

  Future<TrainingSummary> _load() {
    return TrainingSummaryEngine.summarize(
      exerciseName: widget.exerciseController.text,
      equipmentId: widget.equipmentController.value,
      currentSets: _completedSets(),
    );
  }

  void _refresh() {
    final summary = _load();
    setState(() {
      _summary = summary;
    });
  }

  List<TrainingSet> _completedSets() {
    final sets = <TrainingSet>[];
    for (var index = 0; index < widget.sets.length; index++) {
      final controller = widget.sets[index];
      final weight = double.tryParse(controller.weightController.text.trim());
      final reps = int.tryParse(controller.repsController.text.trim());
      if (weight == null || !weight.isFinite || weight < 0) continue;
      if (reps == null || reps <= 0) continue;
      sets.add(TrainingSet(setNo: index + 1, weight: weight, reps: reps));
    }
    return sets;
  }
}
