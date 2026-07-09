import 'command_status.dart';
import 'command_state.dart';
import 'commander_message.dart';
import 'commander_warning.dart';

class MorningBrief {
  final CommandStatus operationStatus;

  final String situation;

  final String summary;

  final String commanderIntent;

  final List<String> actions;

  final String operationId;

  final CommanderMessage commanderMessage;

  final List<CommanderWarning> commanderWarnings;

  final List<CommandState> states;

  const MorningBrief({
    required this.operationStatus,
    required this.situation,
    required this.summary,
    required this.commanderIntent,
    required this.actions,
    required this.operationId,
    required this.commanderMessage,
    required this.commanderWarnings,
    required this.states,
  });
}
