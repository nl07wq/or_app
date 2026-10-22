import 'package:flutter/material.dart';

import '../../../core/widgets/global_touch_ripple.dart';
import '../../reminders/models/reminder_definition.dart';
import 'shared_time_picker.dart';

/// Common date/time input used by the Schedule and Reminder editors.
///
/// It deliberately owns only editable presentation. Each domain retains its
/// own persistence and action semantics.
class SharedDateTimeEditor extends StatelessWidget {
  const SharedDateTimeEditor({
    super.key,
    required this.date,
    required this.allDay,
    required this.startTime,
    required this.endTime,
    required this.onDateChanged,
    required this.onAllDayChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    this.endDate,
    this.onEndDateChanged,
    this.showAllDayToggle = true,
    this.showOverdueNote = false,
  });

  final DateTime date;
  final bool allDay;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<bool> onAllDayChanged;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;
  final DateTime? endDate;
  final ValueChanged<DateTime>? onEndDateChanged;
  final bool showAllDayToggle;
  final bool showOverdueNote;

  Future<void> _pickDate(BuildContext context) async {
    final value = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) onDateChanged(DateUtils.dateOnly(value));
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final value = await showDatePicker(
      context: context,
      initialDate: endDate ?? date,
      firstDate: date,
      lastDate: DateTime(2100),
    );
    if (value != null) onEndDateChanged?.call(DateUtils.dateOnly(value));
  }

  Future<void> _pickTime(
    BuildContext context, {
    required TimeOfDay? current,
    required ValueChanged<TimeOfDay?> onChanged,
  }) async {
    final value = await showSharedTimePicker(
      context,
      initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (value != null) onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveEndDate = endDate ?? date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAllDayToggle) ...[
          EditorFormCard(
            key: const ValueKey('shared-date-time-all-day-card'),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.wb_sunny_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('終日'),
              subtitle: const Text('開始・終了時刻を指定せず、終日予定として登録します'),
              value: allDay,
              onChanged: onAllDayChanged,
            ),
          ),
          const SizedBox(height: 12),
        ],
        EditorFormCard(
          key: const ValueKey('shared-date-time-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('日時', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              _DateTimeRow(
                label: '開始',
                date: date,
                time: startTime,
                allDay: allDay,
                onDateTap: () => _pickDate(context),
                onTimeTap: () => _pickTime(
                  context,
                  current: startTime,
                  onChanged: onStartTimeChanged,
                ),
                showTopConnector: false,
                showBottomConnector: true,
              ),
              const SizedBox(height: 8),
              _DateTimeRow(
                label: '終了',
                date: effectiveEndDate,
                time: endTime,
                allDay: allDay,
                onDateTap: onEndDateChanged == null
                    ? () => _pickDate(context)
                    : () => _pickEndDate(context),
                onTimeTap: () => _pickTime(
                  context,
                  current: endTime,
                  onChanged: onEndTimeChanged,
                ),
                showTopConnector: true,
                showBottomConnector: false,
              ),
              if (showOverdueNote) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .65),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '当日の未完了予定は『超過』になりません。翌日以降に残った予定のみ『超過』として表示します。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .70),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class EditorFormCard extends StatelessWidget {
  const EditorFormCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: .30),
          width: .8,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.date,
    required this.time,
    required this.allDay,
    required this.onDateTap,
    required this.onTimeTap,
    required this.showTopConnector,
    required this.showBottomConnector,
  });

  final String label;
  final DateTime date;
  final TimeOfDay? time;
  final bool allDay;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;
  final bool showTopConnector;
  final bool showBottomConnector;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateLabel =
        '${date.year}年${date.month}月${date.day}日 (${_weekday(date.weekday)})';
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showTopConnector)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 1.5,
                      height: 30,
                      color: scheme.primary.withValues(alpha: .55),
                    ),
                  ),
                if (showBottomConnector)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 1.5,
                      height: 30,
                      color: scheme.primary.withValues(alpha: .55),
                    ),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                    border: Border.all(color: scheme.primary, width: 1.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              key: ValueKey('shared-date-time-$label-date'),
              onTap: onDateTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: .70),
                      ),
                    ),
                  ],
                ),
              ),
            ).inputFeedback(),
          ),
          if (!allDay)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                key: ValueKey('shared-date-time-$label-time'),
                onTap: onTimeTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 84,
                    minHeight: 44,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: .35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 5),
                      Text(time == null ? '時刻未設定' : _format24Hour(time!)),
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ).inputFeedback(),
            ),
        ],
      ),
    );
  }

  static String _format24Hour(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static String _weekday(int value) =>
      const ['月', '火', '水', '木', '金', '土', '日'][value - 1];
}

