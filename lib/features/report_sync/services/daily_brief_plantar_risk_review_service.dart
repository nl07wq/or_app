import '../models/morning_brief_record.dart';

enum DailyBriefPlantarRiskReviewState {
  collecting,
  reviewBuilding,
  reviewReady,
}

class DailyBriefPlantarRiskReviewSummary {
  const DailyBriefPlantarRiskReviewSummary({
    required this.evaluationVersion,
    required this.observationCount,
    required this.greenCount,
    required this.yellowCount,
    required this.redCount,
    required this.state,
  });

  final String evaluationVersion;
  final int observationCount;
  final int greenCount;
  final int yellowCount;
  final int redCount;
  final DailyBriefPlantarRiskReviewState state;

  bool get isReviewReady => state == DailyBriefPlantarRiskReviewState.reviewReady;
}

/// Reconstructs the review milestone from the active, version-provenanced
/// DAILY BRIEF records. It intentionally does not infer a version for records
/// created before the calibration provenance was introduced.
class DailyBriefPlantarRiskReviewService {
  const DailyBriefPlantarRiskReviewService();

  static const evaluationVersion = 'plantar-risk-v2';
  static const commitProvenance = 'b41bf49';
  static const targetObservationCount = 10;

  DailyBriefPlantarRiskReviewSummary summarize(
    Iterable<MorningBriefRecord> records, {
    String version = evaluationVersion,
  }) {
    final byOperationDate = <String, MorningBriefRecord>{};
    for (final record in records) {
      if (record.evaluationVersion != version) continue;
      final existing = byOperationDate[record.localDate];
      if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
        byOperationDate[record.localDate] = record;
      }
    }
    var green = 0;
    var yellow = 0;
    var red = 0;
    for (final record in byOperationDate.values) {
      switch (record.operationStatus) {
        case MorningBriefOperationStatus.green:
          green++;
        case MorningBriefOperationStatus.yellow:
          yellow++;
        case MorningBriefOperationStatus.red:
          red++;
      }
    }
    final count = byOperationDate.length;
    return DailyBriefPlantarRiskReviewSummary(
      evaluationVersion: version,
      observationCount: count,
      greenCount: green,
      yellowCount: yellow,
      redCount: red,
      state: count >= targetObservationCount
          ? DailyBriefPlantarRiskReviewState.reviewReady
          : count >= 5
          ? DailyBriefPlantarRiskReviewState.reviewBuilding
          : DailyBriefPlantarRiskReviewState.collecting,
    );
  }
}
