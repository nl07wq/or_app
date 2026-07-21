import '../../features/morning/models/morning_fact.dart';

import 'activity_summary.dart';
import 'food_summary.dart';
import 'training_summary.dart';

class OperationInput {
  final MorningFact morning;
  final FoodSummary? food;
  final TrainingSummary? training;
  final ActivitySummary? activity;

  const OperationInput({
    required this.morning,
    this.food,
    this.training,
    this.activity,
  });
}