class SharedRecurrenceValue {
  SharedRecurrenceValue({
    required this.recurrence,
    this.end,
    Set<int> weekdays = const <int>{},
    Set<int> monthDays = const <int>{},
    this.monthEnd = false,
    int? monthWeek,
    Set<int> monthWeeks = const <int>{},
  }) : weekdays = Set.unmodifiable(weekdays),
       monthDays = Set.unmodifiable(monthDays),
       monthWeeks = Set.unmodifiable(
         monthWeeks.isNotEmpty
             ? monthWeeks
             : monthWeek == null
             ? const <int>{}
             : <int>{monthWeek},
       );

  final ReminderRecurrence recurrence;
  final DateTime? end;
  final Set<int> weekdays;
  final Set<int> monthDays;
  final bool monthEnd;
  final Set<int> monthWeeks;
  int? get monthWeek =>
      monthWeeks.isEmpty ? null : (monthWeeks.toList()..sort()).first;

  SharedRecurrenceValue copyWith({
    ReminderRecurrence? recurrence,
    DateTime? end,
    bool clearEnd = false,
    Set<int>? weekdays,
    Set<int>? monthDays,
    bool? monthEnd,
    int? monthWeek,
    Set<int>? monthWeeks,
  }) => SharedRecurrenceValue(
    recurrence: recurrence ?? this.recurrence,
    end: clearEnd ? null : (end ?? this.end),
    weekdays: weekdays ?? this.weekdays,
    monthDays: monthDays ?? this.monthDays,
    monthEnd: monthEnd ?? this.monthEnd,
    monthWeeks:
        monthWeeks ?? (monthWeek == null ? this.monthWeeks : <int>{monthWeek}),
  );
}

/// The single recurrence input for Schedule and Reminder editors.
class SharedRecurrenceEditor extends StatelessWidget {
  const SharedRecurrenceEditor({
    super.key,
    required this.startDate,
    required this.value,
    required this.onChanged,
  });

  final DateTime startDate;
  final SharedRecurrenceValue value;
  final ValueChanged<SharedRecurrenceValue> onChanged;

  static const _newChoices = <ReminderRecurrence>[
    ReminderRecurrence.none,
    ReminderRecurrence.daily,
    ReminderRecurrence.weekdays,
    ReminderRecurrence.weekends,
    ReminderRecurrence.weekly,
    ReminderRecurrence.monthlyWeekday,
    ReminderRecurrence.monthly,
    ReminderRecurrence.yearly,
    ReminderRecurrence.customWeekdays,
    ReminderRecurrence.customMonthDays,
  ];

