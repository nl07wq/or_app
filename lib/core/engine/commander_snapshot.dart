import 'operation_status.dart';

class CommanderSnapshot {
  final OperationStatus status;
  final String commanderIntent;
  final String summary;
  final List<String> actions;

  const CommanderSnapshot({
    required this.status,
    required this.commanderIntent,
    required this.summary,
    required this.actions,
  });

  CommanderSnapshot copyWith({
    OperationStatus? status,
    String? commanderIntent,
    String? summary,
    List<String>? actions,
  }) {
    return CommanderSnapshot(
      status: status ?? this.status,
      commanderIntent: commanderIntent ?? this.commanderIntent,
      summary: summary ?? this.summary,
      actions: actions ?? this.actions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CommanderSnapshot &&
        status == other.status &&
        commanderIntent == other.commanderIntent &&
        summary == other.summary &&
        _sameActions(other.actions);
  }

  bool _sameActions(List<String> other) {
    if (actions.length != other.length) return false;

    for (var index = 0; index < actions.length; index++) {
      if (actions[index] != other[index]) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      commanderIntent,
      summary,
      Object.hashAll(actions),
    );
  }
}
