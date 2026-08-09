import 'work_type.dart';

enum SleepType {
  sleep('睡眠'),
  nap('仮眠');

  const SleepType(this.displayLabel);

  final String displayLabel;
}

class MorningData {
  final String date;

  // BODY
  final double weight;
  final double bodyFat;

  // RECOVERY
  final double sleepHours;
  final int? sleepScore;
  final SleepType sleepType;

  // FOOT HEALTH
  final int footPain;
  final int? condition;
  final bool? previousCarryoverConfirmed;

  // BOWEL
  /// Legacy-only Activity data. New Morning input leaves these values null.
  final int? bowelAmount;
  final int? bowelShape;

  // WORK
  final WorkType workType;

  // Fact
  final String workStart;
  final String workEnd;
  final String workBreak;

  // Derived
  final double workHours;

  // MEMO
  final String memo;

  const MorningData({
    required this.date,

    required this.weight,
    required this.bodyFat,

    required this.sleepHours,
    required this.sleepScore,
    this.sleepType = SleepType.sleep,

    required this.footPain,
    this.condition,
    this.previousCarryoverConfirmed,

    this.bowelAmount,
    this.bowelShape,

    required this.workType,

    required this.workStart,
    required this.workEnd,
    required this.workBreak,

    required this.workHours,

    required this.memo,
  });

  factory MorningData.fromJson(Map<String, dynamic> json) {
    final sleepTypeValue = json['sleepType'];
    final sleepType = sleepTypeValue == null
        ? SleepType.sleep
        : SleepType.values.firstWhere(
            (value) => value.name == sleepTypeValue,
            orElse: () => throw const FormatException('Invalid sleep type.'),
          );
    final sleepScore = json.containsKey('sleepScore')
        ? (json['sleepScore'] as num?)?.toInt()
        : 0;
    if (sleepType == SleepType.sleep && sleepScore == null) {
      throw const FormatException('Sleep score is required for sleep.');
    }
    if (sleepScore != null && (sleepScore < 0 || sleepScore > 100)) {
      throw const FormatException('Invalid sleep score.');
    }
    return MorningData(
      date: json['date'] as String,

      weight: (json['weight'] as num).toDouble(),
      bodyFat: (json['bodyFat'] ?? 0).toDouble(),

      sleepHours: (json['sleepHours'] as num).toDouble(),
      sleepScore: sleepScore,
      sleepType: sleepType,

      footPain: (json['footPain'] ?? 0) as int,
      condition: (json['condition'] as num?)?.toInt(),
      previousCarryoverConfirmed: json['previousCarryoverConfirmed'] as bool?,

      bowelAmount: (json['bowelAmount'] as num?)?.toInt(),
      bowelShape: (json['bowelShape'] as num?)?.toInt(),

      workType: WorkType.values.firstWhere(
        (e) => e.name == json['workType'],
        orElse: () => WorkType.work,
      ),
      workStart: json['workStart'] ?? "",
      workEnd: json['workEnd'] ?? "",
      workBreak: json['workBreak'] ?? "",

      workHours: (json['workHours'] ?? 0).toDouble(),

      memo: json['memo'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,

      'weight': weight,
      'bodyFat': bodyFat,

      'sleepHours': sleepHours,
      'sleepScore': sleepScore,
      'sleepType': sleepType.name,

      'footPain': footPain,
      if (condition != null) 'condition': condition,
      if (previousCarryoverConfirmed != null)
        'previousCarryoverConfirmed': previousCarryoverConfirmed,

      if (bowelAmount != null) 'bowelAmount': bowelAmount,
      if (bowelShape != null) 'bowelShape': bowelShape,

      'workType': workType.name,

      'workStart': workStart,
      'workEnd': workEnd,
      'workBreak': workBreak,

      'workHours': workHours,

      'memo': memo,
    };
  }

  Map<String, dynamic> toRecordJson() {
    return {'recordType': 'MorningData', 'version': '1.4', 'data': toJson()};
  }
}
