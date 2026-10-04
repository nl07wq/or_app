enum ReminderRecurrence {
  none,
  daily,
  weekdays,
  weekends,
  weekly,
  biweekly,
  monthly,
  yearly,
  customWeekdays,
  customMonthDays,
}

class ReminderDefinition {
  const ReminderDefinition({
    required this.id,
    required this.title,
    required this.startDate,
    required this.allDay,
    required this.recurrence,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.time,
    this.recurrenceEnd,
    this.weekdays = const [],
    this.monthDays = const [],
    this.monthEnd = false,
    this.effectiveFrom,
    this.retiredAt,
  });

  final String id;
  final String title;
  final String? note;
  final String startDate;
  final bool allDay;
  final String? time;
  final ReminderRecurrence recurrence;
  final String? recurrenceEnd;
  final List<int> weekdays;
  final List<int> monthDays;
  final bool monthEnd;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? effectiveFrom;

  /// A superseded recurring definition remains readable for occurrences that
  /// were already scheduled before this instant.
  final DateTime? retiredAt;

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': 1,
    'title': title,
    if (note != null) 'note': note,
    'startDate': startDate,
    'allDay': allDay,
    if (time != null) 'time': time,
    'recurrence': recurrence.name,
    if (recurrenceEnd != null) 'recurrenceEnd': recurrenceEnd,
    if (weekdays.isNotEmpty) 'weekdays': weekdays,
    if (monthDays.isNotEmpty) 'monthDays': monthDays,
    if (monthEnd) 'monthEnd': true,
    'active': active,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (effectiveFrom != null)
      'effectiveFrom': effectiveFrom!.toUtc().toIso8601String(),
    if (retiredAt != null) 'retiredAt': retiredAt!.toUtc().toIso8601String(),
  };

  factory ReminderDefinition.fromRecord(Map<String, Object?> value) {
    final id = value['id'];
    final title = value['title'];
    final startDate = value['startDate'];
    final recurrence = value['recurrence'];
    final createdAt = value['createdAt'];
    final updatedAt = value['updatedAt'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        startDate is! String ||
        recurrence is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid reminder definition.');
    }
    final created = DateTime.tryParse(createdAt);
    final updated = DateTime.tryParse(updatedAt);
    if (created == null || updated == null)
      throw const FormatException('Invalid reminder timestamp.');
    List<int> readInts(Object? raw, int min, int max) {
      if (raw == null) return const [];
      if (raw is! List ||
          raw.any((item) => item is! int || item < min || item > max))
        throw const FormatException('Invalid reminder recurrence values.');
      return List.unmodifiable(raw.cast<int>().toSet().toList()..sort());
    }

    return ReminderDefinition(
      id: id,
      title: title.trim(),
      note: value['note'] as String?,
      startDate: startDate,
      allDay: value['allDay'] != false,
      time: value['time'] as String?,
      recurrence: ReminderRecurrence.values.firstWhere(
        (item) => item.name == recurrence,
        orElse: () =>
            throw const FormatException('Invalid reminder recurrence.'),
      ),
      recurrenceEnd: value['recurrenceEnd'] as String?,
      weekdays: readInts(value['weekdays'], 1, 7),
      monthDays: readInts(value['monthDays'], 1, 31),
      monthEnd: value['monthEnd'] == true,
      active: value['active'] != false,
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
      effectiveFrom: value['effectiveFrom'] is String
          ? DateTime.tryParse(value['effectiveFrom'] as String)?.toUtc()
          : null,
      retiredAt: value['retiredAt'] is String
          ? DateTime.tryParse(value['retiredAt'] as String)?.toUtc()
          : null,
    );
  }
}
