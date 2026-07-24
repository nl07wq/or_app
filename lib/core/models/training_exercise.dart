import 'training_set.dart';

class TrainingExercise {
  final String exerciseName;

  final int order;

  final List<TrainingSet> sets;
  final String? equipmentId;

  const TrainingExercise({
    required this.exerciseName,
    required this.order,
    required this.sets,
    this.equipmentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'exerciseName': exerciseName,
      'order': order,
      'sets': sets.map((e) => e.toJson()).toList(),
      if (equipmentId != null) 'equipmentId': equipmentId,
    };
  }

  factory TrainingExercise.fromJson(Map<String, dynamic> json) {
    return TrainingExercise(
      exerciseName: json['exerciseName'] as String,
      order: json['order'] as int,
      equipmentId: json['equipmentId'] as String?,
      sets: (json['sets'] as List)
          .map((e) => TrainingSet.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
