import '../../schedule/models/schedule_record.dart';
import '../../schedule/repository/schedule_repository.dart';

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
  const DashboardPlanInformationService(this._schedules);

  final ScheduleRepository _schedules;

  Future<DashboardPlanInformation> loadFor(String operationDate) async {
    final entries = <DashboardPlanInformationEntry>[];
    for (final record in await _schedules.findAll()) {
      final group = _groupFor(record, operationDate);
      if (group != null) {
        entries.add(
          DashboardPlanInformationEntry(record: record, group: group),
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
