import 'package:flutter/foundation.dart';

enum NotificationPrivacyMode { titleVisible, contentHidden }

@immutable
class NotificationConfiguration {
  NotificationConfiguration({
    Iterable<int> offsetsMinutes = const [],
    required this.timeZone,
  }) : offsetsMinutes = List.unmodifiable(
         offsetsMinutes.where((value) => value >= 0).toSet().toList()..sort(),
       );

  final List<int> offsetsMinutes;
  final String timeZone;

  bool get enabled => offsetsMinutes.isNotEmpty;

  NotificationConfiguration copyWith({
    Iterable<int>? offsetsMinutes,
    String? timeZone,
  }) => NotificationConfiguration(
    offsetsMinutes: offsetsMinutes ?? this.offsetsMinutes,
    timeZone: timeZone ?? this.timeZone,
  );
}

enum NotificationOffsetUnit {
  minutes('分', 1),
  hours('時間', 60),
  days('日', 1440),
  weeks('週間', 10080);

  const NotificationOffsetUnit(this.label, this.multiplierMinutes);
  final String label;
  final int multiplierMinutes;
}

int canonicalNotificationOffset(int number, NotificationOffsetUnit unit) {
  if (number < 0) throw ArgumentError.value(number, 'number');
  return number * unit.multiplierMinutes;
}

String notificationOffsetLabel(int minutes) {
  if (minutes == 0) return '開始時刻';
  if (minutes % NotificationOffsetUnit.weeks.multiplierMinutes == 0) {
    return '${minutes ~/ NotificationOffsetUnit.weeks.multiplierMinutes}週間前';
  }
  if (minutes % NotificationOffsetUnit.days.multiplierMinutes == 0) {
    return '${minutes ~/ NotificationOffsetUnit.days.multiplierMinutes}日前';
  }
  if (minutes % NotificationOffsetUnit.hours.multiplierMinutes == 0) {
    return '${minutes ~/ NotificationOffsetUnit.hours.multiplierMinutes}時間前';
  }
  return '$minutes分前';
}
