import '../../../core/engine/training_summary.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../models/training_record_read_model.dart';
import 'training_cardio_calorie_calculator.dart';

class TrainingCardioEnergySummary {
  final int computedCardioCount;
  final int uncomputedCardioCount;
  final double? trainingCardioCaloriesKcal;
  final TrainingEnergyCalculationStatus status;

  const TrainingCardioEnergySummary({
    required this.computedCardioCount,
    required this.uncomputedCardioCount,
    required this.trainingCardioCaloriesKcal,
    required this.status,
  });

  bool get hasPartialCardioCalculation =>
      status == TrainingEnergyCalculationStatus.partial;
}

abstract final class TrainingCardioEnergyService {
  static bool requiresStatusWeight(TrainingSessionV2 session) {
    return session.cardioEntries.any((entry) {
      if (isFormalCalculation(entry) || entry.weightSnapshotKg != null) {
        return false;
      }
      return TrainingCardioCalorieCalculator.calculate(
        mets: entry.mets,
        durationSeconds: entry.durationSeconds,
        weightKg: 1,
      ).isComputed;
    });
  }

  static TrainingSessionV2 applyForSave({
    required TrainingSessionV2 session,
    required double? statusWeightKg,
  }) {
    return TrainingSessionV2(
      date: session.date,
      sessionName: session.sessionName,
      sessionGrade: session.sessionGrade,
      memo: session.memo,
      dynamicStretchCompleted: session.dynamicStretchCompleted,
      cooldownStretchCompleted: session.cooldownStretchCompleted,
      overallEvaluation: session.overallEvaluation,
      exercises: session.exercises,
      cardioEntries: [
        for (final entry in session.cardioEntries)
          _apply(entry, statusWeightKg: statusWeightKg),
      ],
    );
  }

  static TrainingCardioEnergySummary summarize({
    required Iterable<TrainingRecordReadModel> preferredRecords,
    required String localDate,
  }) {
    var computed = 0;
    var uncomputed = 0;
    var calories = 0.0;
    for (final record in preferredRecords) {
      if (record.localDate != localDate) continue;
      final v2 = record.v2Data;
      if (v2 == null) {
        uncomputed += record.v1Data!.cardioEntries.length;
        continue;
      }
      for (final entry in v2.cardioEntries) {
        if (isFormalCalculation(entry)) {
          computed++;
          calories += entry.estimatedCaloriesKcal!;
        } else {
          uncomputed++;
        }
      }
    }
    final status = uncomputed == 0
        ? TrainingEnergyCalculationStatus.complete
        : computed == 0
        ? TrainingEnergyCalculationStatus.notCalculated
        : TrainingEnergyCalculationStatus.partial;
    return TrainingCardioEnergySummary(
      computedCardioCount: computed,
      uncomputedCardioCount: uncomputed,
      trainingCardioCaloriesKcal: computed == 0 && uncomputed > 0
          ? null
          : calories,
      status: status,
    );
  }

  static CardioEntryV2 _apply(
    CardioEntryV2 entry, {
    required double? statusWeightKg,
  }) {
    if (isFormalCalculation(entry)) {
      return entry;
    }
    final result = TrainingCardioCalorieCalculator.calculate(
      mets: entry.mets,
      durationSeconds: entry.durationSeconds,
      weightKg: entry.weightSnapshotKg ?? statusWeightKg,
    );
    return CardioEntryV2(
      purpose: entry.purpose,
      type: entry.type,
      equipment: entry.equipment,
      durationSeconds: entry.durationSeconds,
      distanceKm: entry.distanceKm,
      mets: entry.mets,
      averageHeartRateBpm: entry.averageHeartRateBpm,
      maximumHeartRateBpm: entry.maximumHeartRateBpm,
      averageSpeedKmh: entry.averageSpeedKmh,
      estimatedCaloriesKcal: result.estimatedCaloriesKcal,
      weightSnapshotKg: result.isComputed
          ? result.weightSnapshotKg
          : entry.weightSnapshotKg,
      calculationMethod: result.calculationMethod,
      calculationVersion: result.calculationVersion,
      notes: entry.notes,
      legacyIntensity: entry.legacyIntensity,
      legacyReferenceCaloriesKcal: entry.legacyReferenceCaloriesKcal,
    );
  }

  static bool isFormalCalculation(CardioEntryV2 entry) {
    final calories = entry.estimatedCaloriesKcal;
    final weight = entry.weightSnapshotKg;
    if (calories == null ||
        !calories.isFinite ||
        calories < 0 ||
        weight == null ||
        !weight.isFinite ||
        weight <= 0 ||
        entry.calculationMethod != TrainingCardioCalorieCalculator.method ||
        entry.calculationVersion != TrainingCardioCalorieCalculator.version) {
      return false;
    }
    final recalculated = TrainingCardioCalorieCalculator.calculate(
      mets: entry.mets,
      durationSeconds: entry.durationSeconds,
      weightKg: weight,
    ).estimatedCaloriesKcal;
    return recalculated != null && (recalculated - calories).abs() <= 1e-9;
  }
}