  List<ReminderRecurrence> get _choices =>
      value.recurrence == ReminderRecurrence.biweekly
      ? [
          ReminderRecurrence.biweekly,
          ..._newChoices.where(
            (rule) => rule != ReminderRecurrence.monthlyWeekday,
          ),
        ]
      : _newChoices;

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value.end ?? startDate,
      firstDate: startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(value.copyWith(end: DateUtils.dateOnly(picked)));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<ReminderRecurrence>(
        initialValue: value.recurrence,
        decoration: const InputDecoration(labelText: '繰り返し'),
        items: _choices
            .map(
              (rule) => DropdownMenuItem(
                value: rule,
                child: Text(recurrenceLabel(rule)),
              ),
            )
            .toList(),
        onChanged: (rule) {
          if (rule != null) onChanged(value.copyWith(recurrence: rule));
        },
      ).inputFeedback(),
      if (value.recurrence != ReminderRecurrence.none) ...[
        const SizedBox(height: 12),
        Text('繰り返しの設定', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _settings(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('終了日を指定する'),
          value: value.end != null,
          onChanged: (enabled) => onChanged(
            enabled
                ? value.copyWith(end: startDate)
                : value.copyWith(clearEnd: true),
          ),
        ).inputFeedback(),
        if (value.end != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '繰り返しの終了  ${value.end!.year}/${value.end!.month}/${value.end!.day}',
            ),
            onTap: () => _pickEnd(context),
          ).inputFeedback(),
      ],
    ],
  );

  Widget _settings() {
    final summary = Text(recurrenceSettingsSummary(startDate, value));
    if (value.recurrence == ReminderRecurrence.monthlyWeekday) {
      final selected = value.monthWeeks.isEmpty
          ? <int>{((startDate.day - 1) ~/ 7) + 1}
          : value.monthWeeks;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary,
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(5, (index) {
              final week = index + 1;
              return FilterChip(
                label: Text('第$week'),
                selected: selected.contains(week),
                onSelected: (enabled) {
                  final next = Set<int>.of(selected);
                  if (enabled) {
                    next.add(week);
                  } else if (next.length > 1) {
                    next.remove(week);
                  }
                  onChanged(value.copyWith(monthWeeks: next));
                },
              ).inputFeedback();
            }),
          ),
        ],
      );
    }
    if (value.recurrence == ReminderRecurrence.customWeekdays) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary,
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              final next = Set<int>.of(value.weekdays);
              return FilterChip(
                label: Text(_weekdayLabel(weekday)),
                selected: next.contains(weekday),
                onSelected: (selected) {
                  selected ? next.add(weekday) : next.remove(weekday);
                  onChanged(value.copyWith(weekdays: next));
                },
              ).inputFeedback();
            }),
          ),
        ],
      );
    }
    if (value.recurrence == ReminderRecurrence.customMonthDays) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary,
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ...List.generate(31, (index) {
                final day = index + 1;
                final next = Set<int>.of(value.monthDays);
                return FilterChip(
                  label: Text('$day'),
                  selected: next.contains(day),
                  onSelected: (selected) {
                    selected ? next.add(day) : next.remove(day);
                    onChanged(value.copyWith(monthDays: next));
                  },
                ).inputFeedback();
              }),
              FilterChip(
                label: const Text('月末'),
                selected: value.monthEnd,
                onSelected: (selected) =>
                    onChanged(value.copyWith(monthEnd: selected)),
              ).inputFeedback(),
            ],
          ),
        ],
      );
    }
    return summary;
  }
}

String recurrenceLabel(ReminderRecurrence value) => switch (value) {
  ReminderRecurrence.none => 'なし',
  ReminderRecurrence.daily => '毎日',
  ReminderRecurrence.weekdays => '平日',
  ReminderRecurrence.weekends => '週末',
  ReminderRecurrence.weekly => '毎週',
  ReminderRecurrence.biweekly => '隔週',
  ReminderRecurrence.monthlyWeekday => '隔週',
  ReminderRecurrence.monthly => '毎月',
  ReminderRecurrence.yearly => '毎年',
  ReminderRecurrence.customWeekdays => '曜日指定',
  ReminderRecurrence.customMonthDays => '日付指定',
};

/// The effective user-facing rule, shared by Schedule and Reminder editors.
/// It is intentionally derived from the current start date so changing that
/// date cannot leave a stale weekly, monthly, or yearly description behind.
String recurrenceSettingsSummary(
  DateTime startDate,
  SharedRecurrenceValue value,
) {
  final weekday = _weekdayLabel(startDate.weekday);
  final weeks = value.monthWeeks.isEmpty
      ? <int>{((startDate.day - 1) ~/ 7) + 1}
      : value.monthWeeks;
  switch (value.recurrence) {
    case ReminderRecurrence.none:
      return '';
    case ReminderRecurrence.daily:
      return '開始日から毎日';
    case ReminderRecurrence.weekdays:
      return '月・火・水・木・金';
    case ReminderRecurrence.weekends:
      return '土・日';
    case ReminderRecurrence.weekly:
      return weekday;
    case ReminderRecurrence.biweekly:
      return '14日ごと・$weekday';
    case ReminderRecurrence.monthlyWeekday:
      return '${(weeks.toList()..sort()).map((week) => '第$week').join('・')}・$weekday';
    case ReminderRecurrence.monthly:
      return '${startDate.day}日';
    case ReminderRecurrence.yearly:
      return '${startDate.month}月${startDate.day}日';
    case ReminderRecurrence.customWeekdays:
      return value.weekdays.isEmpty
          ? '曜日を選択してください'
          : (value.weekdays.toList()..sort()).map(_weekdayLabel).join('・');
    case ReminderRecurrence.customMonthDays:
      final details = <String>[
        ...(value.monthDays.toList()..sort()).map((day) => '$day日'),
        if (value.monthEnd) '月末',
      ];
      return details.isEmpty ? '日付を選択してください' : details.join('・');
  }
}

String _weekdayLabel(int weekday) =>
    const ['月', '火', '水', '木', '金', '土', '日'][weekday - 1];
