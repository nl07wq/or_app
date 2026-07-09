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

    if (fact.fatigue >= 4) {
      return const CommandState(
        module: 'Morning',
        status: CommandStatus.warning,
        priority: CommandPriority.medium,
        message: '疲労蓄積',
        action: '回復を優先する',
      );
    }

    if (fact.plantarPain >= 5) {
      return const CommandState(
        module: 'Morning',
        status: CommandStatus.warning,
        priority: CommandPriority.medium,
        message: '足底筋膜炎悪化',
        action: '歩行負荷を抑える',
      );
    }

    if (fact.weight >= 106.0) {
      return const CommandState(
        module: 'Morning',
        status: CommandStatus.warning,
        priority: CommandPriority.low,
        message: '体重増加',
        action: '食事管理を意識する',
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
