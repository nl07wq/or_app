import '../models/command_priority.dart';
import '../models/command_state.dart';
import '../models/command_status.dart';
import '../models/morning_fact.dart';
import 'rule_engine.dart';

class MorningRuleEngine extends RuleEngine {
  final MorningFact fact;

  const MorningRuleEngine({required this.fact});

  @override
  CommandState evaluate() {
    if (fact.sleepMinutes < 360) {
      return const CommandState(
        module: 'Morning',
        status: CommandStatus.warning,
        priority: CommandPriority.high,
        message: '睡眠不足',
        action: '休憩時間を確保する',
      );
    }

    return const CommandState(
      module: 'Morning',
      status: CommandStatus.ready,
      priority: CommandPriority.none,
      message: 'Morning check completed.',
      action: null,
    );
  }
}
