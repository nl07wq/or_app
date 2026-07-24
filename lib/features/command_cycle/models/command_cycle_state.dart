import '../../morning_fact/models/morning_fact.dart';
import '../../training/models/training_summary.dart';

class CommandCycleState {
  final TrainingSummary? trainingSummary;
  final MorningFact? morningFact;

  const CommandCycleState({this.trainingSummary, this.morningFact});
}
