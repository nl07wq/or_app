import '../models/notification_configuration.dart';

class NotificationSourceOccurrence {
  const NotificationSourceOccurrence({
    required this.entityType,
    required this.entityId,
    required this.localDate,
    required this.allDay,
    required this.startTime,
    required this.timeZone,
    required this.offsetsMinutes,
    required this.title,
  });

  final String entityType;
  final String entityId;
  final String localDate;
  final bool allDay;
  final String? startTime;
  final String timeZone;
  final List<int> offsetsMinutes;
  final String title;
}

class NotificationProjection {
  const NotificationProjection({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.occurrenceLocalDate,
    required this.triggerAt,
    required this.timeZone,
    required this.privacyMode,
    this.title,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String occurrenceLocalDate;
  final DateTime triggerAt;
  final String timeZone;
  final NotificationPrivacyMode privacyMode;
  final String? title;

  Map<String, Object?> toJson() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'occurrenceLocalDate': occurrenceLocalDate,
    'triggerAt': triggerAt.toUtc().toIso8601String(),
    'timeZone': timeZone,
    'privacyMode': privacyMode.name,
    if (privacyMode == NotificationPrivacyMode.titleVisible && title != null)
      'title': title,
  };
}

typedef WallTimeResolver =
    int Function(String localDate, String localTime, String timeZone);

class NotificationProjectionPlanner {
  const NotificationProjectionPlanner(this._wallTimeResolver);

  final WallTimeResolver _wallTimeResolver;

  List<NotificationProjection> project(
    Iterable<NotificationSourceOccurrence> occurrences, {
    required NotificationPrivacyMode privacyMode,
    required DateTime now,
  }) {
    final result = <String, NotificationProjection>{};
    for (final occurrence in occurrences) {
      final authorityTime = occurrence.allDay ? '00:00' : occurrence.startTime;
      if (authorityTime == null || occurrence.offsetsMinutes.isEmpty) continue;
      final authority = DateTime.fromMillisecondsSinceEpoch(
        _wallTimeResolver(
          occurrence.localDate,
          authorityTime,
          occurrence.timeZone,
        ),
        isUtc: true,
      );
      for (final offset in occurrence.offsetsMinutes.toSet()) {
        final trigger = authority.subtract(Duration(minutes: offset));
        if (!trigger.isAfter(now.toUtc())) continue;
        final id =
            '${occurrence.entityType}:${occurrence.entityId}@'
            '${occurrence.localDate}:$offset';
        result[id] = NotificationProjection(
          id: id,
          entityType: occurrence.entityType,
          entityId: occurrence.entityId,
          occurrenceLocalDate: occurrence.localDate,
          triggerAt: trigger,
          timeZone: occurrence.timeZone,
          privacyMode: privacyMode,
          title: privacyMode == NotificationPrivacyMode.titleVisible
              ? occurrence.title
              : null,
        );
      }
    }
    final sorted = result.values.toList()
      ..sort((first, second) => first.triggerAt.compareTo(second.triggerAt));
    return sorted;
  }
}
