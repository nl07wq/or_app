import 'command_status.dart';

class ModuleStatus {
  final String module;
  final String message;
  final CommandStatus status;

  const ModuleStatus({
    required this.module,
    required this.message,
    required this.status,
  });
}
