import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/dashboard/models/dynamic_daily_target.dart';
import 'package:or_app/features/dashboard/services/dynamic_daily_target_service.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  group('human-facing representative targets', () {
    test('rounds range midpoints without changing raw ranges', () {
      const calories = DynamicRangeTarget(
        current: 1000,
        low: 2195,
        high: 2488,
        availability: DynamicTargetAvailability.available,
        state: DynamicTargetState.yellowLow,
      );
      const protein = DynamicRangeTarget(
        current: 80,
        low: 116.7,
        high: 142.7,
        availability: DynamicTargetAvailability.available,
        state: DynamicTargetState.redLow,
      );

      expect(DynamicDailyTargetPresentation.caloriesTargetKcal(calories), 2350);
      expect(DynamicDailyTargetPresentation.proteinTargetG(protein), 130);
      expect(calories.low, 2195);
      expect(calories.high, 2488);
      expect(calories.state, DynamicTargetState.yellowLow);
      expect(protein.low, 116.7);
      expect(protein.high, 142.7);
      expect(protein.state, DynamicTargetState.redLow);
    });

    test('rounds water display target without changing its raw target', () {
      for (final value in [(2867.0, 2900), (3117.0, 3100), (3367.0, 3400)]) {
        final water = DynamicWaterTarget(
          current: 1000,
          baseTargetMl: value.$1,
          stepsAdjustmentMl: 0,
          trainingAdjustmentMl: 0,
          cardioAdjustmentMl: 0,
          finalTargetMl: value.$1,
          availability: DynamicTargetAvailability.available,
          state: DynamicTargetState.neutral,
          trainingAdjustmentSource: TrainingAdjustmentSource.noneConfirmed,
        );
        expect(DynamicDailyTargetPresentation.waterTargetMl(water), value.$2);
        expect(water.finalTargetMl, value.$1);
      }
    });
  });

  group('reference body', () {
    test('uses independent seven-day means and derives lean mass', () {
      final result = _evaluate(
        history: [
          _status('2026-08-04', weight: 90, bodyFat: null),
          _status('2026-08-05', weight: 93, bodyFat: 20),
          _status('2026-08-06', weight: 96, bodyFat: 22),
          _status('2026-08-10', weight: null, bodyFat: 24),
        ],
      );

      expect(result.ruleVersion, 'DDT-v1');
      expect(result.referenceBody.weight.value, 93);
      expect(
        result.referenceBody.weight.sourceType,
        BodyReferenceSourceType.sevenDayMean,
      );
      expect(result.referenceBody.weight.sampleCount, 3);
      expect(result.referenceBody.bodyFat.value, 22);
      expect(result.referenceBody.leanMassKg, closeTo(72.54, 0.001));
    });

    test('extends to fourteen days but never uses older values', () {
      final extended = _evaluate(
        history: [
          _status('2026-07-28', weight: 84),
          _status('2026-08-03', weight: 87),
          _status('2026-08-09', weight: 90),
        ],
      );
      expect(extended.referenceBody.weight.value, 87);
      expect(
        extended.referenceBody.weight.sourceType,
        BodyReferenceSourceType.fourteenDayMean,
      );

      final unavailable = _evaluate(
        history: [
          _status('2026-07-27', weight: 80),
          _status('2026-08-09', weight: 90),
        ],
      );
      expect(unavailable.referenceBody.weight.value, isNull);
    });

    test('uses measured today only when a mean cannot be formed', () {
      final result = _evaluate(
        history: [_status('2026-08-10', weight: 91, bodyFat: 25)],
      );
      expect(result.referenceBody.weight.value, 91);
      expect(
        result.referenceBody.weight.sourceType,
        BodyReferenceSourceType.measuredToday,
      );
    });
  });

  group('calories and protein', () {
    test('applies the DDT-v1 calorie bands without a fixed fallback', () {
      for (final value in [
        (1799.0, DynamicTargetState.redLow),
        (1800.0, DynamicTargetState.yellowLow),
        (2250.0, DynamicTargetState.green),
        (2550.0, DynamicTargetState.green),
        (2551.0, DynamicTargetState.yellowHigh),
        (3001.0, DynamicTargetState.redHigh),
      ]) {
        final result = _evaluate(
          history: _referenceHistory(weight: 3000 / 22),
          calories: value.$1,
          workHours: 0,
        );
        expect(result.estimatedTotalBurnKcal, closeTo(3000, 0.01));
        expect(result.calories.low, closeTo(2250, 0.01));
        expect(result.calories.high, closeTo(2550, 0.01));
        expect(result.calories.state, value.$2);
      }

      final unavailable = _evaluate(history: const [], calories: 2200);
      expect(
        unavailable.calories.availability,
        DynamicTargetAvailability.notAvailable,
      );
      expect(unavailable.calories.low, isNull);
      expect(unavailable.calories.state, DynamicTargetState.neutral);
    });

    test('uses lean mass for protein bands and tolerates moderate excess', () {
      for (final value in [
        (80.0, DynamicTargetState.redLow),
        (82.0, DynamicTargetState.yellowLow),
        (117.0, DynamicTargetState.green),
        (143.0, DynamicTargetState.green),
        (150.0, DynamicTargetState.greenHigh),
        (190.0, DynamicTargetState.yellowHigh),
      ]) {
        final result = _evaluate(
          history: _referenceHistory(weight: 81.25, bodyFat: 20),
          protein: value.$1,
        );
        expect(result.referenceBody.leanMassKg, closeTo(65, 0.001));
        expect(result.protein.low, closeTo(117, 0.001));
        expect(result.protein.high, closeTo(143, 0.001));
        expect(result.protein.state, value.$2);
      }
    });
  });

  group('water', () {
    test('clamps base and adds current confirmed adjustments', () {
      final low = _evaluate(history: _referenceHistory(weight: 60), steps: 0);
      expect(low.water.baseTargetMl, 2500);

      final high = _evaluate(
        history: _referenceHistory(weight: 130),
        steps: 12000,
        trainingRecorded: true,
        cardioAtLeast30Minutes: true,
      );
      expect(high.water.baseTargetMl, 3500);
      expect(high.water.stepsAdjustmentMl, 0);
      expect(high.water.trainingAdjustmentMl, 250);
      expect(high.water.cardioAdjustmentMl, 250);
      expect(high.water.finalTargetMl, 4000);
    });

    test('does not use steps or mark missing activity partial', () {
      final targets = [
        for (final steps in [null, 7999, 8000, 12000])
          _evaluate(history: _referenceHistory(), steps: steps).water,
      ];
      final expectedTarget = targets.first.finalTargetMl;
      for (final water in targets) {
        expect(water.stepsAdjustmentMl, 0);
        expect(water.finalTargetMl, expectedTarget);
        expect(water.availability, DynamicTargetAvailability.available);
      }
    });

    test('uses the raw target for completion color', () {
      final below = _evaluate(
        history: _referenceHistory(weight: 95.57),
        water: 2867,
      );
      final above = _evaluate(
        history: _referenceHistory(weight: 95.57),
        water: 2868,
      );
      expect(below.water.finalTargetMl, closeTo(2867.1, 0.001));
      expect(below.water.state, DynamicTargetState.neutral);
      expect(above.water.state, DynamicTargetState.green);
    });

    test('intake changes progress state but never changes the target', () {
      final values = [
        _evaluate(history: _referenceHistory(weight: 90)),
        _evaluate(history: _referenceHistory(weight: 90), water: 500),
        _evaluate(history: _referenceHistory(weight: 90), water: 2700),
      ];

      expect(values.map((value) => value.water.finalTargetMl).toSet(), {2700});
      expect(values[0].water.state, DynamicTargetState.neutral);
      expect(values[1].water.state, DynamicTargetState.neutral);
      expect(values[2].water.state, DynamicTargetState.green);
    });

    test('absence of a training record is none confirmed, not skipped', () {
      final before = _evaluate(
        history: _referenceHistory(weight: 90),
        steps: 4000,
      );
      expect(before.water.finalTargetMl, 2700);
      expect(
        before.water.trainingAdjustmentSource,
        TrainingAdjustmentSource.noneConfirmed,
      );

      final after = _evaluate(
        history: _referenceHistory(weight: 90),
        steps: 4000,
        trainingRecorded: true,
      );
      expect(after.water.finalTargetMl, 2950);
      expect(
        after.water.trainingAdjustmentSource,
        TrainingAdjustmentSource.formalRecord,
      );
    });

    test('loads formal Training and 30-minute Cardio adjustments', () async {
      appInitializationController.markReady();
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      for (final record in _referenceHistory(weight: 90)) {
        await container.status.save(record);
      }
      await container.training.saveNew(
        TrainingSession(
          date: '2026-08-10',
          memo: '',
          exercises: const [],
          cardioEntries: [
            CardioEntry(
              type: CardioType.running,
              intensity: CardioIntensity.moderate,
              durationMinutes: 30,
            ),
          ],
        ),
      );

      final result =
          await DynamicDailyTargetService(
            statusRepository: container.status,
            trainingRepository: container.training,
          ).load(
            operationDate: '2026-08-10',
            currentStatus: _morningFact(weight: 90),
            food: const FoodSummary(
              calories: 1000,
              protein: 100,
              fat: 30,
              carbohydrates: 120,
              hydrationMl: 2000,
              mealCount: 2,
            ),
            activity: const ActivitySummary(
              steps: 0,
              measuredSteps: 0,
              isRecorded: true,
              calculationBasis: ActivityCalculationBasis(
                rawSteps: 0,
                currentCarryOver: 0,
                previousCarryOverDeduction: 0,
                officialSteps: 0,
              ),
            ),
            training: const TrainingSummary(
              completed: true,
              exerciseCount: 0,
              setCount: 0,
              duration: Duration(minutes: 30),
              sessionName: null,
              trainingEstimatedCaloriesKcal: 200,
              totalEnergyCalculationStatus:
                  TrainingEnergyCalculationStatus.complete,
            ),
          );

      expect(result.water.trainingAdjustmentMl, 250);
      expect(result.water.cardioAdjustmentMl, 250);
      expect(result.water.finalTargetMl, 3200);
      expect(result.estimatedTotalBurnKcal, 2180);
      expect(
        (await container.status.findByLocalDate('2026-08-10'))?.weight,
        90,
      );
    });
  });
}

