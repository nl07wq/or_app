enum ProgressionRecommendation { increaseWeight, maintainWeight, repeatWeight }

class ProgressionResult {
  final double lastWeight;
  final int lastReps;
  final double suggestedWeight;
  final int suggestedRepsMin;
  final int suggestedRepsMax;
  final ProgressionRecommendation recommendation;
  final String reason;

  const ProgressionResult({
    required this.lastWeight,
    required this.lastReps,
    required this.suggestedWeight,
    required this.suggestedRepsMin,
    required this.suggestedRepsMax,
    required this.recommendation,
    required this.reason,
  });
}
