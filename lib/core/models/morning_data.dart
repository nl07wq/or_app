class MorningData {
  final String date;
  final double weight;
  final double sleepHours;
  final String workMemo;

  const MorningData({
  required this.date,
  required this.weight,
  required this.sleepHours,
  required this.workMemo,
});

  @override
  String toString() {
    return 'MorningData(weight: $weight, sleepHours: $sleepHours, workMemo: $workMemo)';
  }
  Map<String, dynamic> toJson() {
    
  return {
  'date': date,
  'weight': weight,
  'sleepHours': sleepHours,
  'workMemo': workMemo,
};
}
Map<String, dynamic> toRecordJson() {
  return {
    'recordType': 'MorningData',
    'version': '1.0',
    'data': toJson(),
  };
}
}