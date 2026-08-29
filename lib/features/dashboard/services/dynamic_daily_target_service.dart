import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/operation_engine.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/models/morning_data.dart';
import '../../morning/models/morning_fact.dart';
import '../../status/repositories/status_repository.dart';
import '../../training/models/training_record_read_model.dart';
import '../../training/repository/training_session_repository.dart';
import '../models/dynamic_daily_target.dart';

class DynamicDailyTargetService {
  const DynamicDailyTargetService({
    required this.statusRepository,
    required this.trainingRepository,
  });

  final StatusRepository statusRepository;
  final TrainingSessionRepository trainingRepository;

  Future<DynamicDailyTargetResult> load({
    required String operationDate,
    required MorningFact? currentStatus,
    required FoodSummary? food,
    required ActivitySummary activity,
    required TrainingSummary? training,
  }) async {
    final date = DateTime.parse(operationDate);
    final start = DateTime(date.year, date.month, date.day - 13);
    final statusRecords = await statusRepository.getRange(
      _formatDate(start),
      operationDate,
    );
    final trainingRecords = await trainingRepository.findRecordsByLocalDate(
      operationDate,
    );
    final trainingEnergy = training?.trainingEstimatedCaloriesKcal;
    final energyAvailable =
        trainingRecords.isEmpty ||
        (training?.totalEnergyCalculationStatus !=
                TrainingEnergyCalculationStatus.notCalculated &&
            trainingEnergy != null);

    return DynamicDailyTargetEngine.evaluate(
      operationDate: operationDate,
      statusHistory: statusRecords.values,
      currentStatus: currentStatus,
      currentCaloriesKcal: food == null || food.mealCount == 0
          ? null
          : food.calories,
      currentProteinG: food == null || food.mealCount == 0
          ? null
          : food.protein,
      currentWaterMl: food?.waterRecorded == true ? food!.hydrationMl : null,
      formalTrainingRecorded: trainingRecords.isNotEmpty,
      formalCardioAtLeast30Minutes: trainingRecords.any(_hasThirtyMinuteCardio),
      trainingEnergyKcal: energyAvailable ? trainingEnergy ?? 0 : null,
    );
  }

