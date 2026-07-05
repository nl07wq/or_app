import 'work_type.dart';

class MorningData {
  final String date;

  // BODY
  final double weight;
  final double bodyFat;

  // RECOVERY
  final double sleepHours;
  final int sleepScore;

  // FOOT HEALTH
  final int footPain;

  // BOWEL
  final int bowelAmount;
  final int bowelShape;

  // WORK
  final WorkType workType;
  final double workHours;

  // MEMO
  final String memo;

  const MorningData({
    required this.date,

    required this.weight,
    required this.bodyFat,

    required this.sleepHours,
    required this.sleepScore,

    required this.footPain,

    required this.bowelAmount,
    required this.bowelShape,

    required this.workType,
    required this.workHours,

    required this.memo,
  });

  factory MorningData.fromJson(Map<String, dynamic> json) {
    return MorningData(
      date: json['date'] as String,

      weight: (json['weight'] as num).toDouble(),
      bodyFat: (json['bodyFat'] ?? 0).toDouble(),

      sleepHours: (json['sleepHours'] as num).toDouble(),
      sleepScore: (json['sleepScore'] ?? 0) as int,

      footPain: (json['footPain'] ?? 0) as int,

      bowelAmount: (json['bowelAmount'] ?? 0) as int,
      bowelShape: (json['bowelShape'] ?? 0) as int,

      workType: WorkType.values.firstWhere(
        (e) => e.name == json['workType'],
        orElse: () => WorkType.work,
      ),
      workHours: (json['workHours'] as num).toDouble(),

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

      'footPain': footPain,

      'bowelAmount': bowelAmount,
      'bowelShape': bowelShape,

      'workType': workType.name,
      'workHours': workHours,

      'memo': memo,
    };
  }

  Map<String, dynamic> toRecordJson() {
    return {'recordType': 'MorningData', 'version': '1.3', 'data': toJson()};
  }
}
