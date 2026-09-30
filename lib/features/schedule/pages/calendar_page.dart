import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../models/schedule_record.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.initialDate});
  final DateTime? initialDate;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selected = _dateOnly(widget.initialDate ?? DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);
  Map<String, List<ScheduleRecord>> _byDate = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final values = await AppRepositoryRegistry.container.schedules.findForMonth(
      _month,
    );
    if (!mounted) return;
    setState(() {
      _byDate = {
        for (final value in values)
          value.localDate: [
            ...(values.where(
              (candidate) => candidate.localDate == value.localDate,
            )),
          ],
      };
      _loading = false;
    });
  }

  String get _selectedKey => _key(_selected);
  List<ScheduleRecord> get _selectedSchedules =>
      _byDate[_selectedKey] ?? const [];

  Future<void> _openEditor([ScheduleRecord? record]) async {
    final result = await Navigator.of(context).push<ScheduleRecord>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ScheduleEditor(record: record, initialDate: _selected),
      ),
    );
    if (result == null) {
      return;
    }
    try {
      await AppRepositoryRegistry.container.schedules.save(result);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _delete(ScheduleRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE SCHEDULE'),
        content: Text('Delete ${record.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppRepositoryRegistry.container.schedules.delete(record.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CALENDAR'), centerTitle: true),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthGrid(
                  month: _month,
                  selected: _selected,
                  byDate: _byDate,
                  onPrevious: () {
                    setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    );
                    _load();
                  },
                  onNext: () {
                    setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    );
                    _load();
                  },
                  onToday: () {
                    final now = _dateOnly(DateTime.now());
                    setState(() {
                      _selected = now;
                      _month = DateTime(now.year, now.month);
                    });
                    _load();
                  },
                  onSelect: (date) => setState(() => _selected = date),
                ),
                AppSpacing.gapLG,
                SectionHeader(icon: Icons.timeline, title: "TODAY'S TIMELINE"),
                Text(
                  '${_selected.month.toString().padLeft(2, '0')} / ${_selected.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AppSpacing.gapSM,
                if (_selectedSchedules.isEmpty)
                  const OperationCard(child: Text('NO PLANNED ENTRIES')),
                for (final record in _selectedSchedules)
                  OperationCard(
                    selectable: true,
                    onTap: () => _openEditor(record),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: Text(
                            record.allDay
                                ? 'ALL DAY'
                                : record.startTime ?? 'ANYTIME',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 42,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(record.title),
                              Text(
                                '${record.kind.name.toUpperCase()} · ${record.type.name.toUpperCase()}  ${_timeLabel(record)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (record.kind == ScheduleEntryKind.reminder)
                          IconButton(
                            icon: Icon(
                              record.completed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                            ),
                            onPressed: () => _toggleReminder(record),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(record),
                        ),
                      ],
                    ),
                  ),
                AppSpacing.gapMD,
                OperationButton(
                  text: 'ADD ENTRY',
                  icon: Icons.add,
                  onPressed: () => _openEditor(),
                  role: OperationActionRole.primary,
                ),
              ],
            ),
          ),
  );

  String _timeLabel(ScheduleRecord record) => record.startTime == null
      ? ''
      : '${record.startTime}–${record.endTime ?? ''}${record.breakDuration == null ? '' : '  BREAK ${record.breakDuration}'}';

  Future<void> _toggleReminder(ScheduleRecord record) async {
    await AppRepositoryRegistry.container.schedules.save(
      ScheduleRecord(
        id: record.id,
        localDate: record.localDate,
        type: record.type,
        title: record.title,
        kind: record.kind,
        allDay: record.allDay,
        startTime: record.startTime,
        endTime: record.endTime,
        breakDuration: record.breakDuration,
        memo: record.memo,
        completed: !record.completed,
        createdAt: record.createdAt,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await _load();
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.byDate,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onSelect,
  });
  final DateTime month;
  final DateTime selected;
  final Map<String, List<ScheduleRecord>> byDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7;
    return OperationCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${month.year}.${month.month.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          TextButton(onPressed: onToday, child: const Text('TODAY')),
          Row(
            children: [
              for (final label in [
                'SUN',
                'MON',
                'TUE',
                'WED',
                'THU',
                'FRI',
                'SAT',
              ])
                Expanded(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offset + days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, index) {
              if (index < offset) return const SizedBox();
              final date = DateTime(
                month.year,
                month.month,
                index - offset + 1,
              );
              final schedules = byDate[_key(date)] ?? const [];
              return InkWell(
                onTap: () => onSelect(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: _sameDay(date, selected)
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${date.day}'),
                      if (schedules.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (schedules.any(
                              (value) =>
                                  value.kind == ScheduleEntryKind.schedule,
                            ))
                              const Icon(Icons.remove, size: 12),
                            if (schedules.any(
                              (value) =>
                                  value.kind == ScheduleEntryKind.reminder,
                            ))
                              const Icon(Icons.circle_outlined, size: 8),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({this.record, required this.initialDate});
  final ScheduleRecord? record;
  final DateTime initialDate;
  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late ScheduleEntryKind _kind =
      widget.record?.kind ?? ScheduleEntryKind.schedule;
  late ScheduleType _type = widget.record?.type ?? ScheduleType.personal;
  late bool _allDay = widget.record?.allDay ?? false;
  late bool _completed = widget.record?.completed ?? false;
  late DateTime _date =
      DateTime.tryParse(widget.record?.localDate ?? '') ?? widget.initialDate;
  late final _title = TextEditingController(text: widget.record?.title ?? '');
  late final _start = TextEditingController(
    text: widget.record?.startTime ?? '',
  );
  late final _end = TextEditingController(text: widget.record?.endTime ?? '');
  late final _break = TextEditingController(
    text:
        widget.record?.breakDuration ??
        (_kind == ScheduleEntryKind.schedule && _type == ScheduleType.work
            ? '01:00'
            : ''),
  );
  late final _memo = TextEditingController(text: widget.record?.memo ?? '');
  @override
  void dispose() {
    _title.dispose();
    _start.dispose();
    _end.dispose();
    _break.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.record == null ? 'NEW ENTRY' : 'EDIT ENTRY'),
      actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ScheduleEntryKind>(
              segments: const [
                ButtonSegment(
                  value: ScheduleEntryKind.schedule,
                  label: Text('SCHEDULE'),
                ),
                ButtonSegment(
                  value: ScheduleEntryKind.reminder,
                  label: Text('REMINDER'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (value) =>
                  setState(() => _kind = value.single),
            ),
            DropdownButtonFormField<ScheduleType>(
              initialValue: _type,
              items: ScheduleType.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            OperationTextField(controller: _title, label: 'TITLE'),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Text('DATE ${_key(_date)}'),
            ),
            if (_kind == ScheduleEntryKind.schedule)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ALL DAY'),
                value: _allDay,
                onChanged: (value) => setState(() => _allDay = value),
              ),
            if (!_allDay)
              _TimeControl(
                label: _kind == ScheduleEntryKind.reminder
                    ? 'TIME · OPTIONAL'
                    : 'START',
                controller: _start,
              ),
            if (_kind == ScheduleEntryKind.schedule && !_allDay)
              _TimeControl(label: 'END', controller: _end),
            if (_kind == ScheduleEntryKind.schedule &&
                _type == ScheduleType.work &&
                !_allDay)
              OperationTextField(controller: _break, label: 'BREAK (HH:mm)'),
            if (_kind == ScheduleEntryKind.reminder)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('COMPLETED'),
                value: _completed,
                onChanged: (value) =>
                    setState(() => _completed = value ?? false),
              ),
            OperationTextField(controller: _memo, label: 'MEMO', maxLines: 3),
            AppSpacing.gapLG,
            OperationButton(
              text: 'SAVE ENTRY',
              icon: Icons.check,
              role: OperationActionRole.primary,
              onPressed: _save,
            ),
          ],
        ),
      ),
    ),
  );

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      ScheduleRecord(
        id:
            widget.record?.id ??
            'schedule_${DateTime.now().microsecondsSinceEpoch}',
        localDate: _key(_date),
        type: _type,
        title: _title.text,
        kind: _kind,
        allDay: _kind == ScheduleEntryKind.schedule && _allDay,
        startTime: _allDay || _start.text.trim().isEmpty
            ? null
            : _start.text.trim(),
        endTime:
            _kind == ScheduleEntryKind.schedule &&
                !_allDay &&
                _end.text.trim().isNotEmpty
            ? _end.text.trim()
            : null,
        breakDuration:
            _kind == ScheduleEntryKind.schedule &&
                _type == ScheduleType.work &&
                !_allDay &&
                _break.text.trim().isNotEmpty
            ? _break.text.trim()
            : null,
        memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
        completed: _kind == ScheduleEntryKind.reminder && _completed,
        createdAt: widget.record?.createdAt ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

class _TimeControl extends StatelessWidget {
  const _TimeControl({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(controller.text.isEmpty ? 'NOT SET' : controller.text),
    trailing: const Icon(Icons.access_time),
    onTap: () async {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ClockDial(initial: controller.text),
      );
      if (result != null) controller.text = result;
    },
  );
}

class _ClockDial extends StatefulWidget {
  const _ClockDial({required this.initial});
  final String initial;
  @override
  State<_ClockDial> createState() => _ClockDialState();
}

class _ClockDialState extends State<_ClockDial> {
  late int _hour = int.tryParse(widget.initial.split(':').first) ?? 0;
  late int _minute = widget.initial.contains(':')
      ? int.tryParse(widget.initial.split(':').last) ?? 0
      : 0;
  bool _minutes = false;

  @override
  Widget build(BuildContext context) {
    final values = _minutes
        ? List.generate(12, (i) => i * 5)
        : List.generate(24, (i) => i);
    return SafeArea(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_hour.toString().padLeft(2, '0')} : ${_minute.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(_minutes ? 'SELECT MINUTE' : 'SELECT HOUR'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 6,
              children: [
                for (final value in values)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_minutes) {
                          _minute = value;
                        } else {
                          _hour = value;
                          _minutes = true;
                        }
                      });
                    },
                    child: Text(value.toString().padLeft(2, '0')),
                  ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _minutes = false),
                  child: const Text('HOUR'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                  ),
                  child: const Text('DONE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String _key(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
