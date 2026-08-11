import 'package:flutter/material.dart';

import '../../../core/models/training_session_v2.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../models/training_v2_form_controller.dart';

class TrainingSessionV2Form extends StatelessWidget {
  final TrainingV2FormController controller;
  final VoidCallback onChanged;

  const TrainingSessionV2Form({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(icon: Icons.event_note, title: 'SESSION'),
          AppSpacing.gapMD,
          _TrainingTimeActions(controller: controller, onChanged: onChanged),
          AppSpacing.gapSM,
          TextField(
            controller: controller.sessionName,
            decoration: const InputDecoration(labelText: 'Session Name'),
          ),
          AppSpacing.gapSM,
          DropdownButtonFormField<TrainingSessionGrade?>(
            initialValue: controller.sessionGrade,
            decoration: const InputDecoration(labelText: 'Session Grade'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Not recorded')),
              for (final grade in TrainingSessionGrade.values)
                DropdownMenuItem(value: grade, child: Text(grade.displayLabel)),
            ],
            onChanged: (value) {
              controller.sessionGrade = value;
              onChanged();
            },
          ),
          AppSpacing.gapSM,
          TextField(
            controller: controller.sessionMemo,
            decoration: const InputDecoration(labelText: 'Session Memo'),
            minLines: 2,
            maxLines: 3,
          ),
          AppSpacing.gapSM,
          _TriStateField(
            label: 'Dynamic Stretch',
            value: controller.dynamicStretchCompleted,
            onChanged: (value) {
              controller.dynamicStretchCompleted = value;
              onChanged();
            },
          ),
          AppSpacing.gapSM,
          _TriStateField(
            label: 'Cooldown Stretch',
            value: controller.cooldownStretchCompleted,
            onChanged: (value) {
              controller.cooldownStretchCompleted = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _TrainingTimeActions extends StatelessWidget {
  final TrainingV2FormController controller;
  final VoidCallback onChanged;

  const _TrainingTimeActions({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start = controller.startTime;
    final end = controller.endTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Start Time  ${start ?? 'NOT RECORDED'}'),
        AppSpacing.gapSM,
        OutlinedButton.icon(
          onPressed: start == null
              ? () {
                  controller.startTraining(DateTime.now());
                  onChanged();
                }
              : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('START TRAINING'),
        ),
        AppSpacing.gapSM,
        Text('End Time  ${end ?? 'NOT RECORDED'}'),
        AppSpacing.gapSM,
        OutlinedButton.icon(
          onPressed: start != null && end == null
              ? () {
                  controller.endTraining(DateTime.now());
                  onChanged();
                }
              : null,
          icon: const Icon(Icons.stop),
          label: const Text('END TRAINING'),
        ),
      ],
    );
  }
}

class _TriStateField extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _TriStateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: switch (value) {
        true => 'completed',
        false => 'notCompleted',
        null => 'notRecorded',
      },
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: 'notRecorded', child: Text('Not recorded')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
        DropdownMenuItem(value: 'notCompleted', child: Text('Not completed')),
      ],
      onChanged: (value) => onChanged(switch (value) {
        'completed' => true,
        'notCompleted' => false,
        _ => null,
      }),
    );
  }
}
