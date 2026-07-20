import '../../features/morning/models/morning_fact.dart';

import 'food_summary.dart';
import 'training_summary.dart';

class OperationInput {
  final MorningFact morning;
  final FoodSummary? food;
  final TrainingSummary? training;

  const OperationInput({
    required this.morning,
    this.food,
    this.training,
  });
}