  static bool _hasThirtyMinuteCardio(TrainingRecordReadModel record) {
    final legacy = record.v1Data;
    if (legacy != null) {
      return legacy.cardioEntries.any((entry) => entry.durationMinutes >= 30);
    }
    return record.v2Data!.cardioEntries.any(
      (entry) => entry.durationSeconds >= 30 * 60,
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

abstract final class DynamicDailyTargetEngine {
  static DynamicDailyTargetResult evaluate({
    required String operationDate,
    required Iterable<MorningData> statusHistory,
    required MorningFact? currentStatus,
    required double? currentCaloriesKcal,
    required double? currentProteinG,
    required double? currentWaterMl,
    required bool formalTrainingRecorded,
    required bool formalCardioAtLeast30Minutes,
    required double? trainingEnergyKcal,
  }) {
    final referenceBody = _referenceBody(operationDate, statusHistory);
    final weight = referenceBody.weight.value;
    final estimatedBaseBurn = currentStatus == null || weight == null
        ? null
        : const OperationEngine().estimateTDEEFromFacts(
            weightKg: weight,
            workHours: currentStatus.workHours,
          );
    final estimatedBurn =
        estimatedBaseBurn == null || trainingEnergyKcal == null
        ? null
        : estimatedBaseBurn + trainingEnergyKcal;

    return DynamicDailyTargetResult(
      ruleVersion: DynamicDailyTargetResult.currentRuleVersion,
      referenceBody: referenceBody,
      estimatedBaseBurnKcal: estimatedBaseBurn,
      estimatedTotalBurnKcal: estimatedBurn,
      calories: _calories(currentCaloriesKcal, estimatedBurn),
      protein: _protein(currentProteinG, referenceBody.leanMassKg),
      water: _water(
        current: currentWaterMl,
        referenceWeightKg: weight,
        formalTrainingRecorded: formalTrainingRecorded,
        formalCardioAtLeast30Minutes: formalCardioAtLeast30Minutes,
      ),
    );
  }

  static ReferenceBodyState _referenceBody(
    String operationDate,
    Iterable<MorningData> history,
  ) {
    final weight = _reference(
      operationDate,
      history,
      (record) => record.weight,
      (value) => value > 0,
    );
    final bodyFat = _reference(
      operationDate,
      history,
      (record) => record.bodyFat,
      (value) => value >= 0 && value <= 100,
    );
    final leanMass = weight.value == null || bodyFat.value == null
        ? null
        : weight.value! * (1 - bodyFat.value! / 100);
    return ReferenceBodyState(
      weight: weight,
      bodyFat: bodyFat,
      leanMassKg: leanMass,
    );
  }

  static DerivedBodyReference _reference(
    String operationDate,
    Iterable<MorningData> history,
    double? Function(MorningData record) select,
    bool Function(double value) valid,
  ) {
    final target = DateTime.parse(operationDate);
    List<double> valuesFor(int days) {
      final start = DateTime(target.year, target.month, target.day - days + 1);
      return [
        for (final record in history)
          if (DateTime.tryParse(record.date) case final DateTime date)
            if (!_dateOnly(date).isBefore(start) &&
                !_dateOnly(date).isAfter(target))
              if (select(record) case final double value)
                if (value.isFinite && valid(value)) value,
      ];
    }

    final seven = valuesFor(7);
    if (seven.length >= 3) {
      return DerivedBodyReference(
        value: _mean(seven),
        sourceType: BodyReferenceSourceType.sevenDayMean,
        sampleCount: seven.length,
        windowDays: 7,
      );
    }
    final fourteen = valuesFor(14);
    if (fourteen.length >= 3) {
      return DerivedBodyReference(
        value: _mean(fourteen),
        sourceType: BodyReferenceSourceType.fourteenDayMean,
        sampleCount: fourteen.length,
        windowDays: 14,
      );
    }
    for (final record in history) {
      final date = DateTime.tryParse(record.date);
      if (date == null || _localDate(date) != operationDate) continue;
      final value = select(record);
      if (value != null && value.isFinite && valid(value)) {
        return DerivedBodyReference(
          value: value,
          sourceType: BodyReferenceSourceType.measuredToday,
          sampleCount: 1,
          windowDays: 1,
        );
      }
    }
    return const DerivedBodyReference.notAvailable();
  }

  static DynamicRangeTarget _calories(double? current, double? burn) {
    if (burn == null) {
      return DynamicRangeTarget(
        current: current,
        low: null,
        high: null,
        availability: DynamicTargetAvailability.notAvailable,
        state: DynamicTargetState.neutral,
      );
    }
    final low = burn * 0.75;
    final high = burn * 0.85;
    final state = current == null
        ? DynamicTargetState.neutral
        : current < burn * 0.60
        ? DynamicTargetState.redLow
        : current < low
        ? DynamicTargetState.yellowLow
        : current <= high
        ? DynamicTargetState.green
        : current <= burn
        ? DynamicTargetState.yellowHigh
        : DynamicTargetState.redHigh;
    return DynamicRangeTarget(
      current: current,
      low: low,
      high: high,
      availability: DynamicTargetAvailability.available,
      state: state,
    );
  }

  static DynamicRangeTarget _protein(double? current, double? leanMass) {
    if (leanMass == null) {
      return DynamicRangeTarget(
        current: current,
        low: null,
        high: null,
        availability: DynamicTargetAvailability.notAvailable,
        state: DynamicTargetState.neutral,
      );
    }
    final low = leanMass * 1.8;
    final high = leanMass * 2.2;
    final state = current == null
        ? DynamicTargetState.neutral
        : current < low * 0.70
        ? DynamicTargetState.redLow
        : current < low
        ? DynamicTargetState.yellowLow
        : current <= high
        ? DynamicTargetState.green
        : current <= high * 1.30
        ? DynamicTargetState.greenHigh
        : DynamicTargetState.yellowHigh;
    return DynamicRangeTarget(
      current: current,
      low: low,
      high: high,
      availability: DynamicTargetAvailability.available,
      state: state,
    );
  }

  static DynamicWaterTarget _water({
    required double? current,
    required double? referenceWeightKg,
    required bool formalTrainingRecorded,
    required bool formalCardioAtLeast30Minutes,
  }) {
    if (referenceWeightKg == null) {
      return DynamicWaterTarget(
        current: current,
        baseTargetMl: null,
        stepsAdjustmentMl: 0,
        trainingAdjustmentMl: formalTrainingRecorded ? 250 : 0,
        cardioAdjustmentMl: formalCardioAtLeast30Minutes ? 250 : 0,
        finalTargetMl: null,
        availability: DynamicTargetAvailability.notAvailable,
        state: DynamicTargetState.neutral,
        trainingAdjustmentSource: formalTrainingRecorded
            ? TrainingAdjustmentSource.formalRecord
            : TrainingAdjustmentSource.noneConfirmed,
      );
    }
    final base = (referenceWeightKg * 30).clamp(2500.0, 3500.0);
    final trainingAdjustment = formalTrainingRecorded ? 250.0 : 0.0;
    final cardioAdjustment = formalCardioAtLeast30Minutes ? 250.0 : 0.0;
    final target = base + trainingAdjustment + cardioAdjustment;
    const availability = DynamicTargetAvailability.available;
    final state =
        availability != DynamicTargetAvailability.available ||
            current == null ||
            current < target
        ? DynamicTargetState.neutral
        : DynamicTargetState.green;
    return DynamicWaterTarget(
      current: current,
      baseTargetMl: base,
      stepsAdjustmentMl: 0,
      trainingAdjustmentMl: trainingAdjustment,
      cardioAdjustmentMl: cardioAdjustment,
      finalTargetMl: target,
      availability: availability,
      state: state,
      trainingAdjustmentSource: formalTrainingRecorded
          ? TrainingAdjustmentSource.formalRecord
          : TrainingAdjustmentSource.noneConfirmed,
    );
  }

  static double _mean(List<double> values) =>
      values.fold<double>(0, (sum, value) => sum + value) / values.length;

  static String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
