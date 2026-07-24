import '../../../core/models/training_set.dart';
import '../models/statistics_result.dart';

class StatisticsService {
  StatisticsService._();

  static StatisticsResult calculate(Iterable<TrainingSet> inputSets) {
    final sets = inputSets
        .where((set) => set.weight.isFinite && set.weight >= 0 && set.reps > 0)
        .toList(growable: false);
    if (sets.isEmpty) {
      return const StatisticsResult(
        totalVolume: 0,
        workingSets: 0,
        totalRepetitions: 0,
        averageWeight: 0,
        heaviestSet: null,
      );
    }

    var totalVolume = 0.0;
    var totalWeight = 0.0;
    var totalRepetitions = 0;
    var heaviestSet = sets.first;

    for (final set in sets) {
      totalVolume += set.weight * set.reps;
      totalWeight += set.weight;
      totalRepetitions += set.reps;
      if (_isHigherRecord(set, heaviestSet)) {
        heaviestSet = set;
      }
    }

    return StatisticsResult(
      totalVolume: totalVolume,
      workingSets: sets.length,
      totalRepetitions: totalRepetitions,
      averageWeight: totalWeight / sets.length,
      heaviestSet: heaviestSet,
    );
  }

  static bool _isHigherRecord(TrainingSet candidate, TrainingSet current) {
    return candidate.weight > current.weight ||
        candidate.weight == current.weight && candidate.reps > current.reps;
  }
}
