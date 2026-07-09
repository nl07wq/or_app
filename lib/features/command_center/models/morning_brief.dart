import 'command_status.dart';

class MorningBrief {
  final CommandStatus operationStatus;

  final String situation;

  final String summary;

  final String commanderIntent;

  final List<String> actions;

  const MorningBrief({
    required this.operationStatus,
    required this.situation,
    required this.summary,
    required this.commanderIntent,
    required this.actions,
  });
}
