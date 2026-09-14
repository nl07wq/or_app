import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training_analysis/services/recovery_evidence_shadow_v2_service.dart';
import 'package:or_app/features/training_analysis/services/training_frequency_recommendation_service.dart';

void main() {
  const service = RecoveryEvidenceShadowV2Service();
  final now = DateTime.parse('2027-01-01T00:00:00Z');

  test('keeps V1 output intact while adding a shadow result', () {
    final records = _records(weights: const [70, 70, 70, 70, 70]);
    final v1Before = const TrainingFrequencyRecommendationService()
        .build(target: records.last, records: records, now: now)
        .single;
    final shadow = service
        .build(target: records.last, records: records, now: now)
        .single;
    final v1After = const TrainingFrequencyRecommendationService()
        .build(target: records.last, records: records, now: now)
        .single;
    expect(v1After.validObservationCount, v1Before.validObservationCount);
    expect(
      v1After.supportedObservationCount,
      v1Before.supportedObservationCount,
    );
    expect(shadow.parameterVersion, 'v2-beta-1');
    expect(shadow.identity, v1Before.targetIdentity);
  });

  test('uses a five-session median baseline after three normal facts', () {
    final records = _records(weights: const [70, 70, 70, 70, 70]);
    final result = service
        .build(target: records.last, records: records, now: now)
        .single;
    expect(result.baseline, isNotNull);
    expect(result.baseline!.sampleCount, 3);
    expect(result.baseline!.maxWeight, 70);
  });

  test(
    'classifies one rep from 10 to 9 as tolerated at the beta 90 percent threshold',
    () {
      final records = _records(reps: const [10, 10, 10, 10, 9]);
      final latest = service
          .build(target: records.last, records: records, now: now)
          .single
          .latestObservation!;
      expect(
        latest.performanceBand,
        RecoveryEvidenceShadowPerformanceBand.toleratedDecline,
      );
      expect(
        latest.recoveryEvidence,
        RecoveryEvidenceShadowClassification.supported,
      );
    },
  );

  test('classifies five reps to four reps as a clear decline', () {
    final records = _records(reps: const [5, 5, 5, 5, 4]);
    final latest = service
        .build(target: records.last, records: records, now: now)
        .single
        .latestObservation!;
    expect(
      latest.performanceBand,
      RecoveryEvidenceShadowPerformanceBand.clearDecline,
    );
    expect(
      latest.recoveryEvidence,
      RecoveryEvidenceShadowClassification.negative,
    );
  });

  test('isolates a substantial load increase as a transition', () {
    final records = _records(weights: const [203, 203, 203, 203, 253]);
    final latest = service
        .build(target: records.last, records: records, now: now)
        .single
        .latestObservation!;
    expect(
      latest.loadContext,
      RecoveryEvidenceShadowLoadContext.loadTransitionUp,
    );
    expect(
      latest.performanceBand,
      RecoveryEvidenceShadowPerformanceBand.transition,
    );
    expect(
      latest.recoveryEvidence,
      RecoveryEvidenceShadowClassification.transition,
    );
  });

  test(
    'marks the direct session after a transition as non-negative after-effect',
    () {
      final records = _records(weights: const [203, 203, 203, 203, 253, 223]);
      final latest = service
          .build(target: records.last, records: records, now: now)
          .single
          .latestObservation!;
      expect(
        latest.loadContext,
        RecoveryEvidenceShadowLoadContext.transitionAfterEffect,
      );
      expect(
        latest.recoveryEvidence,
        RecoveryEvidenceShadowClassification.transition,
      );
    },
  );

  test('keeps a seven-day maintained 48-hour observation low information', () {
    final records = _records(days: const [0, 3, 6, 9, 16]);
    final latest = service
        .build(target: records.last, records: records, now: now)
        .single
        .latestObservation!;
    expect(latest.intervalZone, RecoveryEvidenceShadowIntervalZone.extended);
    expect(
      latest.recoveryEvidence,
      RecoveryEvidenceShadowClassification.lowInformation,
    );
  });

  test('excludes a thirteen-day maintained 48-hour observation', () {
    final records = _records(days: const [0, 3, 6, 9, 22]);
    final latest = service
        .build(target: records.last, records: records, now: now)
        .single
        .latestObservation!;
    expect(latest.intervalZone, RecoveryEvidenceShadowIntervalZone.excluded);
    expect(
      latest.recoveryEvidence,
      RecoveryEvidenceShadowClassification.excluded,
    );
  });

  test('does not combine equipment identities', () {
    final records = _records(
      weights: const [70, 70, 70, 70, 70],
      equipment: const [null, null, null, null, 'Rack'],
    );
    final result = service
        .build(target: records.last, records: records, now: now)
        .single;
    expect(result.observations, isEmpty);
  });

  test('derives validation milestones from forward informative evidence', () {
    final start = DateTime.utc(2025);
    final two = service.validationProgress(
      service
          .build(
            target: _records(weights: const [70, 70, 70, 70, 70, 70]).last,
            records: _records(weights: const [70, 70, 70, 70, 70, 70]),
            now: now,
          )
          .single,
      betaStart: start,
    );
    final threeRecords = _records(weights: const [70, 70, 70, 70, 70, 70, 70]);
    final three = service.validationProgress(
      service
          .build(target: threeRecords.last, records: threeRecords, now: now)
          .single,
      betaStart: start,
    );
    final fiveRecords = _records(
      weights: const [70, 70, 70, 70, 70, 70, 70, 70, 70],
    );
    final five = service.validationProgress(
      service
          .build(target: fiveRecords.last, records: fiveRecords, now: now)
          .single,
      betaStart: start,
    );
    expect(two.newBetaInformativeCount, 2);
    expect(two.milestone, RecoveryEvidenceShadowValidationMilestone.collecting);
    expect(three.newBetaInformativeCount, 3);
    expect(
      three.milestone,
      RecoveryEvidenceShadowValidationMilestone.firstReview,
    );
    expect(five.newBetaInformativeCount, 5);
    expect(
      five.milestone,
      RecoveryEvidenceShadowValidationMilestone.reviewReady,
    );
    expect(
      service.validationOverall([three, five]),
      RecoveryEvidenceShadowValidationOverall.firstReviewAvailable,
    );
  });

  test(
    'does not count extended, excluded, or transition evidence for validation',
    () {
      final start = DateTime.utc(2025);
      final extended = _records(days: const [0, 3, 6, 9, 16]);
      final excluded = _records(days: const [0, 3, 6, 9, 22]);
      final transition = _records(weights: const [203, 203, 203, 203, 253]);
      for (final records in [extended, excluded, transition]) {
        final progress = service.validationProgress(
          service
              .build(target: records.last, records: records, now: now)
              .single,
          betaStart: start,
        );
        expect(progress.newBetaInformativeCount, 0);
      }
    },
  );

  test('does not reuse validation counts for another parameter version', () {
    final records = _records(weights: const [70, 70, 70, 70, 70, 70]);
    final result = service
        .build(target: records.last, records: records, now: now)
        .single;
    final incompatible = RecoveryEvidenceShadowV2Result(
      parameterVersion: 'v2-beta-2',
      identity: result.identity,
      recoveryReferenceHours: result.recoveryReferenceHours,
      baseline: result.baseline,
      latestObservation: result.latestObservation,
      observations: result.observations,
      estimate: result.estimate,
      v1EligibleCount: result.v1EligibleCount,
      v1SupportedCount: result.v1SupportedCount,
      v1Status: result.v1Status,
    );
    final progress = service.validationProgress(
      incompatible,
      betaStart: DateTime.utc(2025),
    );
    expect(progress.isCompatible, isFalse);
    expect(progress.newBetaInformativeCount, 0);
  });

  test('tracks recurring exercise and equipment identities independently', () {
    final records = [
      ..._records(weights: const [70, 70, 70, 70, 70, 70], idPrefix: 'barbell'),
      ..._records(
        weights: const [70, 70, 70, 70, 70, 70],
        equipment: const ['Rack', 'Rack', 'Rack', 'Rack', 'Rack', 'Rack'],
        idPrefix: 'rack',
      ),
    ];
    final results = service.buildRecurring(records: records, now: now);
    final progress = [
      for (final result in results)
        service.validationProgress(result, betaStart: DateTime.utc(2025)),
    ];
    expect(results, hasLength(2));
    expect(progress.map((value) => value.identity.equipmentKey).toSet(), {
      'none',
      'name:rack',
    });
    expect(
      progress.every((value) => value.newBetaInformativeCount == 2),
      isTrue,
    );
  });
}