DynamicDailyTargetResult _evaluate({
  List<MorningData> history = const [],
  double? calories,
  double? protein,
  double? water,
  int? steps,
  bool trainingRecorded = false,
  bool cardioAtLeast30Minutes = false,
  double workHours = 0,
}) => DynamicDailyTargetEngine.evaluate(
  operationDate: '2026-08-10',
  statusHistory: history,
  currentStatus: _morningFact(
    weight: history.lastOrNull?.weight,
    bodyFat: history.lastOrNull?.bodyFat,
    workHours: workHours,
  ),
  currentCaloriesKcal: calories,
  currentProteinG: protein,
  currentWaterMl: water,
  formalTrainingRecorded: trainingRecorded,
  formalCardioAtLeast30Minutes: cardioAtLeast30Minutes,
  trainingEnergyKcal: 0,
);

MorningFact _morningFact({
  double? weight,
  double? bodyFat = 20,
  double workHours = 0,
}) => MorningFact(
  date: DateTime(2026, 8, 10),
  weight: weight,
  bodyFat: bodyFat,
  sleepDuration: null,
  sleepScore: null,
  workHours: workHours,
  footPain: 1,
  medications: const [],
  freeNotes: null,
);

List<MorningData> _referenceHistory({
  double weight = 90,
  double bodyFat = 20,
}) => [
  _status('2026-08-08', weight: weight, bodyFat: bodyFat),
  _status('2026-08-09', weight: weight, bodyFat: bodyFat),
  _status('2026-08-10', weight: weight, bodyFat: bodyFat),
];

MorningData _status(String date, {double? weight, double? bodyFat = 20}) =>
    MorningData(
      date: date,
      weight: weight,
      bodyFat: bodyFat,
      sleepHours: null,
      sleepScore: null,
      footPain: 1,
      workType: WorkType.holiday,
      workStart: '',
      workEnd: '',
      workBreak: '',
      workHours: 0,
      memo: '',
    );
