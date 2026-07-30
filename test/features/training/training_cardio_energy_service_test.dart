import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/services/training_cardio_calorie_calculator.dart';
import 'package:or_app/features/training/services/training_cardio_energy_service.dart';

void main() {
  test('applies formal values and preserves a saved snapshot', () {
    final calculated = TrainingCardioEnergyService.applyForSave(
      session: _session([_cardio()]),
      statusWeightKg: 96.8,
    ).cardioEntries.single;

    expect(calculated.estimatedCaloriesKcal, closeTo(33.88, 1e-12));
    expect(calculated.weightSnapshotKg, 96.8);
    expect(calculated.calculationMethod, 'metsAcsmV1');
    expect(calculated.calculationVersion, 1);

    final preserved = TrainingCardioEnergyService.applyForSave(
      session: _session([calculated]),
      statusWeightKg: 120,
    ).cardioEntries.single;
    expect(preserved.estimatedCaloriesKcal, calculated.estimatedCaloriesKcal);
    expect(preserved.weightSnapshotKg, 96.8);
  });

  test('requests STATUS only when a calculable entry has no snapshot', () {
    expect(
      TrainingCardioEnergyService.requiresStatusWeight(_session(const [])),
      isFalse,
    );
    expect(
      TrainingCardioEnergyService.requiresStatusWeight(
        _session([_cardio(mets: null)]),
      ),
      isFalse,
    );
    expect(
      TrainingCardioEnergyService.requiresStatusWeight(
        _session([_cardio(weightSnapshotKg: 80)]),
      ),
      isFalse,
    );
    expect(
      TrainingCardioEnergyService.requiresStatusWeight(_session([_cardio()])),
      isTrue,
    );
  });

  test(
    'uses an existing weight snapshot when changed fields need calculation',
    () {
      final result = TrainingCardioEnergyService.applyForSave(
        session: _session([_cardio(weightSnapshotKg: 80, mets: 5)]),
        statusWeightKg: 120,
      ).cardioEntries.single;

      expect(result.weightSnapshotKg, 80);
      expect(result.estimatedCaloriesKcal, closeTo(35, 1e-12));
    },
  );

  test('saves missing inputs as uncomputed without losing input', () {
    final result = TrainingCardioEnergyService.applyForSave(
      session: _session([_cardio(mets: null)]),
      statusWeightKg: 96.8,
    ).cardioEntries.single;

    expect(result.durationSeconds, 300);
    expect(result.mets, isNull);
    expect(result.weightSnapshotKg, isNull);
    expect(result.estimatedCaloriesKcal, isNull);
    expect(result.calculationMethod, isNull);
    expect(result.calculationVersion, isNull);
  });

  test('distinguishes none, complete, partial, and not calculated', () {
    final none = TrainingCardioEnergyService.summarize(
      preferredRecords: [_record(_session(const []))],
      localDate: '2026-07-30',
    );
    expect(none.trainingCardioCaloriesKcal, 0);
    expect(none.status, TrainingEnergyCalculationStatus.complete);

    final formal = _cardio(
      weightSnapshotKg: 80,
      estimatedCaloriesKcal: 28,
      method: TrainingCardioCalorieCalculator.method,
      version: 1,
    );
    final complete = TrainingCardioEnergyService.summarize(
      preferredRecords: [
        _record(_session([formal, formal])),
      ],
      localDate: '2026-07-30',
    );
    expect(complete.trainingCardioCaloriesKcal, 56);
    expect(complete.computedCardioCount, 2);
    expect(complete.uncomputedCardioCount, 0);
    expect(complete.status, TrainingEnergyCalculationStatus.complete);

    final partial = TrainingCardioEnergyService.summarize(
      preferredRecords: [
        _record(_session([formal, _cardio()])),
      ],
      localDate: '2026-07-30',
    );
    expect(partial.trainingCardioCaloriesKcal, 28);
    expect(partial.uncomputedCardioCount, 1);
    expect(partial.status, TrainingEnergyCalculationStatus.partial);

    final missing = TrainingCardioEnergyService.summarize(
      preferredRecords: [
        _record(_session([_cardio()])),
      ],
      localDate: '2026-07-30',
    );
    expect(missing.trainingCardioCaloriesKcal, isNull);
    expect(missing.status, TrainingEnergyCalculationStatus.notCalculated);
  });

  test('does not add legacy reference or v1 cardio calories', () {
    final v2 = _cardio(legacyReferenceCaloriesKcal: 999);
    final v1 = TrainingRecordReadModel.v1(
      id: 'legacy-training:12345678:0001',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
      data: TrainingSession(
        date: '2026-07-30T12:00:00',
        memo: '',
        exercises: const [],
        cardioEntries: [
          CardioEntry(
            type: CardioType.running,
            intensity: CardioIntensity.vigorous,
            durationMinutes: 30,
          ),
        ],
      ),
    );

    final summary = TrainingCardioEnergyService.summarize(
      preferredRecords: [
        _record(_session([v2])),
        v1,
      ],
      localDate: '2026-07-30',
    );
    expect(summary.trainingCardioCaloriesKcal, isNull);
    expect(summary.uncomputedCardioCount, 2);
    expect(summary.status, TrainingEnergyCalculationStatus.notCalculated);
  });
}

TrainingSessionV2 _session(List<CardioEntryV2> entries) => TrainingSessionV2(
  date: '2026-07-30T12:00:00',
  exercises: const [],
  cardioEntries: entries,
);

CardioEntryV2 _cardio({
  double? mets = 4,
  double? weightSnapshotKg,
  double? estimatedCaloriesKcal,
  String? method,
  int? version,
  double? legacyReferenceCaloriesKcal,
}) => CardioEntryV2(
  purpose: CardioPurpose.main,
  type: CardioType.running,
  durationSeconds: 300,
  mets: mets,
  weightSnapshotKg: weightSnapshotKg,
  estimatedCaloriesKcal: estimatedCaloriesKcal,
  calculationMethod: method,
  calculationVersion: version,
  legacyReferenceCaloriesKcal: legacyReferenceCaloriesKcal,
);

TrainingRecordReadModel _record(TrainingSessionV2 session) =>
    TrainingRecordReadModel.v2(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
      data: session,
    );
