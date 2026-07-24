import 'package:flutter/material.dart';

import '../../../core/models/training_set.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/personal_record_result.dart';
import '../models/statistics_result.dart';
import '../models/training_set_controller.dart';
import '../services/personal_record_service.dart';
import '../services/statistics_service.dart';
import 'training_personal_record_card.dart';
import 'training_statistics_card.dart';

class TrainingMetricsSection extends StatefulWidget {
  final TextEditingController exerciseController;
  final ValueNotifier<String?> equipmentController;
  final List<TrainingSetController> sets;

  const TrainingMetricsSection({
    super.key,
    required this.exerciseController,
    required this.equipmentController,
    required this.sets,
  });

  @override
  State<TrainingMetricsSection> createState() => _TrainingMetricsSectionState();
}

class _TrainingMetricsSectionState extends State<TrainingMetricsSection> {
  final List<TrainingSetController> _listenedSets = [];
  late StatisticsResult _statistics;
  late Future<PersonalRecordResult?> _personalRecord;

  @override
  void initState() {
    super.initState();
    widget.exerciseController.addListener(_refresh);
    widget.equipmentController.addListener(_refresh);
    _syncSetListeners();
    _updateResults();
  }

  @override
  void didUpdateWidget(covariant TrainingMetricsSection oldWidget) {
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
    _updateResults();
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
    return Column(
      children: [
        TrainingStatisticsCard(result: _statistics),
        AppSpacing.gapXS,
        TrainingPersonalRecordCard(result: _personalRecord),
      ],
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

  void _updateResults() {
    final sets = _completedSets();
    _statistics = StatisticsService.calculate(sets);
    _personalRecord = PersonalRecordService.load(
      exerciseName: widget.exerciseController.text,
      equipmentId: widget.equipmentController.value,
      currentSets: sets,
    );
  }

  void _refresh() {
    final sets = _completedSets();
    final statistics = StatisticsService.calculate(sets);
    final personalRecord = PersonalRecordService.load(
      exerciseName: widget.exerciseController.text,
      equipmentId: widget.equipmentController.value,
      currentSets: sets,
    );
    setState(() {
      _statistics = statistics;
      _personalRecord = personalRecord;
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
