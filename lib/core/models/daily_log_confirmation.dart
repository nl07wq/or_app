import '../engine/activity_summary.dart';
import '../engine/food_summary.dart';
import '../engine/training_summary.dart';
import '../../features/morning/models/morning_fact.dart';

class DailyLogConfirmation {
  final DateTime date;
  final DateTime confirmedAt;
  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary? activity;
  final TrainingSummary? training;

  DailyLogConfirmation({
    required DateTime date,
    required this.confirmedAt,
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
  }) : date = DateTime(date.year, date.month, date.day);

  DailyLogConfirmation copyWith({
    DateTime? date,
    DateTime? confirmedAt,
    MorningFact? morning,
    FoodSummary? food,
    ActivitySummary? activity,
    TrainingSummary? training,
  }) => DailyLogConfirmation(
    date: date ?? this.date,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    morning: morning ?? this.morning,
    food: food ?? this.food,
    activity: activity ?? this.activity,
    training: training ?? this.training,
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'confirmedAt': confirmedAt.toIso8601String(),
    'morning': morning?.toJson(),
    'food': food?.toJson(),
    'activity': activity?.toJson(),
    'training': training?.toJson(),
  };

  factory DailyLogConfirmation.fromJson(Map<String, dynamic> json) =>
      DailyLogConfirmation(
        date: DateTime.parse(json['date'] as String),
        confirmedAt: DateTime.parse(json['confirmedAt'] as String),
        morning: json['morning'] == null
            ? null
            : MorningFact.fromJson(Map<String, dynamic>.from(json['morning'])),
        food: json['food'] == null
            ? null
            : FoodSummary.fromJson(Map<String, dynamic>.from(json['food'])),
        activity: json['activity'] == null
            ? null
            : ActivitySummary.fromJson(Map<String, dynamic>.from(json['activity'])),
        training: json['training'] == null
            ? null
            : TrainingSummary.fromJson(Map<String, dynamic>.from(json['training'])),
      );
}
