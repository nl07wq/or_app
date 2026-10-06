import 'reminder_definition.dart';

enum ReminderOccurrenceStatus { pending, completed, skipped }

class ReminderOccurrenceState {
  const ReminderOccurrenceState({
    required this.id,
    required this.definitionId,
    required this.localDate,
    required this.status,
    required this.updatedAt,
    this.completedAt,
  });
  final String id;
  final String definitionId;
  final String localDate;
  final ReminderOccurrenceStatus status;
  final DateTime updatedAt;
  final DateTime? completedAt;
  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': 1,
    'definitionId': definitionId,
    'localDate': localDate,
    'status': status.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
  };
  factory ReminderOccurrenceState.fromRecord(Map<String, Object?> value) {
    final id = value['id'];
    final definitionId = value['definitionId'];
    final localDate = value['localDate'];
    final status = value['status'];
    final updatedAt = value['updatedAt'];
    if (id is! String ||
        definitionId is! String ||
        localDate is! String ||
        status is! String ||
        updatedAt is! String)
      throw const FormatException('Invalid reminder occurrence state.');
    final updated = DateTime.tryParse(updatedAt);
    final completed = value['completedAt'] is String
        ? DateTime.tryParse(value['completedAt'] as String)
        : null;
    if (updated == null)
      throw const FormatException('Invalid reminder occurrence timestamp.');
    return ReminderOccurrenceState(
      id: id,
      definitionId: definitionId,
      localDate: localDate,
      status: ReminderOccurrenceStatus.values.firstWhere(
        (item) => item.name == status,
        orElse: () =>
            throw const FormatException('Invalid reminder occurrence status.'),
      ),
      updatedAt: updated.toUtc(),
      completedAt: completed?.toUtc(),
    );
  }
}

class ReminderOccurrence {
  const ReminderOccurrence({
    required this.definition,
    required this.localDate,
    required this.status,
  });
  final ReminderDefinition definition;
  final String localDate;
  final ReminderOccurrenceStatus status;
  String get id => '${definition.id}@$localDate';
}
