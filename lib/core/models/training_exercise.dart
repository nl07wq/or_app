import 'training_set.dart';

class TrainingExercise {
  final String exerciseName;

  final int order;

  final List<TrainingSet> sets;

  const TrainingExercise({
    required this.exerciseName,
    required this.order,
    required this.sets,
  });

  Map<String, dynamic> toJson() {
    return {
      'exerciseName': exerciseName,
      'order': order,
      'sets': sets.map((e) => e.toJson()).toList(),
    };
  }

  factory TrainingExercise.fromJson(Map<String, dynamic> json) {
    return TrainingExercise(
      exerciseName: json['exerciseName'] as String,
      order: json['order'] as int,
      sets: (json['sets'] as List)
          .map((e) => TrainingSet.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
