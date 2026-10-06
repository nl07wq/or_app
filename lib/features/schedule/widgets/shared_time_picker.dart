import 'package:flutter/material.dart';

/// The single Material time-selection surface for Schedule and Reminder.
Future<TimeOfDay?> showSharedTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) => showTimePicker(context: context, initialTime: initialTime);

TimeOfDay timeOfDayFromClock(String? value, {TimeOfDay fallback = const TimeOfDay(hour: 9, minute: 0)}) {
  final parts = value?.split(':');
  if (parts?.length != 2) return fallback;
  final hour = int.tryParse(parts![0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return fallback;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String clockFromTimeOfDay(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
