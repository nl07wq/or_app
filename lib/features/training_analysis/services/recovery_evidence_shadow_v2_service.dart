import '../../training/models/training_record_read_model.dart';
import '../../training/services/training_exercise_identity.dart';
import '../../training/services/training_history_domain_service.dart';
import 'training_frequency_recommendation_service.dart';

/// Read-only beta analysis. V1 remains the only official recovery/frequency
/// rule; this service is deliberately invoked only by the diagnostic surface.
class RecoveryEvidenceShadowV2Service {
  const RecoveryEvidenceShadowV2Service({
    this.domain = const TrainingHistoryDomainService(),
    this.v1 = const TrainingFrequencyRecommendationService(),
  });

  static const parameterVersion = 'v2-beta-1';

  /// The v2-beta-1 activation commit.  Forward validation deliberately starts
  /// here rather than re-labelling historical observations as Beta evidence.
  static final betaStartedAt = DateTime.utc(2026, 9, 14, 2, 22, 17);
  static const baselineWindowSize = 5;
  static const baselineMinimumSessions = 3;
  static const loadTransitionRatio = .10;
  static const toleratedDeclineRatio = .90;
  static const informativeLowerRatio = .75;
  static const informativeUpperRatio = 2.0;
  static const extendedUpperRatio = 4.0;
  static const _longGap = Duration(days: 14);

  final TrainingHistoryDomainService domain;
  final TrainingFrequencyRecommendationService v1;

  /// Counts only forward, normal-context evidence which is already eligible
  /// for the shadow personal-estimate algorithm.  The result is derived from
  /// formal Training facts and the parameter version; no mutable counter is
  /// persisted.
  RecoveryEvidenceShadowValidationProgress validationProgress(
    RecoveryEvidenceShadowV2Result result, {
    DateTime? betaStart,
    String expectedParameterVersion = parameterVersion,
  }) {
    final start = betaStart ?? betaStartedAt;
    if (result.parameterVersion != expectedParameterVersion) {
      return RecoveryEvidenceShadowValidationProgress.incompatible(
        identity: result.identity,
        parameterVersion: result.parameterVersion,
        expectedParameterVersion: expectedParameterVersion,
        betaStartedAt: start,
      );
    }
    final qualifying = result.observations.where(
      (value) =>
          value.loadContext == RecoveryEvidenceShadowLoadContext.normal &&
          value.intervalZone ==
              RecoveryEvidenceShadowIntervalZone.informative &&
          value.recoveryEvidence ==
              RecoveryEvidenceShadowClassification.supported,
    );
    final historical = qualifying
        .where((value) => value.currentStartTime.isBefore(start))
        .length;
    final forward = qualifying
        .where((value) => !value.currentStartTime.isBefore(start))
        .length;
    return RecoveryEvidenceShadowValidationProgress(
      identity: result.identity,
      parameterVersion: result.parameterVersion,
      expectedParameterVersion: expectedParameterVersion,
      betaStartedAt: start,
      historicalInformativeCount: historical,
      newBetaInformativeCount: forward,
    );
  }

  RecoveryEvidenceShadowValidationOverall validationOverall(
    Iterable<RecoveryEvidenceShadowValidationProgress> values,
  ) {
    final compatible = values.where((value) => value.isCompatible).toList();
    if (compatible.isEmpty ||
        compatible.any((value) => value.newBetaInformativeCount < 3)) {
      return RecoveryEvidenceShadowValidationOverall.collecting;
    }
    if (compatible.any((value) => value.newBetaInformativeCount < 5)) {
      return RecoveryEvidenceShadowValidationOverall.firstReviewAvailable;
    }
    return RecoveryEvidenceShadowValidationOverall.reviewReady;
  }

