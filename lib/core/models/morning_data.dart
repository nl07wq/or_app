class MorningData {
  final String date;
  final double weight;
  final double sleepHours;
  final double workHours;
  final String memo;

  const MorningData({
    required this.date,
    required this.weight,
    required this.sleepHours,
    required this.workHours,
    required this.memo,
  });

  factory MorningData.fromJson(Map<String, dynamic> json) {
    return MorningData(
      date: json['date'] as String,
      weight: (json['weight'] as num).toDouble(),
      sleepHours: (json['sleepHours'] as num).toDouble(),
      workHours: (json['workHours'] as num).toDouble(),
      memo: json['memo'] as String,
    );
  }

  @override
  String toString() {
    return '''
MorningData(
  date: $date,
  weight: $weight,
  sleepHours: $sleepHours,
  workHours: $workHours,
  memo: $memo
)
''';
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'weight': weight,
      'sleepHours': sleepHours,
      'workHours': workHours,
      'memo': memo,
    };
  }

  Map<String, dynamic> toRecordJson() {
    return {'recordType': 'MorningData', 'version': '1.1', 'data': toJson()};
  }
}
