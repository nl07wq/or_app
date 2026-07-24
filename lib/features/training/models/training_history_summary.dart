import '../../../core/models/training_set.dart';

class TrainingHistorySummary {
  final List<TrainingSet> sets;

  TrainingHistorySummary({required Iterable<TrainingSet> sets})
    : sets = List.unmodifiable(sets);
}
