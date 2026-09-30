enum ScheduleType { work, personal, appointment, training, other }

enum ScheduleEntryKind { schedule, reminder }

class ScheduleRecord {
  const ScheduleRecord({
    required this.id,
    required this.localDate,
    required this.type,
    required this.title,
    this.kind = ScheduleEntryKind.schedule,
    this.allDay = false,
    this.startTime,
    this.endTime,
    this.breakDuration,
    this.memo,
    this.completed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String localDate;
  final ScheduleType type;
  final String title;
  final ScheduleEntryKind kind;
  final bool allDay;
  final String? startTime;
  final String? endTime;
  final String? breakDuration;
  final String? memo;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': 2,
    'localDate': localDate,
    'type': type.name,
    'title': title,
    'kind': kind.name,
    if (allDay) 'allDay': true,
    if (startTime != null) 'startTime': startTime,
    if (endTime != null) 'endTime': endTime,
    if (breakDuration != null) 'breakDuration': breakDuration,
    if (memo != null) 'memo': memo,
    if (completed) 'completed': true,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ScheduleRecord.fromRecord(Map<String, Object?> record) {
    final id = record['id'];
    final localDate = record['localDate'];
    final type = record['type'];
    final title = record['title'];
    final createdAt = record['createdAt'];
    final updatedAt = record['updatedAt'];
    final kindValue = record['kind'];
    if (id is! String ||
        id.isEmpty ||
        localDate is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(localDate) ||
        type is! String ||
        title is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid schedule record.');
    }
    final created = DateTime.tryParse(createdAt);
    final updated = DateTime.tryParse(updatedAt);
    if (created == null || updated == null) {
      throw const FormatException('Invalid schedule timestamp.');
    }
    return ScheduleRecord(
      id: id,
      localDate: localDate,
      kind: kindValue == null
          ? ScheduleEntryKind.schedule
          : ScheduleEntryKind.values.firstWhere(
              (value) => value.name == kindValue,
              orElse: () => throw const FormatException('Invalid entry kind.'),
            ),
      allDay: record['allDay'] == true,
      type: ScheduleType.values.firstWhere(
        (value) => value.name == type,
        orElse: () => throw const FormatException('Invalid schedule type.'),
      ),
      title: title,
      startTime: record['startTime'] as String?,
      endTime: record['endTime'] as String?,
      breakDuration: record['breakDuration'] as String?,
      memo: record['memo'] as String?,
      completed: record['completed'] == true,
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
    );
  }
}