  /// Returns the latest result for each recurring exact identity.  This keeps
  /// the diagnostic dynamic as the current program changes without using
  /// display-name allowlists.
  List<RecoveryEvidenceShadowV2Result> buildRecurring({
    required Iterable<TrainingRecordReadModel> records,
    required DateTime now,
  }) {
    final values = records.toList(growable: false);
    final recordsById = {for (final value in values) value.id: value};
    final points = domain.exerciseHistory(values);
    final latestByIdentity = <TrainingExerciseIdentity, ExerciseHistoryPoint>{};
    final countByIdentity = <TrainingExerciseIdentity, int>{};
    for (final point in points) {
      countByIdentity[point.identity] =
          (countByIdentity[point.identity] ?? 0) + 1;
      final existing = latestByIdentity[point.identity];
      final candidate = recordsById[point.recordId];
      final previous = existing == null ? null : recordsById[existing.recordId];
      if (candidate != null &&
          (previous == null ||
              candidate.sortDateTime.isAfter(previous.sortDateTime))) {
        latestByIdentity[point.identity] = point;
      }
    }
    final results = <RecoveryEvidenceShadowV2Result>[];
    for (final entry in latestByIdentity.entries) {
      if ((countByIdentity[entry.key] ?? 0) < 2) continue;
      final target = recordsById[entry.value.recordId];
      if (target == null) continue;
      final candidates = build(
        target: target,
        records: values,
        now: now,
      ).where((value) => value.identity == entry.key);
      if (candidates.isNotEmpty) results.add(candidates.first);
    }
    results.sort(
      (a, b) => a.identity.exerciseKey.compareTo(b.identity.exerciseKey),
    );
    return results;
  }

  List<RecoveryEvidenceShadowV2Result> build({
    required TrainingRecordReadModel target,
    required Iterable<TrainingRecordReadModel> records,
    required DateTime now,
  }) {
    final values = records.toList(growable: false);
    final byId = {for (final value in values) value.id: value};
    final v1Results = {
      for (final value in v1.build(target: target, records: values, now: now))
        value.targetIdentity: value,
    };
    final points = domain.exerciseHistory(values);
    final targetIdentities = points
        .where((point) => point.recordId == target.id)
        .map((point) => point.identity)
        .toSet();
    return [
      for (final identity in targetIdentities)
        _buildIdentity(
          identity: identity,
          target: target,
          points: points,
          recordsById: byId,
          v1Result: v1Results[identity],
          now: now,
        ),
    ];
  }

  RecoveryEvidenceShadowV2Result _buildIdentity({
    required TrainingExerciseIdentity identity,
    required TrainingRecordReadModel target,
    required List<ExerciseHistoryPoint> points,
    required Map<String, TrainingRecordReadModel> recordsById,
    required TrainingFrequencyRecommendation? v1Result,
    required DateTime now,
  }) {
    final referenceHours = v1Result?.recoveryReferenceHours;
    final occurrences = [
      for (final point in points)
        if (point.identity == identity &&
            (point.recordId == target.id ||
                (recordsById[point.recordId]?.sortDateTime.isBefore(
                      target.sortDateTime,
                    ) ??
                    false)))
          _ShadowOccurrence(point, recordsById[point.recordId]!),
    ]..sort((a, b) => a.record.sortDateTime.compareTo(b.record.sortDateTime));

    final sessions = <_ShadowSession>[];
    for (final occurrence in occurrences) {
      final start = _exactStart(occurrence.record);
      final end = _exactEnd(occurrence.record);
      if (start == null ||
          end == null ||
          start.isAfter(now) ||
          end.isAfter(now)) {
        continue;
      }
      sessions.add(_ShadowSession.fromOccurrence(occurrence, start, end));
    }
    final observations = <RecoveryEvidenceShadowObservation>[];
    final contexts = <_SessionContext>[];
    for (var index = 1; index < sessions.length; index++) {
      final previous = sessions[index - 1];
      final current = sessions[index];
      if (!current.start.isAfter(previous.end)) continue;
      final baseline = _baseline(contexts);
      final context = _contextFor(
        current,
        baseline,
        contexts.isEmpty ? null : contexts.last,
      );
      final intervalHours =
          current.start.difference(previous.end).inMinutes / 60.0;
      final zone = _zone(intervalHours, referenceHours);
      final band = _bandFor(current, baseline, context, zone);
      final evidence = _evidenceFor(band, zone);
      observations.add(
        RecoveryEvidenceShadowObservation(
          previousRecordId: previous.record.id,
          currentRecordId: current.record.id,
          previousEndTime: previous.end,
          currentStartTime: current.start,
          intervalHours: intervalHours,
          baseline: baseline,
          loadContext: context,
          performanceBand: band,
          intervalZone: zone,
          recoveryEvidence: evidence,
          current: current.metrics,
        ),
      );
      contexts.add(_SessionContext(current, context, band));
    }
    final latest = observations.isEmpty ? null : observations.last;
    final estimate = _estimate(observations, referenceHours);
    return RecoveryEvidenceShadowV2Result(
      parameterVersion: parameterVersion,
      identity: identity,
      recoveryReferenceHours: referenceHours,
      baseline: latest?.baseline ?? _baseline(contexts),
      latestObservation: latest,
      observations: observations,
      estimate: estimate,
      v1EligibleCount: v1Result?.validObservationCount ?? 0,
      v1SupportedCount: v1Result?.supportedObservationCount ?? 0,
      v1Status: v1Result?.status,
    );
  }

