import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_set_v2.dart';

class TrainingV2Statistics {
  final int mainSetCount;
  final int totalReps;
  final double totalVolume;
  final double? averageWeight;
  final TrainingSetV2? heaviestSet;
  final TrainingSetV2? topSet;

  const TrainingV2Statistics({
    required this.mainSetCount,
    required this.totalReps,
    required this.totalVolume,
    required this.averageWeight,
    required this.heaviestSet,
    required this.topSet,
  });

  static const empty = TrainingV2Statistics(
    mainSetCount: 0,
    totalReps: 0,
    totalVolume: 0,
    averageWeight: null,
    heaviestSet: null,
    topSet: null,
  );
}

abstract final class TrainingV2StatisticsService {
  static TrainingV2Statistics calculate(TrainingExerciseV2 exercise) {
    final mainSets = exercise.sets
        .where((set) => set.setType == TrainingSetType.main)
        .toList(growable: false);
    if (mainSets.isEmpty) return TrainingV2Statistics.empty;

    var totalReps = 0;
    var totalVolume = 0.0;
    var totalWeight = 0.0;
    var heaviest = mainSets.first;
    for (final set in mainSets) {
      totalReps += set.reps;
      totalVolume += set.weightKg * set.reps;
      totalWeight += set.weightKg;
      if (isHigherSet(set, heaviest)) heaviest = set;
    }
    return TrainingV2Statistics(
      mainSetCount: mainSets.length,
      totalReps: totalReps,
      totalVolume: totalVolume,
      averageWeight: totalWeight / mainSets.length,
      heaviestSet: heaviest,
      topSet: heaviest,
    );
  }

  static bool isHigherSet(TrainingSetV2 candidate, TrainingSetV2 current) {
    if (candidate.weightKg != current.weightKg) {
      return candidate.weightKg > current.weightKg;
    }
    if (candidate.reps != current.reps) {
      return candidate.reps > current.reps;
    }
    return candidate.setNo < current.setNo;
  }
}
