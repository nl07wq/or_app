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
    final result = await showDialog<ScheduleRecord>(
      context: context,
      builder: (_) => _ScheduleEditor(record: record, initialDate: _selected),
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
                SectionHeader(
                  icon: Icons.event_note,
                  title: 'SCHEDULE — $_selectedKey',
                ),
                AppSpacing.gapSM,
                if (_selectedSchedules.isEmpty)
                  const OperationCard(child: Text('NO SCHEDULES')),
                for (final record in _selectedSchedules)
                  OperationCard(
                    selectable: true,
                    onTap: () => _openEditor(record),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(record.title),
                              Text(
                                '${record.type.name.toUpperCase()}  ${_timeLabel(record)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
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
                  text: 'ADD SCHEDULE',
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
                        const Icon(Icons.circle, size: 6),
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
  late ScheduleType _type = widget.record?.type ?? ScheduleType.personal;
  late DateTime _date =
      DateTime.tryParse(widget.record?.localDate ?? '') ?? widget.initialDate;
  late final _title = TextEditingController(text: widget.record?.title ?? '');
  late final _start = TextEditingController(
    text: widget.record?.startTime ?? '',
  );
  late final _end = TextEditingController(text: widget.record?.endTime ?? '');
  late final _break = TextEditingController(
    text: widget.record?.breakDuration ?? '',
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.record == null ? 'ADD SCHEDULE' : 'EDIT SCHEDULE'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          OperationTextField(controller: _start, label: 'START (HH:mm)'),
          OperationTextField(controller: _end, label: 'END (HH:mm)'),
          OperationTextField(controller: _break, label: 'BREAK (HH:mm)'),
          OperationTextField(controller: _memo, label: 'MEMO', maxLines: 3),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      TextButton(onPressed: _save, child: const Text('SAVE')),
    ],
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
        startTime: _start.text.trim().isEmpty ? null : _start.text.trim(),
        endTime: _end.text.trim().isEmpty ? null : _end.text.trim(),
        breakDuration: _break.text.trim().isEmpty ? null : _break.text.trim(),
        memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
        createdAt: widget.record?.createdAt ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
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