List<TrainingRecordReadModel> _records({
  List<double> weights = const [70, 70, 70, 70, 70],
  List<int>? reps,
  List<int>? days,
  List<String?>? equipment,
  String idPrefix = 'record',
}) => [
  for (var index = 0; index < weights.length; index++)
    _record(
      '$idPrefix:$index',
      DateTime.parse(
        '2026-01-01T09:00:00+09:00',
      ).add(Duration(days: days?[index] ?? index * 3)),
      weights[index],
      reps?[index] ?? 10,
      equipment?[index],
    ),
];

TrainingRecordReadModel _record(
  String id,
  DateTime start,
  double weight,
  int reps,
  String? equipment,
) => TrainingRecordReadModel.v2(
  id: id,
  localDate: start.toIso8601String().substring(0, 10),
  createdAt: start,
  updatedAt: start,
  data: TrainingSessionV2(
    date: start.toIso8601String(),
    startTime: start.toIso8601String(),
    endTime: start.add(const Duration(hours: 1)).toIso8601String(),
    exercises: [
      TrainingExerciseV2(
        exerciseName: 'Bench Press',
        order: 1,
        equipment: equipment == null
            ? null
            : TrainingEquipmentSnapshot(name: equipment),
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.main,
            weightKg: weight,
            reps: reps,
          ),
        ],
      ),
    ],
  ),
);
