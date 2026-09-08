import 'dart:convert';

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

  /// Resolves a date-bound target from the canonical formal STATUS record.
  ///
  /// Analysis surfaces must not reconstruct the current STATUS through a
  /// separate read path: target availability depends on the formal record for
  /// the same operation date.
  Future<DynamicDailyTargetResult> loadForOperationDate({
    required String operationDate,
    required FoodSummary? food,
    required ActivitySummary activity,
    required TrainingSummary? training,
  }) async {
    final status = await statusRepository.findByLocalDate(operationDate);
    return load(
      operationDate: operationDate,
      currentStatus: status == null ? null : _toMorningFact(status),
      food: food,
      activity: activity,
      training: training,
    );
  }

  /// Observes the production target path without mutating formal data.
  ///
  /// This is intentionally narrow and temporary: it makes unavailable target
  /// results actionable on a real device instead of silently collapsing an
  /// exception into a presentation-only "not available" state.
  Future<DynamicDailyTargetDiagnostic> diagnoseForOperationDate({
    required String operationDate,
    required FoodSummary? food,
    required ActivitySummary activity,
    required TrainingSummary? training,
  }) async {
    final payload = <String, dynamic>{
      'title': 'OR-APP DAILY TARGET DIAGNOSTIC',
      'operationDate': operationDate,
      'resolver': 'DynamicDailyTargetService.loadForOperationDate',
      'statusLookup': <String, dynamic>{
        'repository': 'StatusRepository.findByLocalDate',
        'requestedOperationDate': operationDate,
      },
      'foodContext': _foodDiagnostic(food),
      'activityContext': <String, dynamic>{
        'stepsRequiredForTarget': false,
        'isRecorded': activity.isRecorded,
      },
      'trainingContext': <String, dynamic>{
        'summaryProvided': training != null,
        'energyKcal': training?.trainingEstimatedCaloriesKcal,
        'energyStatus': training?.totalEnergyCalculationStatus?.name,
      },
    };

    MorningData? status;
    try {
      status = await statusRepository.findByLocalDate(operationDate);
      payload['statusLookup'] = <String, dynamic>{
        ...payload['statusLookup'] as Map<String, dynamic>,
        'exists': status != null,
        'storedDate': status?.date,
        'canonicalDate': status == null ? null : operationDate,
      };
      payload['statusInputs'] = _statusDiagnostic(status);
    } catch (error) {
      payload['error'] = _errorDiagnostic('statusLookup', error);
      return DynamicDailyTargetDiagnostic(payload: payload);
    }

    try {
      final date = DateTime.parse(operationDate);
      final start = DateTime(date.year, date.month, date.day - 13);
      final history = await statusRepository.getRange(
        _formatDate(start),
        operationDate,
      );
      payload['statusHistory'] = <String, dynamic>{
        'rangeStart': _formatDate(start),
        'rangeEnd': operationDate,
        'recordCount': history.values.length,
        'hasReadIssues': history.hasIssues,
        'localDates': [
          for (final record in history.values) record.date.split('T').first,
        ],
      };
    } catch (error) {
      payload['error'] = _errorDiagnostic('statusHistory', error);
      return DynamicDailyTargetDiagnostic(payload: payload);
    }

    try {
      final records = await trainingRepository.findRecordsByLocalDate(
        operationDate,
      );
      payload['trainingContext'] = <String, dynamic>{
        ...payload['trainingContext'] as Map<String, dynamic>,
        'formalRecordCount': records.length,
      };
    } catch (error) {
      payload['error'] = _errorDiagnostic('trainingLookup', error);
      return DynamicDailyTargetDiagnostic(payload: payload);
    }

    try {
      final result = await loadForOperationDate(
        operationDate: operationDate,
        food: food,
        activity: activity,
        training: training,
      );
      payload['referenceBody'] = _referenceBodyDiagnostic(result.referenceBody);
      payload['calculation'] = _calculationDiagnostic(result);
      payload['result'] = <String, dynamic>{
        'nutritionTargetsAvailable': result.nutritionTargetsAvailable,
        'availabilityRule': 'allCaloriesProteinFatCarbohydrateRequired',
      };
      return DynamicDailyTargetDiagnostic(payload: payload, result: result);
    } catch (error) {
      payload['error'] = _errorDiagnostic('targetCalculation', error);
      return DynamicDailyTargetDiagnostic(payload: payload);
    }
  }

  static Map<String, dynamic> _statusDiagnostic(MorningData? status) =>
      <String, dynamic>{
        'exists': status != null,
        'weight': status?.weight,
        'bodyFat': status?.bodyFat,
        'workHours': status?.workHours,
      };

  static Map<String, dynamic> _foodDiagnostic(FoodSummary? food) =>
      <String, dynamic>{
        'summaryPresent': food != null,
        'mealCount': food?.mealCount,
        'calories': food?.calories,
        'protein': food?.protein,
        'fat': food?.fat,
        'carbohydrates': food?.carbohydrates,
      };

  static Map<String, dynamic> _referenceBodyDiagnostic(
    ReferenceBodyState reference,
  ) => <String, dynamic>{
    'weight': _derivedReferenceDiagnostic(reference.weight),
    'bodyFat': _derivedReferenceDiagnostic(reference.bodyFat),
    'leanMassKg': reference.leanMassKg,
  };

  static Map<String, dynamic> _derivedReferenceDiagnostic(
    DerivedBodyReference reference,
  ) => <String, dynamic>{
    'value': reference.value,
    'sourceType': reference.sourceType.name,
    'sampleCount': reference.sampleCount,
    'windowDays': reference.windowDays,
  };

  static Map<String, dynamic> _calculationDiagnostic(
    DynamicDailyTargetResult result,
  ) => <String, dynamic>{
    'estimatedBaseBurnKcal': result.estimatedBaseBurnKcal,
    'estimatedTotalBurnKcal': result.estimatedTotalBurnKcal,
    'calories': _rangeDiagnostic(result.calories),
    'protein': _rangeDiagnostic(result.protein),
    'fat': _rangeDiagnostic(result.fat),
    'carbohydrate': _rangeDiagnostic(result.carbohydrate),
  };

  static Map<String, dynamic> _rangeDiagnostic(DynamicRangeTarget target) =>
      <String, dynamic>{
        'availability': target.availability.name,
        'current': target.current,
        'low': target.low,
        'high': target.high,
        'state': target.state.name,
      };

  static Map<String, dynamic> _errorDiagnostic(String stage, Object error) =>
      <String, dynamic>{
        'stage': stage,
        'type': error.runtimeType.toString(),
        'message': error.toString(),
      };

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
      currentFatG: food == null || food.mealCount == 0 ? null : food.fat,
      currentCarbohydrateG: food == null || food.mealCount == 0
          ? null
          : food.carbohydrates,
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

  static MorningFact _toMorningFact(MorningData status) => MorningFact(
    date: DateTime.parse(status.date),
    weight: status.weight,
    bodyFat: status.bodyFat,
    sleepDuration: status.sleepHours == null
        ? null
        : Duration(minutes: (status.sleepHours! * 60).round()),
    sleepScore: status.sleepScore,
    workHours: status.workHours,
    footPain: status.footPain,
    condition: status.condition,
    previousCarryoverConfirmed: status.previousCarryoverConfirmed,
    medications: const [],
    freeNotes: status.memo.isEmpty ? null : status.memo,
  );

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class DynamicDailyTargetDiagnostic {
  const DynamicDailyTargetDiagnostic({required this.payload, this.result});

  final Map<String, dynamic> payload;
  final DynamicDailyTargetResult? result;

  String jsonForConsumer({
    required String consumer,
    required String operationDate,
  }) => const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
    ...payload,
    'consumer': <String, dynamic>{
      'name': consumer,
      'operationDate': operationDate,
      'receivedTargetResult': result != null,
      'nutritionTargetsAvailable': result?.nutritionTargetsAvailable,
    },
  });
}

