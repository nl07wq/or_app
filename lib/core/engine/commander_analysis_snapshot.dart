import 'operation_status.dart';

class CommanderAnalysisSnapshot {
  final OperationStatus status;
  final String overview;
  final String recoveryAnalysis;
  final String nutritionAnalysis;
  final String trainingAnalysis;
  final List<String> recommendations;

  const CommanderAnalysisSnapshot({
    required this.status,
    required this.overview,
    required this.recoveryAnalysis,
    required this.nutritionAnalysis,
    required this.trainingAnalysis,
    required this.recommendations,
  });

  CommanderAnalysisSnapshot copyWith({
    OperationStatus? status,
    String? overview,
    String? recoveryAnalysis,
    String? nutritionAnalysis,
    String? trainingAnalysis,
    List<String>? recommendations,
  }) {
    return CommanderAnalysisSnapshot(
      status: status ?? this.status,
      overview: overview ?? this.overview,
      recoveryAnalysis: recoveryAnalysis ?? this.recoveryAnalysis,
      nutritionAnalysis: nutritionAnalysis ?? this.nutritionAnalysis,
      trainingAnalysis: trainingAnalysis ?? this.trainingAnalysis,
      recommendations: recommendations ?? this.recommendations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CommanderAnalysisSnapshot &&
        status == other.status &&
        overview == other.overview &&
        recoveryAnalysis == other.recoveryAnalysis &&
        nutritionAnalysis == other.nutritionAnalysis &&
        trainingAnalysis == other.trainingAnalysis &&
        _sameRecommendations(other.recommendations);
  }

  bool _sameRecommendations(List<String> other) {
    if (recommendations.length != other.length) return false;

    for (var index = 0; index < recommendations.length; index++) {
      if (recommendations[index] != other[index]) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      overview,
      recoveryAnalysis,
      nutritionAnalysis,
      trainingAnalysis,
      Object.hashAll(recommendations),
    );
  }
}
