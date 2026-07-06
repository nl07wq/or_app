import '../models/command_state.dart';
import '../models/command_status.dart';
import 'rule_engine.dart';
import '../models/command_priority.dart';

class DefaultRuleEngine extends RuleEngine {
  const DefaultRuleEngine();

  @override
  CommandState evaluate() {
    return const CommandState(
      module: 'System',
      status: CommandStatus.ready,
      priority: CommandPriority.none,
      message: 'System Ready',
      action: null,
    );
  }
}