abstract final class DynamicDailyTargetEngine {
  static DynamicDailyTargetResult evaluate({
    required String operationDate,
    required Iterable<MorningData> statusHistory,
    required MorningFact? currentStatus,
    required double? currentCaloriesKcal,
    required double? currentProteinG,
    required double? currentFatG,
    required double? currentCarbohydrateG,
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

    final calories = _calories(currentCaloriesKcal, estimatedBurn);
    final protein = _protein(currentProteinG, referenceBody.leanMassKg);
    final macroTargets = _macros(
      calories: calories,
      protein: protein,
      currentFatG: currentFatG,
      currentCarbohydrateG: currentCarbohydrateG,
    );
    return DynamicDailyTargetResult(
      ruleVersion: DynamicDailyTargetResult.currentRuleVersion,
      referenceBody: referenceBody,
      estimatedBaseBurnKcal: estimatedBaseBurn,
      estimatedTotalBurnKcal: estimatedBurn,
      calories: calories,
      protein: protein,
      fat: macroTargets.fat,
      carbohydrate: macroTargets.carbohydrate,
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

  /// Fat is a transparent 25–30% energy range. Carbohydrate receives the
  /// remaining energy after the existing calorie and protein targets plus the
  /// midpoint fat reference; this keeps the macro targets reconcilable.
  static _MacroTargets _macros({
    required DynamicRangeTarget calories,
    required DynamicRangeTarget protein,
    required double? currentFatG,
    required double? currentCarbohydrateG,
  }) {
    final calorieLow = calories.low;
    final calorieHigh = calories.high;
    final proteinLow = protein.low;
    final proteinHigh = protein.high;
    if (calorieLow == null ||
        calorieHigh == null ||
        proteinLow == null ||
        proteinHigh == null) {
      return _MacroTargets.unavailable(
        currentFatG: currentFatG,
        currentCarbohydrateG: currentCarbohydrateG,
      );
    }
    final calorieTarget = (calorieLow + calorieHigh) / 2;
    final proteinTarget = (proteinLow + proteinHigh) / 2;
    final fatLow = calorieTarget * .25 / 9;
    final fatHigh = calorieTarget * .30 / 9;
    final fatReference = (fatLow + fatHigh) / 2;
    final carbohydrateTarget =
        (calorieTarget - proteinTarget * 4 - fatReference * 9) / 4;
    if (!carbohydrateTarget.isFinite || carbohydrateTarget < 0) {
      return _MacroTargets.unavailable(
        currentFatG: currentFatG,
        currentCarbohydrateG: currentCarbohydrateG,
      );
    }
    return _MacroTargets(
      fat: DynamicRangeTarget(
        current: currentFatG,
        low: fatLow,
        high: fatHigh,
        availability: DynamicTargetAvailability.available,
        state: _rangeState(currentFatG, fatLow, fatHigh),
      ),
      carbohydrate: DynamicRangeTarget(
        current: currentCarbohydrateG,
        low: carbohydrateTarget * .95,
        high: carbohydrateTarget * 1.05,
        availability: DynamicTargetAvailability.available,
        state: _rangeState(
          currentCarbohydrateG,
          carbohydrateTarget * .95,
          carbohydrateTarget * 1.05,
        ),
      ),
    );
  }

  static DynamicTargetState _rangeState(
    double? current,
    double low,
    double high,
  ) {
    if (current == null) return DynamicTargetState.neutral;
    if (current < low) return DynamicTargetState.yellowLow;
    if (current > high) return DynamicTargetState.yellowHigh;
    return DynamicTargetState.green;
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

class _MacroTargets {
  const _MacroTargets({required this.fat, required this.carbohydrate});
  factory _MacroTargets.unavailable({
    required double? currentFatG,
    required double? currentCarbohydrateG,
  }) => _MacroTargets(
    fat: DynamicRangeTarget(
      current: currentFatG,
      low: null,
      high: null,
      availability: DynamicTargetAvailability.notAvailable,
      state: DynamicTargetState.neutral,
    ),
    carbohydrate: DynamicRangeTarget(
      current: currentCarbohydrateG,
      low: null,
      high: null,
      availability: DynamicTargetAvailability.notAvailable,
      state: DynamicTargetState.neutral,
    ),
  );
  final DynamicRangeTarget fat;
  final DynamicRangeTarget carbohydrate;
}
