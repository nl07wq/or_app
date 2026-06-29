class TrainingData {
  final String date;
  final String exercise;
  final int sets;
  final int reps;
  final double weight;
  final String memo;

  const TrainingData({
    required this.date,
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.memo,
  });

  @override
  String toString() {
    return 'TrainingData(date: $date, exercise: $exercise)';
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'exercise': exercise,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'memo': memo,
    };
  }

  Map<String, dynamic> toRecordJson() {
    return {'recordType': 'TrainingData', 'version': '1.0', 'data': toJson()};
  }
}
