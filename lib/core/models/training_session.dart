import 'training_exercise.dart';

class TrainingSession {
  final String date;

  final String memo;

  final List<TrainingExercise> exercises;

  const TrainingSession({
    required this.date,
    required this.memo,
    required this.exercises,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'memo': memo,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      date: json['date'] as String,
      memo: json['memo'] as String,
      exercises: (json['exercises'] as List)
          .map((e) => TrainingExercise.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
