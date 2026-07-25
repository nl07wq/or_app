import '../models/morning_fact.dart';

class MorningFactBuilder {
  MorningFactBuilder._();

  static MorningFact build({
    DateTime? date,
    double? weight,
    double? bodyFat,
    Duration? sleepDuration,
    int? sleepScore,
    int? footPain,
    int? condition,
    double? hydration,
    String? workSchedule,
    bool? previousCarryoverConfirmed,
    String? note,
  }) {
    return MorningFact(
      date: date,
      weight: weight,
      bodyFat: bodyFat,
      sleepDuration: sleepDuration,
      sleepScore: sleepScore,
      footPain: footPain,
      condition: condition,
      hydration: hydration,
      workSchedule: workSchedule,
      previousCarryoverConfirmed: previousCarryoverConfirmed,
      note: note,
    );
  }
}
