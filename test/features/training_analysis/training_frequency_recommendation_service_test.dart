import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training_analysis/services/training_frequency_recommendation_service.dart';

void main() {
  const service = TrainingFrequencyRecommendationService();
  final now = DateTime.parse('2026-06-01T00:00:00Z');

  test('uses the TARGET recovery maximum and never SUPPORT muscles', () {
    final records = _records(
      exercise: 'Leg Press',
      starts: const ['2026-01-01T09:00:00+09:00'],
    );
    final recommendation = service
        .build(target: records.single, records: records, now: now)
        .single;

    expect(recommendation.recoveryReferenceHours, 72);
    expect(
      recommendation.status,
      TrainingFrequencyRecommendationStatus.baselineOnly,
    );
    expect(recommendation.recommendedMinHours, 72);
    expect(recommendation.recommendedMaxHours, isNull);
    expect(recommendation.confidence, TrainingFrequencyConfidence.insufficient);
  });

  test('personalizes from the latest three supported exact pairs', () {
    final records = _records(
      starts: const [
        '2026-01-01T09:00:00+09:00',
        '2026-01-04T09:00:00+09:00',
        '2026-01-08T09:00:00+09:00',
        '2026-01-13T09:00:00+09:00',
      ],
      weights: const [70, 70, 72, 72],
      reps: const [8, 8, 8, 8],
    );
    final recommendation = service
        .build(target: records.last, records: records, now: now)
        .single;

    expect(
      recommendation.status,
      TrainingFrequencyRecommendationStatus.personalized,
    );
    expect(recommendation.confidence, TrainingFrequencyConfidence.medium);
    expect(recommendation.validObservationCount, 3);
    expect(recommendation.supportedObservationCount, 3);
    expect(recommendation.recoveryReferenceHours, 48);
    expect(recommendation.recommendedMinHours, 71);
    expect(recommendation.recommendedMaxHours, 119);
    expect(
      recommendation.evidence.every((value) => value.intervalHours >= 48),
      isTrue,
    );
  });

  test(
    'keeps a short observed interval but clamps recommendation to baseline',
    () {
      final records = _records(
        starts: const [
          '2026-01-01T09:00:00+09:00',
          '2026-01-02T21:00:00+09:00',
          '2026-01-04T09:00:00+09:00',
          '2026-01-06T09:00:00+09:00',
        ],
      );
      final recommendation = service
          .build(target: records.last, records: records, now: now)
          .single;

      expect(recommendation.observedMinHours, lessThan(48));
      expect(
        recommendation.status,
        TrainingFrequencyRecommendationStatus.personalized,
      );
      expect(recommendation.recommendedMinHours, 48);
    },
  );

  test('excludes long gaps from personalized recommendation evidence', () {
    final records = _records(
      starts: const [
        '2026-01-01T09:00:00+09:00',
        '2026-01-20T09:00:00+09:00',
        '2026-01-23T09:00:00+09:00',
        '2026-01-26T09:00:00+09:00',
        '2026-01-29T09:00:00+09:00',
      ],
    );
    final recommendation = service
        .build(target: records.last, records: records, now: now)
        .single;

    expect(recommendation.longGapObservationCount, 1);
    expect(recommendation.validObservationCount, 3);
    expect(
      recommendation.status,
      TrainingFrequencyRecommendationStatus.personalized,
    );
    expect(recommendation.recommendedMaxHours, 71);
  });

  test('uses only the latest five valid exact observations', () {
    final records = _records(
      starts: const [
        '2026-01-01T09:00:00+09:00',
        '2026-01-04T09:00:00+09:00',
        '2026-01-07T09:00:00+09:00',
        '2026-01-10T09:00:00+09:00',
        '2026-01-13T09:00:00+09:00',
        '2026-01-16T09:00:00+09:00',
        '2026-01-19T09:00:00+09:00',
      ],
    );
    final recommendation = service
        .build(target: records.last, records: records, now: now)
        .single;

    expect(recommendation.validObservationCount, 5);
    expect(recommendation.evidence.first.previousRecordId, 'record:1');
  });

  test('does not force a range when comparable evidence conflicts', () {
    final records = _records(
      starts: const [
        '2026-01-01T09:00:00+09:00',
        '2026-01-04T09:00:00+09:00',
        '2026-01-07T09:00:00+09:00',
        '2026-01-10T09:00:00+09:00',
      ],
      weights: const [80, 70, 60, 50],
    );
    final recommendation = service
        .build(target: records.last, records: records, now: now)
        .single;

    expect(
      recommendation.status,
      TrainingFrequencyRecommendationStatus.conflicting,
    );
    expect(recommendation.confidence, TrainingFrequencyConfidence.low);
    expect(recommendation.recommendedMaxHours, isNull);
  });

  test('does not treat load progression with lower reps as a regression', () {
    final records = _records(
      starts: const ['2026-01-01T09:00:00+09:00', '2026-01-04T09:00:00+09:00'],
      weights: const [203, 253],
      reps: const [8, 5],
    );
    final recommendation = service
        .build(target: records.last, records: records, now: now)
        .single;

    expect(
      recommendation.evidence.single.classification,
      TrainingFrequencyObservationClassification.limited,
    );
    expect(
      recommendation.evidence.single.reasonCodes,
      contains(TrainingFrequencyReasonCode.loadProgression),
    );
  });

  test('does not mix different equipment identities', () {
    final records = _records(
      starts: const ['2026-01-01T09:00:00+09:00', '2026-01-04T09:00:00+09:00'],
      exercise: 'Bench Press',
      equipmentNames: const [null, 'Power Rack'],
    );
    final recommendation = service
        .build(target: records.last, records: records, now: now)
        .single;

    expect(recommendation.validObservationCount, 0);
    expect(
      recommendation.status,
      TrainingFrequencyRecommendationStatus.baselineOnly,
    );
  });

  test('keeps RPE contextual and supports lower RPE at comparable work', () {
    final records = _records(
      starts: const ['2026-01-01T09:00:00+09:00', '2026-01-04T09:00:00+09:00'],
      rpes: const [9, 7],
    );
    final recommendation = service
        .build(target: records.last, records: records, now: now)
        .single;

    expect(
      recommendation.evidence.single.classification,
      TrainingFrequencyObservationClassification.supported,
    );
    expect(
      recommendation.evidence.single.reasonCodes,
      contains(TrainingFrequencyReasonCode.rpeLowerAtComparableWork),
    );
  });

  test('does not use missing endTime or legacy records as exact evidence', () {
    final legacy = TrainingRecordReadModel.v1(
      id: 'legacy',
      localDate: '2026-01-01',
      createdAt: DateTime.parse('2026-01-01T09:00:00+09:00'),
      updatedAt: DateTime.parse('2026-01-01T09:00:00+09:00'),
      data: TrainingSession(
        date: '2026-01-01',
        memo: '',
        exercises: const [
          TrainingExercise(
            exerciseName: 'Bench Press',
            order: 1,
            sets: [TrainingSet(setNo: 1, weight: 70, reps: 8)],
          ),
        ],
      ),
    );
    final target = _record(
      id: 'missing-end',
      start: '2026-01-04T09:00:00+09:00',
      exercise: 'Bench Press',
      weight: 70,
      reps: 8,
      hasEndTime: false,
    );
    final recommendation = service
        .build(target: target, records: [legacy, target], now: now)
        .single;

    expect(recommendation.validObservationCount, 0);
    expect(
      recommendation.status,
      TrainingFrequencyRecommendationStatus.baselineOnly,
    );
    expect(recommendation.recommendedMinHours, 48);
  });

  test('excludes future timestamps from exact evidence', () {
    final futureTarget = _record(
      id: 'future',
      start: '2026-07-01T09:00:00+09:00',
      exercise: 'Bench Press',
      weight: 70,
      reps: 8,
    );
    final past = _record(
      id: 'past',
      start: '2026-01-01T09:00:00+09:00',
      exercise: 'Bench Press',
      weight: 70,
      reps: 8,
    );
    final recommendation = service
        .build(target: futureTarget, records: [past, futureTarget], now: now)
        .single;

    expect(recommendation.validObservationCount, 0);
    expect(recommendation.latestObservedIntervalHours, isNull);
  });

  test('returns unavailable for an unmapped exercise without inference', () {
    final records = _records(
      exercise: 'Custom Movement',
      starts: const ['2026-01-01T09:00:00+09:00'],
    );
    final recommendation = service
        .build(target: records.single, records: records, now: now)
        .single;

    expect(
      recommendation.status,
      TrainingFrequencyRecommendationStatus.unavailable,
    );
    expect(recommendation.recommendedMinHours, isNull);
    expect(recommendation.recoveryReferenceHours, isNull);
  });
}

