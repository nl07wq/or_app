import '../../reminders/models/reminder_definition.dart';

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
    this.recurrence = ReminderRecurrence.none,
    this.recurrenceEnd,
    this.recurrenceWeekdays = const [],
    this.recurrenceMonthDays = const [],
    this.recurrenceMonthEnd = false,
    this.recurrenceMonthWeek,
    this.recurrenceMonthWeeks = const [],
    this.notificationOffsetsMinutes = const [],
    this.notificationTimeZone = 'Etc/UTC',
    this.seriesId,
    this.occurrenceDate,
    this.occurrenceExcluded = false,
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
  final ReminderRecurrence recurrence;
  final String? recurrenceEnd;
  final List<int> recurrenceWeekdays;
  final List<int> recurrenceMonthDays;
  final bool recurrenceMonthEnd;
  final int? recurrenceMonthWeek;
  final List<int> recurrenceMonthWeeks;
  final List<int> notificationOffsetsMinutes;
  final String notificationTimeZone;

  /// A recurring definition owns one logical series. Individual overrides and
  /// exclusions carry its id plus the original scheduled date.
  final String? seriesId;
  final String? occurrenceDate;
  final bool occurrenceExcluded;

  bool get isRecurringSeries =>
      recurrence != ReminderRecurrence.none && occurrenceDate == null;
  bool get isOccurrenceOverride => occurrenceDate != null;
  String get effectiveSeriesId => seriesId ?? id;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': 5,
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
    'recurrence': recurrence.name,
    if (recurrenceEnd != null) 'recurrenceEnd': recurrenceEnd,
    if (recurrenceWeekdays.isNotEmpty) 'recurrenceWeekdays': recurrenceWeekdays,
    if (recurrenceMonthDays.isNotEmpty)
      'recurrenceMonthDays': recurrenceMonthDays,
    if (recurrenceMonthEnd) 'recurrenceMonthEnd': true,
    if (recurrenceMonthWeek != null) 'recurrenceMonthWeek': recurrenceMonthWeek,
    if (recurrenceMonthWeeks.isNotEmpty)
      'recurrenceMonthWeeks': recurrenceMonthWeeks,
    if (notificationOffsetsMinutes.isNotEmpty)
      'notificationOffsetsMinutes': notificationOffsetsMinutes,
    'notificationTimeZone': notificationTimeZone,
    if (seriesId != null) 'seriesId': seriesId,
    if (occurrenceDate != null) 'occurrenceDate': occurrenceDate,
    if (occurrenceExcluded) 'occurrenceExcluded': true,
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
    List<int> ints(Object? raw, int min, int max) {
      if (raw == null) return const [];
      if (raw is! List ||
          raw.any((value) => value is! int || value < min || value > max)) {
        throw const FormatException('Invalid schedule recurrence values.');
      }
      return List.unmodifiable(raw.cast<int>().toSet().toList()..sort());
    }

    final recurrenceMonthWeek = record['recurrenceMonthWeek'];
    if (recurrenceMonthWeek != null &&
        (recurrenceMonthWeek is! int ||
            recurrenceMonthWeek < 1 ||
            recurrenceMonthWeek > 5)) {
      throw const FormatException('Invalid schedule recurrence month week.');
    }

    final recurrenceName = record['recurrence'];
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
      recurrence: recurrenceName == null
          ? ReminderRecurrence.none
          : ReminderRecurrence.values.firstWhere(
              (value) => value.name == recurrenceName,
              orElse: () => throw const FormatException('Invalid recurrence.'),
            ),
      recurrenceEnd: record['recurrenceEnd'] as String?,
      recurrenceWeekdays: ints(record['recurrenceWeekdays'], 1, 7),
      recurrenceMonthDays: ints(record['recurrenceMonthDays'], 1, 31),
      recurrenceMonthEnd: record['recurrenceMonthEnd'] == true,
      recurrenceMonthWeek: recurrenceMonthWeek as int?,
      recurrenceMonthWeeks: ints(record['recurrenceMonthWeeks'], 1, 5),
      notificationOffsetsMinutes: ints(
        record['notificationOffsetsMinutes'],
        0,
        525600 * 10,
      ),
      notificationTimeZone:
          record['notificationTimeZone'] as String? ?? 'Etc/UTC',
      seriesId: record['seriesId'] as String?,
      occurrenceDate: record['occurrenceDate'] as String?,
      occurrenceExcluded: record['occurrenceExcluded'] == true,
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
    );
  }
}