  RecoveryEvidenceShadowBaseline? _baseline(List<_SessionContext> contexts) {
    final normal = contexts
        .where(
          (value) =>
              value.loadContext == RecoveryEvidenceShadowLoadContext.normal &&
              value.session.metrics.isComparable,
        )
        .toList();
    if (normal.length < baselineMinimumSessions) return null;
    final recent = normal.length <= baselineWindowSize
        ? normal
        : normal.sublist(normal.length - baselineWindowSize);
    final setCount = _mode(
      recent.map((value) => value.session.metrics.setCount),
    );
    final comparable = recent
        .where((value) => value.session.metrics.setCount == setCount)
        .toList();
    if (comparable.length < baselineMinimumSessions) return null;
    return RecoveryEvidenceShadowBaseline(
      maxWeight: _median(
        comparable.map((value) => value.session.metrics.maxWeight!),
      ),
      totalReps: _median(
        comparable.map((value) => value.session.metrics.totalReps!.toDouble()),
      ),
      volume: _median(comparable.map((value) => value.session.metrics.volume!)),
      setCount: setCount,
      sampleCount: comparable.length,
      promotedLoadRegime: _hasPromotedRegime(recent, setCount),
    );
  }

  bool _hasPromotedRegime(List<_SessionContext> recent, int setCount) {
    final candidates = recent
        .where((value) => value.session.metrics.setCount == setCount)
        .toList();
    if (candidates.length < 4) return false;
    final lastFour = candidates.sublist(candidates.length - 4);
    final median = _median(
      lastFour.map((value) => value.session.metrics.maxWeight!),
    );
    return lastFour
            .where(
              (value) =>
                  (value.session.metrics.maxWeight! - median).abs() / median <
                  loadTransitionRatio,
            )
            .length >=
        3;
  }

  RecoveryEvidenceShadowLoadContext _contextFor(
    _ShadowSession current,
    RecoveryEvidenceShadowBaseline? baseline,
    _SessionContext? previous,
  ) {
    if (previous != null &&
        (previous.loadContext ==
                RecoveryEvidenceShadowLoadContext.loadTransitionUp ||
            previous.loadContext ==
                RecoveryEvidenceShadowLoadContext.loadTransitionDown)) {
      return RecoveryEvidenceShadowLoadContext.transitionAfterEffect;
    }
    if (baseline == null || !current.metrics.isComparable) {
      return RecoveryEvidenceShadowLoadContext.normal;
    }
    final change =
        (current.metrics.maxWeight! - baseline.maxWeight) / baseline.maxWeight;
    if (change >= loadTransitionRatio) {
      return RecoveryEvidenceShadowLoadContext.loadTransitionUp;
    }
    if (change <= -loadTransitionRatio) {
      return RecoveryEvidenceShadowLoadContext.loadTransitionDown;
    }
    return RecoveryEvidenceShadowLoadContext.normal;
  }

