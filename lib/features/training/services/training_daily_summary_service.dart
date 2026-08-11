import '../../../core/engine/training_summary.dart';
import '../models/training_record_read_model.dart';
import 'training_cardio_calorie_calculator.dart';
import 'training_cardio_energy_service.dart';
import 'training_energy_service.dart';
import 'training_v2_statistics_service.dart';

class TrainingDailySummary {
  final int sessionCount;
  final int v2SessionCount;
  final int exerciseCount;
  final int mainSetCount;
  final int legacySetCount;
  final int cardioEntryCount;
  final List<String> sessionNames;
  final List<String> sessionGrades;
  final double? trainingCardioCaloriesKcal;
  final double? trainingStrengthCaloriesKcal;
  final double? trainingEstimatedCaloriesKcal;
  final int computedCardioCount;
  final int uncomputedCardioCount;
  final TrainingEnergyCalculationStatus energyCalculationStatus;
  final TrainingEnergyCalculationStatus totalEnergyCalculationStatus;

  const TrainingDailySummary({
    required this.sessionCount,
    required this.v2SessionCount,
    required this.exerciseCount,
    required this.mainSetCount,
    required this.legacySetCount,
    required this.cardioEntryCount,
    required this.sessionNames,
    required this.sessionGrades,
    required this.trainingCardioCaloriesKcal,
    required this.trainingStrengthCaloriesKcal,
    required this.trainingEstimatedCaloriesKcal,
    required this.computedCardioCount,
    required this.uncomputedCardioCount,
    required this.energyCalculationStatus,
    required this.totalEnergyCalculationStatus,
  });

  bool get recorded => sessionCount > 0;
  bool get hasV2 => v2SessionCount > 0;
  bool get hasPartialCardioCalculation =>
      energyCalculationStatus == TrainingEnergyCalculationStatus.partial;
  int get displaySetCount => hasV2 ? mainSetCount : legacySetCount;

  TrainingSummary? toDashboardSummary() {
    if (!recorded) return null;
    return TrainingSummary(
      completed: true,
      exerciseCount: exerciseCount,
      setCount: displaySetCount,
      duration: null,
      sessionName: sessionCount > 1
          ? '$sessionCount sessions'
          : sessionNames.firstOrNull,
      trainingCardioCaloriesKcal: trainingCardioCaloriesKcal,
      trainingStrengthCaloriesKcal: trainingStrengthCaloriesKcal,
      trainingEstimatedCaloriesKcal: trainingEstimatedCaloriesKcal,
      computedCardioCount: computedCardioCount,
      uncomputedCardioCount: uncomputedCardioCount,
      energyCalculationStatus: energyCalculationStatus,
      totalEnergyCalculationStatus: totalEnergyCalculationStatus,
      energyCalculationVersion: TrainingCardioCalorieCalculator.version,
    );
  }
}

abstract final class TrainingDailySummaryService {
  static TrainingDailySummary calculate({
    required Iterable<TrainingRecordReadModel> preferredRecords,
    required String localDate,
  }) {
    final records = preferredRecords
        .where((record) => record.localDate == localDate)
        .toList(growable: false);
    var exerciseCount = 0;
    var v2SessionCount = 0;
    var mainSetCount = 0;
    var legacySetCount = 0;
    var cardioCount = 0;
    final names = <String>[];
    final grades = <String>[];
    for (final record in records) {
      final v2 = record.v2Data;
      if (v2 != null) {
        v2SessionCount++;
        exerciseCount += v2.exercises.length;
        cardioCount += v2.cardioEntries.length;
        mainSetCount += v2.exercises.fold(
          0,
          (sum, exercise) =>
              sum +
              TrainingV2StatisticsService.calculate(exercise).mainSetCount,
        );
        final name = v2.sessionName?.trim();
        if (name != null && name.isNotEmpty) names.add(name);
        final grade = v2.sessionGrade?.displayLabel;
        if (grade != null) grades.add(grade);
        continue;
      }
      final v1 = record.v1Data!;
      exerciseCount += v1.exercises.length;
      cardioCount += v1.cardioEntries.length;
      legacySetCount += v1.exercises.fold(
        0,
        (sum, exercise) => sum + exercise.sets.length,
      );
      final name = v1.memo.trim().isNotEmpty
          ? v1.memo.trim()
          : v1.exercises.firstOrNull?.exerciseName;
      if (name != null && name.isNotEmpty) names.add(name);
    }
    final energy = TrainingCardioEnergyService.summarize(
      preferredRecords: records,
      localDate: localDate,
    );
    final totalEnergy = TrainingEnergyService.summarize(
      preferredRecords: records,
      localDate: localDate,
    );
    return TrainingDailySummary(
      sessionCount: records.length,
      v2SessionCount: v2SessionCount,
      exerciseCount: exerciseCount,
      mainSetCount: mainSetCount,
      legacySetCount: legacySetCount,
      cardioEntryCount: cardioCount,
      sessionNames: List.unmodifiable(names),
      sessionGrades: List.unmodifiable(grades),
      trainingCardioCaloriesKcal: energy.trainingCardioCaloriesKcal,
      trainingStrengthCaloriesKcal: totalEnergy.trainingStrengthCaloriesKcal,
      trainingEstimatedCaloriesKcal: totalEnergy.trainingEstimatedCaloriesKcal,
      computedCardioCount: energy.computedCardioCount,
      uncomputedCardioCount: energy.uncomputedCardioCount,
      energyCalculationStatus: energy.status,
      totalEnergyCalculationStatus: totalEnergy.status,
    );
  }
}
