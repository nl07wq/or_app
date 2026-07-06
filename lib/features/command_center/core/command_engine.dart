import '../models/command_result.dart';
import '../models/command_state.dart';
import 'default_rule_engine.dart';
import 'rule_engine.dart';
import 'morning_rule_engine.dart';
import '../models/morning_fact.dart';

class CommandEngine {
  final List<RuleEngine> rules;

  CommandEngine({required MorningFact morningFact, List<RuleEngine>? rules})
    : rules =
          rules ??
          [const DefaultRuleEngine(), MorningRuleEngine(fact: morningFact)];
  List<CommandState> evaluate() {
    return rules.map((rule) => rule.evaluate()).toList();
  }

  CommandState resolveHighestPriority(List<CommandState> states) {
    states.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    return states.first;
  }

  CommandResult buildResult() {
    final states = evaluate();

    final highest = resolveHighestPriority(states);

    return CommandResult(
      operationStatus: highest.status,
      commanderIntent: highest.message,
      highestPriority: highest,
      states: states,
    );
  }
}
