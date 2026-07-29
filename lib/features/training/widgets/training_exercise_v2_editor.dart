import 'package:flutter/material.dart';

import '../../../core/models/training_set_v2.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../models/training_v2_form_controller.dart';
import '../services/exercise_name_localization.dart';
import 'exercise_selector.dart';
import 'training_collapsible_card.dart';
import 'training_equipment_field.dart';
import 'training_set_v2_editor.dart';

class TrainingExerciseV2Editor extends StatelessWidget {
  final int index;
  final TrainingV2ExerciseFormController controller;
  final TrainingEquipmentCandidates equipmentCandidates;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const TrainingExerciseV2Editor({
    super.key,
    required this.index,
    required this.controller,
    required this.equipmentCandidates,
    required this.expanded,
    required this.onToggle,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name = controller.exerciseName.text.trim();
    final title = name.isEmpty
        ? 'EXERCISE ${index + 1}'
        : exerciseDisplayName(name);
    return TrainingCollapsibleCard(
      icon: Icons.fitness_center,
      title: title,
      summary: _summary(),
      isExpanded: expanded,
      onToggle: onToggle,
      headerKey: ValueKey('v2-exercise-header-${identityHashCode(controller)}'),
      contentKey: ValueKey(
        'v2-exercise-content-${identityHashCode(controller)}',
      ),
      semanticsLabel: '$title, ${expanded ? 'expanded' : 'collapsed'}',
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
                onPressed: onDelete,
              ),
            ],
          ),
          AppSpacing.gapSM,
          TrainingEquipmentField(
            fieldKey: 'v2-exercise-$index-equipment',
            value: controller.equipment,
            candidates: equipmentCandidates,
            onChanged: (value) {
              controller.equipment = value;
              onChanged();
            },
          ),
          AppSpacing.gapMD,
          TrainingSetV2Editor(controller: controller, onChanged: onChanged),
          AppSpacing.gapMD,
          TextField(
            controller: controller.evaluation,
            decoration: const InputDecoration(labelText: 'Evaluation'),
            minLines: 3,
            maxLines: 5,
          ),
          AppSpacing.gapMD,
          const SectionHeader(icon: Icons.flag_outlined, title: 'NEXT TARGET'),
          AppSpacing.gapSM,
          TextField(
            controller: controller.targetWeight,
            decoration: const InputDecoration(
              labelText: 'Target Weight',
              suffixText: 'kg',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          AppSpacing.gapSM,
          for (final (targetIndex, reps) in controller.targetReps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: Key('v2-target-reps-$index-$targetIndex'),
                      controller: reps,
                      decoration: InputDecoration(
                        labelText: 'Target Set ${targetIndex + 1}',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete target reps',
                    onPressed: () {
                      controller.removeTargetRep(reps);
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('ADD TARGET REP'),
              onPressed: () {
                controller.addTargetRep();
                onChanged();
              },
            ),
          ),
          TextField(
            controller: controller.targetNotes,
            decoration: const InputDecoration(labelText: 'Target Notes'),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  String? _summary() {
    var mainSets = 0;
    var reps = 0;
    double? heaviest;
    for (final set in controller.sets) {
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
