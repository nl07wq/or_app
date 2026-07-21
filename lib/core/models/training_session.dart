import 'training_exercise.dart';
import 'cardio_entry.dart';

class TrainingSession {
  final String date;

  final String memo;

  final List<TrainingExercise> exercises;
  final List<CardioEntry> cardioEntries;

  TrainingSession({
    required this.date,
    required this.memo,
    required this.exercises,
    List<CardioEntry> cardioEntries = const [],
  }) : cardioEntries = List.unmodifiable(cardioEntries);

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'memo': memo,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'cardioEntries': cardioEntries.map((entry) => entry.toJson()).toList(),
    };
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      date: json['date'] as String,
      memo: json['memo'] as String,
      exercises: (json['exercises'] as List)
          .map((e) => TrainingExercise.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      cardioEntries: (json['cardioEntries'] as List? ?? const [])
          .map((entry) => CardioEntry.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
    );
  }
}
