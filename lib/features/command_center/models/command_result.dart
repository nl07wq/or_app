import 'command_state.dart';
import 'command_status.dart';

class CommandResult {
  final CommandStatus operationStatus;
  final String commanderIntent;
  final CommandState highestPriority;
  final List<CommandState> states;

  const CommandResult({
    required this.operationStatus,
    required this.commanderIntent,
    required this.highestPriority,
    required this.states,
  });
}
