import 'operation_status.dart';

class DailyOperationDecision {
  final OperationStatus status;
  final String situation;
  final String commanderIntent;
  final String primaryAction;
  final String dashboardSummary;
  final String recoveryAnalysis;
  final String nutritionAnalysis;
  final String hydrationAnalysis;
  final String trainingAnalysis;
  final List<String> recommendations;

  const DailyOperationDecision({
    required this.status,
    required this.situation,
    required this.commanderIntent,
    required this.primaryAction,
    required this.dashboardSummary,
    required this.recoveryAnalysis,
    required this.nutritionAnalysis,
    required this.hydrationAnalysis,
    required this.trainingAnalysis,
    required this.recommendations,
  });

  DailyOperationDecision copyWith({
    OperationStatus? status,
    String? situation,
    String? commanderIntent,
    String? primaryAction,
    String? dashboardSummary,
    String? recoveryAnalysis,
    String? nutritionAnalysis,
    String? hydrationAnalysis,
    String? trainingAnalysis,
    List<String>? recommendations,
  }) {
    return DailyOperationDecision(
      status: status ?? this.status,
      situation: situation ?? this.situation,
      commanderIntent: commanderIntent ?? this.commanderIntent,
      primaryAction: primaryAction ?? this.primaryAction,
      dashboardSummary: dashboardSummary ?? this.dashboardSummary,
      recoveryAnalysis: recoveryAnalysis ?? this.recoveryAnalysis,
      nutritionAnalysis: nutritionAnalysis ?? this.nutritionAnalysis,
      hydrationAnalysis: hydrationAnalysis ?? this.hydrationAnalysis,
      trainingAnalysis: trainingAnalysis ?? this.trainingAnalysis,
      recommendations: recommendations ?? this.recommendations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DailyOperationDecision &&
        status == other.status &&
        situation == other.situation &&
        commanderIntent == other.commanderIntent &&
        primaryAction == other.primaryAction &&
        dashboardSummary == other.dashboardSummary &&
        recoveryAnalysis == other.recoveryAnalysis &&
        nutritionAnalysis == other.nutritionAnalysis &&
        hydrationAnalysis == other.hydrationAnalysis &&
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
  int get hashCode => Object.hash(
    status,
    situation,
    commanderIntent,
    primaryAction,
    dashboardSummary,
    recoveryAnalysis,
    nutritionAnalysis,
    hydrationAnalysis,
    trainingAnalysis,
    Object.hashAll(recommendations),
  );
}
