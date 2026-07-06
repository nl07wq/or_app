import '../models/command_state.dart';

abstract class RuleEngine {
  const RuleEngine();

  CommandState evaluate();
}
