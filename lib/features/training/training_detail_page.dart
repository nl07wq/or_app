import 'package:flutter/material.dart';

import '../../core/models/training_session.dart';
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
