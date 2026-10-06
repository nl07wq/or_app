import 'package:flutter/material.dart';

import '../../schedule/models/schedule_record.dart';
import '../../schedule/repository/schedule_repository.dart';
import '../../reminders/models/reminder_occurrence.dart';
import '../../reminders/repository/reminder_repository.dart';
import '../../reminders/services/reminder_occurrence_service.dart';

enum DashboardPlanInformationGroup {
  todaySchedule,
  todayReminder,
  overdueReminder,
}

class DashboardPlanInformationEntry {
  const DashboardPlanInformationEntry({
    required this.record,
    required this.group,
  });

  final ScheduleRecord record;
  final DashboardPlanInformationGroup group;

  bool get isOverdue => group == DashboardPlanInformationGroup.overdueReminder;

  bool get isTimed => !record.allDay && record.startTime != null;
}

class DashboardPlanInformation {
  const DashboardPlanInformation({
    required this.operationDate,
    required this.entries,
  });

  final String operationDate;
  final List<DashboardPlanInformationEntry> entries;
}

/// Read-only Dashboard projection of Calendar's Plan authority.
class DashboardPlanInformationService {
  const DashboardPlanInformationService(this._schedules, {this.reminders});

  final ScheduleRepository _schedules;
  final ReminderRepository? reminders;

  Future<DashboardPlanInformation> loadFor(String operationDate) async {
    final entries = <DashboardPlanInformationEntry>[];
    for (final record in await _schedules.findAll()) {
      if (record.kind == ScheduleEntryKind.reminder && reminders != null) {
        continue;
      }
      final group = _groupFor(record, operationDate);
      if (group != null) {
        entries.add(
          DashboardPlanInformationEntry(record: record, group: group),
        );
      }
    }
    final reminderRepository = reminders;
    if (reminderRepository != null) {
      final date = DateTime.parse(operationDate);
      final occurrences = await ReminderOccurrenceService(
        reminderRepository,
      ).inRange(DateTimeRange(start: date, end: date), includeCompleted: false);
      for (final occurrence in occurrences) {
        entries.add(
          DashboardPlanInformationEntry(
            record: _projectReminder(occurrence),
            group: DashboardPlanInformationGroup.todayReminder,
          ),
        );
      }
    }
    entries.sort(_compareEntries);
    return DashboardPlanInformation(
      operationDate: operationDate,
      entries: List.unmodifiable(entries),
    );
  }

  DashboardPlanInformationGroup? _groupFor(
    ScheduleRecord record,
    String operationDate,
  ) {
    if (record.kind == ScheduleEntryKind.reminder) {
      if (record.completed || record.localDate.compareTo(operationDate) > 0) {
        return null;
      }
      if (record.localDate.compareTo(operationDate) < 0) {
        return DashboardPlanInformationGroup.overdueReminder;
      }
      return DashboardPlanInformationGroup.todayReminder;
    }

    if (record.localDate != operationDate) return null;
    return DashboardPlanInformationGroup.todaySchedule;
  }

  int _compareEntries(
    DashboardPlanInformationEntry first,
    DashboardPlanInformationEntry second,
  ) {
    final group = first.group.index.compareTo(second.group.index);
    if (group != 0) return group;

    if (first.isOverdue) {
      final date = first.record.localDate.compareTo(second.record.localDate);
      if (date != 0) return date;
    }

    if (first.isTimed && second.isTimed) {
      final time = first.record.startTime!.compareTo(second.record.startTime!);
      if (time != 0) return time;
    } else if (first.isTimed != second.isTimed) {
      return first.isTimed ? -1 : 1;
    } else {
      final allDay = _allDayRank(
        first.record,
      ).compareTo(_allDayRank(second.record));
      if (allDay != 0) return allDay;
    }

    final kind = first.record.kind.index.compareTo(second.record.kind.index);
    if (kind != 0) return kind;
    final title = first.record.title.compareTo(second.record.title);
    return title != 0 ? title : first.record.id.compareTo(second.record.id);
  }

  int _allDayRank(ScheduleRecord record) => record.allDay ? 0 : 1;
}

ScheduleRecord _projectReminder(ReminderOccurrence occurrence) =>
    ScheduleRecord(
      id: occurrence.id,
      localDate: occurrence.localDate,
      type: ScheduleType.other,
      title: occurrence.definition.title,
      kind: ScheduleEntryKind.reminder,
      allDay: occurrence.definition.allDay,
      startTime: occurrence.definition.time,
      memo: occurrence.definition.note,
      completed: occurrence.status == ReminderOccurrenceStatus.completed,
      createdAt: occurrence.definition.createdAt,
      updatedAt: occurrence.definition.updatedAt,
    );
