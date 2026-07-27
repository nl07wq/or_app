import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/digestive_summary.dart';
import '../../../core/models/activity_data.dart';
import '../../../core/models/morning_data.dart';
import 'bowel_movement_resolver.dart';

class ActivitySummaryEngine {
  final BowelMovementResolver _bowelResolver;

  const ActivitySummaryEngine([
    this._bowelResolver = const BowelMovementResolver(),
  ]);

  ActivitySummary generate({
    required ActivityData? record,
    int previousCarryOver = 0,
    MorningData? legacyMorning,
    String? legacyMorningBowel,
  }) {
    if (record == null) return const ActivitySummary.empty();

    final warnings = <ActivitySummaryWarning>[];
    final unconfirmed = <String>[];

    void warn(String field, ActivitySummaryWarningCode code) {
      unconfirmed.add(field);
      warnings.add(ActivitySummaryWarning(code));
    }

    if (!record.stepsEntered) {
      warn('rawSteps', ActivitySummaryWarningCode.stepsUnconfirmed);
    }
    if (!record.carryOverEntered) {
      warn('carryOver', ActivitySummaryWarningCode.carryOverUnconfirmed);
    }
    if (record.plannedWork == null || record.actualWork == null) {
      if (record.plannedWork == null) {
        unconfirmed.add('plannedWork');
      }
      if (record.actualWork == null) {
        unconfirmed.add('actualWork');
      }
      warnings.add(
        const ActivitySummaryWarning(
          ActivitySummaryWarningCode.workUnconfirmed,
        ),
      );
    }
    if (record.trainingStatus == ActivityTrainingStatus.unconfirmed) {
      warn('trainingStatus', ActivitySummaryWarningCode.trainingUnconfirmed);
    }

    final hasDigestiveEventsContract = record.digestiveEvents != null;
    final bowelMovement = hasDigestiveEventsContract
        ? record.bowelMovement
        : _bowelResolver.resolve(
            activity: record,
            legacyMorning: legacyMorning,
            legacyMorningBowel: legacyMorningBowel,
          );
    if (!hasDigestiveEventsContract && !bowelMovement.isConfirmed) {
      warn('bowelMovement', ActivitySummaryWarningCode.bowelUnconfirmed);
    }

    int? officialSteps;
    if (record.stepsEntered && record.carryOverEntered) {
      final calculated =
          record.measuredSteps + record.carryOver - previousCarryOver;
      if (calculated < 0) {
        warnings.add(
          const ActivitySummaryWarning(
            ActivitySummaryWarningCode.officialStepsInvalid,
          ),
        );
      } else {
        officialSteps = calculated;
      }
    }

    final hasValidSteps = officialSteps != null;
    return ActivitySummary(
      steps: officialSteps ?? 0,
      measuredSteps: hasValidSteps ? record.measuredSteps : 0,
      carryOver: hasValidSteps ? record.carryOver : 0,
      previousCarryOverDeduction: hasValidSteps ? previousCarryOver : 0,
      isRecorded: true,
      recordId: record.id,
      date: record.date,
      plannedWork: record.plannedWork,
      actualWork: record.actualWork,
      trainingStatus: record.trainingStatus,
      bowelMovement: bowelMovement,
      digestiveSummary: hasDigestiveEventsContract
          ? DigestiveSummary.fromEvents(record.digestiveEvents!)
          : null,
      status: warnings.isEmpty
          ? ActivitySummaryStatus.confirmed
          : ActivitySummaryStatus.incomplete,
      unconfirmedFields: List.unmodifiable(unconfirmed),
      warnings: List.unmodifiable(warnings),
      calculationBasis: ActivityCalculationBasis(
        rawSteps: record.rawSteps,
        currentCarryOver: record.carryoverSteps,
        previousCarryOverDeduction: previousCarryOver,
        officialSteps: officialSteps,
      ),
    );
  }
}
