import 'package:flutter/material.dart';

import '../../../core/models/training_set_v2.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/training_record_read_model.dart';
import '../models/training_v2_form_controller.dart';
import '../services/exercise_name_localization.dart';
import '../services/training_equipment_candidates.dart';
import 'exercise_selector.dart';
import 'training_collapsible_card.dart';
import 'training_equipment_field.dart';
import 'training_set_v2_editor.dart';
import 'training_v2_entry_insight_panel.dart';

class TrainingExerciseV2Editor extends StatefulWidget {
  final int index;
  final TrainingV2ExerciseFormController controller;
  final List<TrainingRecordReadModel> preferredRecords;
  final TrainingRecordReadModel? targetRecord;
  final String sessionDate;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const TrainingExerciseV2Editor({
    super.key,
    required this.index,
    required this.controller,
    required this.preferredRecords,
    required this.targetRecord,
    required this.sessionDate,
    required this.expanded,
    required this.onToggle,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<TrainingExerciseV2Editor> createState() =>
      _TrainingExerciseV2EditorState();
}

class _TrainingExerciseV2EditorState extends State<TrainingExerciseV2Editor> {
  late String _previousExerciseKey;

  @override
  void initState() {
    super.initState();
    _previousExerciseKey = exerciseIdentityKey(
      widget.controller.exerciseName.text,
    );
    widget.controller.exerciseName.addListener(_handleExerciseChange);
  }

  @override
  void didUpdateWidget(covariant TrainingExerciseV2Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.exerciseName.removeListener(_handleExerciseChange);
      _previousExerciseKey = exerciseIdentityKey(
        widget.controller.exerciseName.text,
      );
      widget.controller.exerciseName.addListener(_handleExerciseChange);
    }
  }

  @override
  void dispose() {
    widget.controller.exerciseName.removeListener(_handleExerciseChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final name = controller.exerciseName.text.trim();
    final title = name.isEmpty
        ? 'EXERCISE ${widget.index + 1}'
        : exerciseDisplayName(name);
    final equipmentCandidates = _equipmentCandidates();
    return TrainingCollapsibleCard(
      icon: Icons.fitness_center,
      title: title,
      summary: _summary(),
      isExpanded: widget.expanded,
      onToggle: widget.onToggle,
      headerKey: ValueKey('v2-exercise-header-${identityHashCode(controller)}'),
      contentKey: ValueKey(
        'v2-exercise-content-${identityHashCode(controller)}',
      ),
      semanticsLabel: '$title, ${widget.expanded ? 'expanded' : 'collapsed'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ExerciseSelector(controller: controller.exerciseName),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete exercise',
                onPressed: widget.onDelete,
              ),
            ],
          ),
          AppSpacing.gapSM,
          TrainingEquipmentField(
            fieldKey: 'v2-exercise-${widget.index}-equipment',
            value: controller.equipment,
            candidates: equipmentCandidates,
            hasSelection: controller.equipmentSelectionMade,
            allowCustom: name.isNotEmpty,
            onChanged: (value) {
              setState(() {
                controller.equipment = value;
                controller.equipmentSelectionMade = true;
              });
              widget.onChanged();
            },
          ),
          if (name.isNotEmpty) ...[
            AppSpacing.gapMD,
            TrainingV2EntryInsightPanel(
              controller: controller,
              preferredRecords: widget.preferredRecords,
              targetRecord: widget.targetRecord,
              sessionDate: widget.sessionDate,
            ),
          ],
          AppSpacing.gapMD,
          TrainingSetV2Editor(
            controller: controller,
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }

  void _handleExerciseChange() {
    final currentKey = exerciseIdentityKey(widget.controller.exerciseName.text);
    if (currentKey == _previousExerciseKey) return;
    _previousExerciseKey = currentKey;
    final selected = widget.controller.equipment;
    setState(() {
      if (selected != null && !_equipmentCandidates().contains(selected)) {
        widget.controller.equipment = null;
        widget.controller.equipmentSelectionMade = false;
      }
    });
    widget.onChanged();
  }

  TrainingEquipmentCandidates _equipmentCandidates() {
    return TrainingEquipmentCandidates.forExercise(
      exerciseName: widget.controller.exerciseName.text,
      preferredRecords: widget.preferredRecords,
    );
  }

  String? _summary() {
    var mainSets = 0;
    var reps = 0;
    double? heaviest;
    for (final set in widget.controller.sets) {
      if (set.setType != TrainingSetType.main) continue;
      final weight = double.tryParse(set.weight.text.trim());
      final valueReps = int.tryParse(set.reps.text.trim());
      if (weight == null ||
          !weight.isFinite ||
          weight < 0 ||
          valueReps == null ||
          valueReps < 1) {
        continue;
      }
      mainSets++;
      reps += valueReps;
      if (heaviest == null || weight > heaviest) heaviest = weight;
    }
    if (mainSets == 0) return 'Not configured';
    return '${_number(heaviest!)} kg   $mainSets Main Sets   $reps Reps';
  }
}

String _number(double value) {
  return value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}
