import '../../training/models/training_summary.dart';
import '../models/command_cycle_state.dart';

class CommandCycleEngine {
  final TrainingSummary? _trainingSummary;

  const CommandCycleEngine() : _trainingSummary = null;

  const CommandCycleEngine._({this._trainingSummary});

  CommandCycleEngine registerTrainingSummary(TrainingSummary summary) {
    return CommandCycleEngine._(trainingSummary: summary);
  }

  CommandCycleState build() {
    return CommandCycleState(trainingSummary: _trainingSummary);
  }
}
