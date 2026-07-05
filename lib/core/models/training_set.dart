class TrainingSet {
  final int setNo;

  final double weight;

  final int reps;

  const TrainingSet({
    required this.setNo,
    required this.weight,
    required this.reps,
  });

  Map<String, dynamic> toJson() {
    return {'setNo': setNo, 'weight': weight, 'reps': reps};
  }

  factory TrainingSet.fromJson(Map<String, dynamic> json) {
    return TrainingSet(
      setNo: json['setNo'] as int,
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'] as int,
    );
  }
}
