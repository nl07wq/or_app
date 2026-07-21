import 'package:flutter/material.dart';

import '../../core/models/cardio_entry.dart';
import '../../core/models/training_session.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import 'widgets/training_summary_card.dart';
import 'widgets/training_exercise_detail_card.dart';
import 'widgets/training_session_summary_card.dart';

class TrainingDetailPage extends StatelessWidget {
  final TrainingSession session;

  const TrainingDetailPage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final exerciseCount = session.exercises.length;

    final setCount = session.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );

    final totalVolume = session.exercises.fold<double>(
      0,
      (sum, exercise) =>
          sum +
          exercise.sets.fold<double>(
            0,
            (v, set) => v + (set.weight * set.reps),
          ),
    );
    
    final totalRep = session.exercises.fold<int>(
      0,
      (sum, exercise) =>
          sum + exercise.sets.fold<int>(0, (rep, set) => rep + set.reps),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Training Detail')),
      body: ListView(
        children: [
          TrainingSummaryCard(
            date: session.date.split('T').first,
            memo: session.memo,
            exerciseCount: exerciseCount,
            setCount: setCount,
            totalVolume: totalVolume,
          ),

          ...session.exercises.map(
            (exercise) => TrainingExerciseDetailCard(exercise: exercise),
          ),
          if (session.cardioEntries.isNotEmpty)
            _CardioDetailCard(entries: session.cardioEntries),
          TrainingSessionSummaryCard(
            exerciseCount: exerciseCount,
            setCount: setCount,
            totalRep: totalRep,
            totalVolume: totalVolume,
          ),
        ],
      ),
    );
  }
}

class _CardioDetailCard extends StatelessWidget {
  const _CardioDetailCard({required this.entries});

  final List<CardioEntry> entries;

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.directions_run_outlined,
            title: 'Cardio',
          ),
          AppSpacing.gapMD,
          for (var index = 0; index < entries.length; index++) ...[
            _CardioDetailEntry(index: index + 1, entry: entries[index]),
            if (index < entries.length - 1) ...[
              AppSpacing.gapMD,
              const Divider(),
              AppSpacing.gapMD,
            ],
          ],
        ],
      ),
    );
  }
}

class _CardioDetailEntry extends StatelessWidget {
  const _CardioDetailEntry({required this.index, required this.entry});

  final int index;
  final CardioEntry entry;

  @override
  Widget build(BuildContext context) {
    final notes = entry.notes?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index. ${_cardioTypeLabel(entry.type)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        AppSpacing.gapSM,
        Text(
          '${_cardioIntensityLabel(entry.intensity)} - '
          '${entry.durationMinutes} min',
        ),
        if (entry.distanceKm != null)
          Text('Distance: ${_formatDistance(entry.distanceKm!)} km'),
        if (entry.estimatedCalories != null)
          Text('Estimated: ${entry.estimatedCalories!.round()} kcal'),
        if (notes != null && notes.isNotEmpty) Text('Notes: $notes'),
      ],
    );
  }
}

String _cardioTypeLabel(CardioType type) => switch (type) {
  CardioType.walking => 'Walking',
  CardioType.running => 'Running',
  CardioType.exerciseBike => 'Exercise Bike',
  CardioType.elliptical => 'Elliptical / Cross Trainer',
  CardioType.treadmillWalking => 'Treadmill Walking',
  CardioType.treadmillRunning => 'Treadmill Running',
};

String _cardioIntensityLabel(CardioIntensity intensity) => switch (intensity) {
  CardioIntensity.light => 'Light',
  CardioIntensity.moderate => 'Moderate',
  CardioIntensity.vigorous => 'Vigorous',
};

String _formatDistance(double distanceKm) {
  if (distanceKm == distanceKm.roundToDouble()) {
    return distanceKm.round().toString();
  }

  return distanceKm.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
