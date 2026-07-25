class MorningFact {
  final DateTime? date;
  final double? weight;
  final double? bodyFat;
  final Duration? sleepDuration;
  final int? sleepScore;
  final int? footPain;
  final int? condition;
  @Deprecated('Legacy read compatibility only. Use Activity bowel movement.')
  final String? bowel;
  final double? hydration;
  final String? workSchedule;
  final bool? previousCarryoverConfirmed;
  final String? note;

  const MorningFact({
    this.date,
    this.weight,
    this.bodyFat,
    this.sleepDuration,
    this.sleepScore,
    this.footPain,
    this.condition,
    this.bowel,
    this.hydration,
    this.workSchedule,
    this.previousCarryoverConfirmed,
    this.note,
  });
}