  RecoveryEvidenceShadowPerformanceBand _bandFor(
    _ShadowSession current,
    RecoveryEvidenceShadowBaseline? baseline,
    RecoveryEvidenceShadowLoadContext context,
    RecoveryEvidenceShadowIntervalZone zone,
  ) {
    if (zone == RecoveryEvidenceShadowIntervalZone.excluded) {
      return RecoveryEvidenceShadowPerformanceBand.excluded;
    }
    if (context != RecoveryEvidenceShadowLoadContext.normal) {
      return RecoveryEvidenceShadowPerformanceBand.transition;
    }
    if (baseline == null ||
        !current.metrics.isComparable ||
        current.metrics.setCount != baseline.setCount) {
      return RecoveryEvidenceShadowPerformanceBand.lowInformation;
    }
    final repsRatio = current.metrics.totalReps! / baseline.totalReps;
    final volumeRatio = current.metrics.volume! / baseline.volume;
    final weightRatio = current.metrics.maxWeight! / baseline.maxWeight;
    if (weightRatio >= 1 && repsRatio >= 1 && volumeRatio >= 1) {
      return RecoveryEvidenceShadowPerformanceBand.maintainedOrImproved;
    }
    final workRatio = repsRatio < volumeRatio ? repsRatio : volumeRatio;
    return workRatio >= toleratedDeclineRatio
        ? RecoveryEvidenceShadowPerformanceBand.toleratedDecline
        : RecoveryEvidenceShadowPerformanceBand.clearDecline;
  }

  RecoveryEvidenceShadowIntervalZone _zone(double hours, int? referenceHours) {
    if (referenceHours == null ||
        hours > _longGap.inHours ||
        hours > referenceHours * extendedUpperRatio) {
      return RecoveryEvidenceShadowIntervalZone.excluded;
    }
    if (hours > referenceHours * informativeUpperRatio) {
      return RecoveryEvidenceShadowIntervalZone.extended;
    }
    if (hours >= referenceHours * informativeLowerRatio) {
      return RecoveryEvidenceShadowIntervalZone.informative;
    }
    return RecoveryEvidenceShadowIntervalZone.belowBasis;
  }

  RecoveryEvidenceShadowClassification _evidenceFor(
    RecoveryEvidenceShadowPerformanceBand band,
    RecoveryEvidenceShadowIntervalZone zone,
  ) {
    if (band == RecoveryEvidenceShadowPerformanceBand.excluded ||
        zone == RecoveryEvidenceShadowIntervalZone.excluded) {
      return RecoveryEvidenceShadowClassification.excluded;
    }
    if (band == RecoveryEvidenceShadowPerformanceBand.transition) {
      return RecoveryEvidenceShadowClassification.transition;
    }
    if (band == RecoveryEvidenceShadowPerformanceBand.lowInformation ||
        zone != RecoveryEvidenceShadowIntervalZone.informative) {
      return RecoveryEvidenceShadowClassification.lowInformation;
    }
    return band == RecoveryEvidenceShadowPerformanceBand.clearDecline
        ? RecoveryEvidenceShadowClassification.negative
        : RecoveryEvidenceShadowClassification.supported;
  }

  RecoveryEvidenceShadowEstimate _estimate(
    List<RecoveryEvidenceShadowObservation> observations,
    int? referenceHours,
  ) {
    final positive = observations
        .where(
          (value) =>
              value.recoveryEvidence ==
              RecoveryEvidenceShadowClassification.supported,
        )
        .toList();
    final negatives = observations
        .where(
          (value) =>
              value.recoveryEvidence ==
              RecoveryEvidenceShadowClassification.negative,
        )
        .toList();
    if (referenceHours == null ||
        positive.length < 2 ||
        negatives.any(
          (value) =>
              value.intervalHours >=
              positive
                  .map((value) => value.intervalHours)
                  .reduce((a, b) => a < b ? a : b),
        )) {
      return const RecoveryEvidenceShadowEstimate.insufficient();
    }
    final hours = positive.map((value) => value.intervalHours).toList()..sort();
    return RecoveryEvidenceShadowEstimate.available(
      lowerHours: hours.first,
      upperHours: hours.last,
      evidenceCount: positive.length,
    );
  }