List<TrainingRecordReadModel> _records({
  String exercise = 'Bench Press',
  required List<String> starts,
  List<double>? weights,
  List<int>? reps,
  List<int?>? rpes,
  List<String>? names,
  List<String?>? equipmentNames,
}) => [
  for (var index = 0; index < starts.length; index++)
    _record(
      id: 'record:$index',
      start: starts[index],
      exercise: names?[index] ?? exercise,
      weight: weights?[index] ?? 70,
      reps: reps?[index] ?? 8,
      rpe: rpes?[index] ?? 8,
      equipmentName: equipmentNames?[index],
    ),
];

TrainingRecordReadModel _record({
  required String id,
  required String start,
  required String exercise,
  required double weight,
  required int reps,
  int? rpe,
  bool hasEndTime = true,
  String? equipmentName,
}) {
  final startTime = DateTime.parse(start);
  final end = startTime.add(const Duration(hours: 1));
  return TrainingRecordReadModel.v2(
    id: id,
    localDate: start.substring(0, 10),
    createdAt: startTime,
    updatedAt: startTime,
    data: TrainingSessionV2(
      date: start,
      startTime: start,
      endTime: hasEndTime ? end.toIso8601String() : null,
      exercises: [
        TrainingExerciseV2(
          exerciseName: exercise,
          order: 1,
          equipment: equipmentName == null
              ? null
              : TrainingEquipmentSnapshot(name: equipmentName),
          sets: [
            TrainingSetV2(
              setNo: 1,
              setType: TrainingSetType.main,
              weightKg: weight,
              reps: reps,
              rpe: rpe,
            ),
          ],
        ),
      ],
    ),
  );
}
