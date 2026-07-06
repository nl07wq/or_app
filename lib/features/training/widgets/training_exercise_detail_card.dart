import 'package:flutter/material.dart';

import '../../../core/models/training_exercise.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/summary_row.dart';

class TrainingExerciseDetailCard extends StatelessWidget {
  final TrainingExercise exercise;

  const TrainingExerciseDetailCard({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final totalRep = exercise.sets.fold<int>(0, (sum, set) => sum + set.reps);

    final maxWeight = exercise.sets.fold<double>(
      0,
      (max, set) => set.weight > max ? set.weight : max,
    );

    final volume = exercise.sets.fold<double>(
      0,
      (sum, set) => sum + (set.weight * set.reps),
    );

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.fitness_center, title: 'EXERCISE'),

          AppSpacing.gapMD,

          Text(
            exercise.exerciseName,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          AppSpacing.gapLG,

          ...exercise.sets.map(
            (set) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'SET ${set.setNo}    ${set.weight} kg × ${set.reps}回',
              ),
            ),
          ),

          AppSpacing.gapLG,

          const Divider(),

          AppSpacing.gapSM,

          Text(
            'Exercise Summary',
            style: Theme.of(context).textTheme.titleSmall,
          ),

          AppSpacing.gapSM,

          SummaryRow(title: 'Volume', value: '${volume.toStringAsFixed(0)} kg'),

          SummaryRow(title: 'Rep', value: '$totalRep'),

          SummaryRow(title: 'Max', value: '${maxWeight.toStringAsFixed(1)} kg'),
        ],
      ),
    );
  }
}
