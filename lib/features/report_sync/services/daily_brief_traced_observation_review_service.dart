import '../models/morning_brief_record.dart';

enum DailyBriefTracedObservationReviewState { collecting, reviewReady }

class DailyBriefTracedObservationReviewSummary {
  const DailyBriefTracedObservationReviewSummary({
    required this.observationCount,
    required this.greenCount,
    required this.yellowCount,
    required this.redCount,
    required this.state,
  });

  final int observationCount;
  final int greenCount;
  final int yellowCount;
  final int redCount;
  final DailyBriefTracedObservationReviewState state;

  int get displayedObservationCount => observationCount.clamp(0, 10);
}

/// Derives the calibration gate from canonical persisted DAILY BRIEF records.
/// No counter is persisted, so reloads and replacements cannot double-count.
class DailyBriefTracedObservationReviewService {
  const DailyBriefTracedObservationReviewService();

  static const targetObservationCount = 10;

  DailyBriefTracedObservationReviewSummary summarize(
    Iterable<MorningBriefRecord> records,
  ) {
    final canonical = <String, MorningBriefRecord>{};
    for (final record in records) {
      final trace = record.decisionTrace;
      if (trace == null ||
          trace.traceSchemaVersion != 'decision-trace-v1' ||
          trace.finalDecision.operationStatus !=
              record.operationStatus.stableId ||
          record.sourceType != 'status') {
        continue;
      }
      final existing = canonical[record.localDate];
      if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
        canonical[record.localDate] = record;
      }
    }
    var green = 0;
    var yellow = 0;
    var red = 0;
    for (final record in canonical.values) {
      switch (record.operationStatus) {
        case MorningBriefOperationStatus.green:
          green++;
        case MorningBriefOperationStatus.yellow:
          yellow++;
        case MorningBriefOperationStatus.red:
          red++;
      }
    }
    final count = canonical.length;
    return DailyBriefTracedObservationReviewSummary(
      observationCount: count,
      greenCount: green,
      yellowCount: yellow,
      redCount: red,
      state: count >= targetObservationCount
          ? DailyBriefTracedObservationReviewState.reviewReady
          : DailyBriefTracedObservationReviewState.collecting,
    );
  }
}