  DateTime? _exactStart(TrainingRecordReadModel record) =>
      record.v2Data?.startTime == null
      ? null
      : DateTime.tryParse(record.v2Data!.startTime!);
  DateTime? _exactEnd(TrainingRecordReadModel record) =>
      record.v2Data?.endTime == null
      ? null
      : DateTime.tryParse(record.v2Data!.endTime!);
}

enum RecoveryEvidenceShadowLoadContext {
  normal,
  loadTransitionUp,
  loadTransitionDown,
  transitionAfterEffect,
}

enum RecoveryEvidenceShadowPerformanceBand {
  maintainedOrImproved,
  toleratedDecline,
  clearDecline,
  transition,
  lowInformation,
  excluded,
}

enum RecoveryEvidenceShadowIntervalZone {
  belowBasis,
  informative,
  extended,
  excluded,
}

enum RecoveryEvidenceShadowClassification {
  supported,
  negative,
  transition,
  lowInformation,
  excluded,
}

class RecoveryEvidenceShadowMetricSnapshot {
  const RecoveryEvidenceShadowMetricSnapshot(
    this.maxWeight,
    this.totalReps,
    this.setCount,
    this.volume,
  );
  factory RecoveryEvidenceShadowMetricSnapshot.fromPoint(
    ExerciseHistoryPoint point,
  ) {
    final metric = TrainingFrequencyMetricSnapshot.fromPoint(point);
    return RecoveryEvidenceShadowMetricSnapshot(
      metric.maxWeight,
      metric.totalReps,
      metric.recordedSetCount,
      metric.recordedVolume,
    );
  }
  final double? maxWeight;
  final int? totalReps;
  final int? setCount;
  final double? volume;
  bool get isComparable =>
      maxWeight != null &&
      totalReps != null &&
      setCount != null &&
      volume != null;
}

class RecoveryEvidenceShadowBaseline {
  const RecoveryEvidenceShadowBaseline({
    required this.maxWeight,
    required this.totalReps,
    required this.volume,
    required this.setCount,
    required this.sampleCount,
    required this.promotedLoadRegime,
  });
  final double maxWeight;
  final double totalReps;
  final double volume;
  final int setCount;
  final int sampleCount;
  final bool promotedLoadRegime;
}

class RecoveryEvidenceShadowObservation {
  const RecoveryEvidenceShadowObservation({
    required this.previousRecordId,
    required this.currentRecordId,
    required this.previousEndTime,
    required this.currentStartTime,
    required this.intervalHours,
    required this.baseline,
    required this.loadContext,
    required this.performanceBand,
    required this.intervalZone,
    required this.recoveryEvidence,
    required this.current,
  });
  final String previousRecordId;
  final String currentRecordId;
  final DateTime previousEndTime;
  final DateTime currentStartTime;
  final double intervalHours;
  final RecoveryEvidenceShadowBaseline? baseline;
  final RecoveryEvidenceShadowLoadContext loadContext;
  final RecoveryEvidenceShadowPerformanceBand performanceBand;
  final RecoveryEvidenceShadowIntervalZone intervalZone;
  final RecoveryEvidenceShadowClassification recoveryEvidence;
  final RecoveryEvidenceShadowMetricSnapshot current;
}

class RecoveryEvidenceShadowEstimate {
  const RecoveryEvidenceShadowEstimate.insufficient()
    : available = false,
      lowerHours = null,
      upperHours = null,
      evidenceCount = 0;
  const RecoveryEvidenceShadowEstimate.available({
    required this.lowerHours,
    required this.upperHours,
    required this.evidenceCount,
  }) : available = true;
  final bool available;
  final double? lowerHours;
  final double? upperHours;
  final int evidenceCount;
}

