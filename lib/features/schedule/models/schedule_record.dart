enum ScheduleType { work, personal, appointment, training, other }

class ScheduleRecord {
  const ScheduleRecord({
    required this.id,
    required this.localDate,
    required this.type,
    required this.title,
    this.startTime,
    this.endTime,
    this.breakDuration,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String localDate;
  final ScheduleType type;
  final String title;
  final String? startTime;
  final String? endTime;
  final String? breakDuration;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': 1,
    'localDate': localDate,
    'type': type.name,
    'title': title,
    if (startTime != null) 'startTime': startTime,
    if (endTime != null) 'endTime': endTime,
    if (breakDuration != null) 'breakDuration': breakDuration,
    if (memo != null) 'memo': memo,
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
      type: ScheduleType.values.firstWhere(
        (value) => value.name == type,
        orElse: () => throw const FormatException('Invalid schedule type.'),
      ),
      title: title,
      startTime: record['startTime'] as String?,
      endTime: record['endTime'] as String?,
      breakDuration: record['breakDuration'] as String?,
      memo: record['memo'] as String?,
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
    );
  }
}
