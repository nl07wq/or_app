import 'command_priority.dart';
import 'command_status.dart';

class CommandState {
  final String module;
  final CommandStatus status;
  final CommandPriority priority;
  final String message;
  final String? action;

  const CommandState({
    required this.module,
    required this.status,
    required this.priority,
    required this.message,
    this.action,
  });
}
