import '../../schedule/models/schedule_record.dart';
import '../../schedule/repository/schedule_repository.dart';
import '../models/reminder_definition.dart';
import '../models/reminder_occurrence.dart';
import '../repository/reminder_repository.dart';

/// Copies legacy reminder records once, with deterministic IDs. The legacy
/// records remain untouched until a later retention policy explicitly removes
/// them, so a failed or interrupted migration cannot lose user data.
class LegacyReminderMigrationService {
  const LegacyReminderMigrationService(this._schedules, this._reminders);

  final ScheduleRepository _schedules;
  final ReminderRepository _reminders;

  Future<int> migrate({DateTime Function()? now}) async {
    final timestamp = (now ?? DateTime.now)().toUtc();
    final existing = {
      for (final value in await _reminders.findDefinitions()) value.id,
    };
    var added = 0;
    for (final record in await _schedules.findAll()) {
      if (record.kind != ScheduleEntryKind.reminder) continue;
      final id = 'legacy-reminder-${record.id}';
      if (existing.contains(id)) continue;
      final definition = ReminderDefinition(
        id: id,
        title: record.title,
        note: record.memo,
        startDate: record.localDate,
        allDay: record.allDay || record.startTime == null,
        time: record.allDay ? null : record.startTime,
        recurrence: ReminderRecurrence.none,
        active: true,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );
      await _reminders.saveDefinition(definition);
      if (record.completed) {
        await _reminders.saveState(
          ReminderOccurrenceState(
            id: '$id@${record.localDate}',
            definitionId: id,
            localDate: record.localDate,
            status: ReminderOccurrenceStatus.completed,
            updatedAt: timestamp,
            completedAt: timestamp,
          ),
        );
      }
      existing.add(id);
      added++;
    }
    return added;
  }
}