class RecoveryEvidenceShadowV2Result {
  const RecoveryEvidenceShadowV2Result({
    required this.parameterVersion,
    required this.identity,
    required this.recoveryReferenceHours,
    required this.baseline,
    required this.latestObservation,
    required this.observations,
    required this.estimate,
    required this.v1EligibleCount,
    required this.v1SupportedCount,
    required this.v1Status,
  });
  final String parameterVersion;
  final TrainingExerciseIdentity identity;
  final int? recoveryReferenceHours;
  final RecoveryEvidenceShadowBaseline? baseline;
  final RecoveryEvidenceShadowObservation? latestObservation;
  final List<RecoveryEvidenceShadowObservation> observations;
  final RecoveryEvidenceShadowEstimate estimate;
  final int v1EligibleCount;
  final int v1SupportedCount;
  final TrainingFrequencyRecommendationStatus? v1Status;
}

enum RecoveryEvidenceShadowValidationMilestone {
  collecting,
  firstReview,
  reviewReady,
}

enum RecoveryEvidenceShadowValidationOverall {
  collecting,
  firstReviewAvailable,
  reviewReady,
}

class RecoveryEvidenceShadowValidationProgress {
  const RecoveryEvidenceShadowValidationProgress({
    required this.identity,
    required this.parameterVersion,
    required this.expectedParameterVersion,
    required this.betaStartedAt,
    required this.historicalInformativeCount,
    required this.newBetaInformativeCount,
  }) : isCompatible = true;

  const RecoveryEvidenceShadowValidationProgress.incompatible({
    required this.identity,
    required this.parameterVersion,
    required this.expectedParameterVersion,
    required this.betaStartedAt,
  }) : isCompatible = false,
       historicalInformativeCount = 0,
       newBetaInformativeCount = 0;

  final TrainingExerciseIdentity identity;
  final String parameterVersion;
  final String expectedParameterVersion;
  final DateTime betaStartedAt;
  final int historicalInformativeCount;
  final int newBetaInformativeCount;
  final bool isCompatible;

  RecoveryEvidenceShadowValidationMilestone get milestone =>
      newBetaInformativeCount >= 5
      ? RecoveryEvidenceShadowValidationMilestone.reviewReady
      : newBetaInformativeCount >= 3
      ? RecoveryEvidenceShadowValidationMilestone.firstReview
      : RecoveryEvidenceShadowValidationMilestone.collecting;
}

class _ShadowOccurrence {
  const _ShadowOccurrence(this.point, this.record);
  final ExerciseHistoryPoint point;
  final TrainingRecordReadModel record;
}

class _ShadowSession {
  const _ShadowSession(this.record, this.start, this.end, this.metrics);
  factory _ShadowSession.fromOccurrence(
    _ShadowOccurrence value,
    DateTime start,
    DateTime end,
  ) => _ShadowSession(
    value.record,
    start,
    end,
    RecoveryEvidenceShadowMetricSnapshot.fromPoint(value.point),
  );
  final TrainingRecordReadModel record;
  final DateTime start;
  final DateTime end;
  final RecoveryEvidenceShadowMetricSnapshot metrics;
}

class _SessionContext {
  const _SessionContext(this.session, this.loadContext, this.band);
  final _ShadowSession session;
  final RecoveryEvidenceShadowLoadContext loadContext;
  final RecoveryEvidenceShadowPerformanceBand band;
}

double _median(Iterable<double> source) {
  final values = source.toList()..sort();
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle]
      : (values[middle - 1] + values[middle]) / 2;
}

int _mode(Iterable<int?> source) {
  final counts = <int, int>{};
  for (final value in source) {
    if (value != null) counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts.entries
      .reduce(
        (a, b) =>
            a.value > b.value || (a.value == b.value && a.key < b.key) ? a : b,
      )
      .key;
}
