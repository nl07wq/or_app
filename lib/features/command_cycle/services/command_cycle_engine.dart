import '../../morning_fact/models/morning_fact.dart';
import '../../training/models/training_summary.dart';
import '../models/command_cycle_state.dart';

class CommandCycleEngine {
  final TrainingSummary? _trainingSummary;
  final MorningFact? _morningFact;

  const CommandCycleEngine()
    : _trainingSummary = null,
      _morningFact = null;

  const CommandCycleEngine._({this._trainingSummary, this._morningFact});

  CommandCycleEngine registerTrainingSummary(TrainingSummary summary) {
    return CommandCycleEngine._(
      trainingSummary: summary,
      morningFact: _morningFact,
    );
  }

  CommandCycleEngine registerMorningFact(MorningFact fact) {
    return CommandCycleEngine._(
      trainingSummary: _trainingSummary,
      morningFact: fact,
    );
  }

  CommandCycleState build() {
    return CommandCycleState(
      trainingSummary: _trainingSummary,
      morningFact: _morningFact,
    );
  }
}
