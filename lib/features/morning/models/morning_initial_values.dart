import '../../../core/models/work_type.dart';

class MorningInitialValues {
  final String weight;
  final String bodyFat;
  final String sleep;
  final String sleepScore;
  final bool hasPreviousRecord;
  final WorkType? workType;
  final String? workStart;
  final String? workEnd;
  final String? workBreak;

  const MorningInitialValues({
    required this.weight,
    required this.bodyFat,
    required this.sleep,
    required this.sleepScore,
    this.hasPreviousRecord = false,
    this.workType,
    this.workStart,
    this.workEnd,
    this.workBreak,
  });

  const MorningInitialValues.empty()
    : weight = '',
      bodyFat = '',
      sleep = '',
      sleepScore = '',
      hasPreviousRecord = false,
      workType = null,
      workStart = null,
      workEnd = null,
      workBreak = null;
}
