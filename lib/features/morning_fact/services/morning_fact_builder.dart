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
    String? bowel,
    double? hydration,
    String? workSchedule,
  }) {
    return MorningFact(
      date: date,
      weight: weight,
      bodyFat: bodyFat,
      sleepDuration: sleepDuration,
      sleepScore: sleepScore,
      footPain: footPain,
      condition: condition,
      bowel: bowel,
      hydration: hydration,
      workSchedule: workSchedule,
    );
  }
}
