import '../../../core/models/training_set.dart';

class StatisticsResult {
  final double totalVolume;
  final int workingSets;
  final int totalRepetitions;
  final double averageWeight;
  final TrainingSet? heaviestSet;

  const StatisticsResult({
    required this.totalVolume,
    required this.workingSets,
    required this.totalRepetitions,
    required this.averageWeight,
    required this.heaviestSet,
  });
}
