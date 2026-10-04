import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../repositories/app_repository_container.dart';
import '../../schedule/models/schedule_plan_revision.dart';
import '../../schedule/widgets/shared_time_picker.dart';
import '../models/reminder_definition.dart';
import '../models/reminder_occurrence.dart';
import '../services/legacy_reminder_migration_service.dart';
import '../services/reminder_occurrence_service.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  List<ReminderOccurrence> _today = const [];
  List<ReminderOccurrence> _all = const [];
  List<ReminderOccurrence> _completed = const [];
  List<ReminderDefinition> _recurring = const [];
  bool _loading = true;

  ReminderOccurrenceService get _occurrences =>
      ReminderOccurrenceService(AppRepositoryRegistry.container.reminders);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final container = AppRepositoryRegistry.container;
    await LegacyReminderMigrationService(
      container.schedules,
      container.reminders,
    ).migrate();
    final today = DateUtils.dateOnly(DateTime.now());
    final future = today.add(const Duration(days: 90));
    final pending = await _occurrences.inRange(
      DateTimeRange(start: today, end: future),
      includeCompleted: false,
    );
    final definitions = await container.reminders.findDefinitions();
    final completed = await _occurrences.completed();
    if (!mounted) return;
    setState(() {
      _today = pending
          .where((value) => value.localDate == _dateKey(today))
          .toList();
      _all = pending;
      _completed = completed;
      _recurring = definitions
          .where((value) => value.recurrence != ReminderRecurrence.none)
          .toList();
      _loading = false;
    });
  }

  Future<void> _toggle(ReminderOccurrence value) async {
    if (value.status == ReminderOccurrenceStatus.completed) {
      await _occurrences.restore(value);
    } else {
      await _occurrences.complete(value, DateTime.now());
    }
    notifySchedulePlanChanged();
    await _load();
  }

  Future<void> _create() async {
    final draft = await showModalBottomSheet<_ReminderDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReminderEditor(),
    );
    if (draft == null) return;
    final now = DateTime.now().toUtc();
    await AppRepositoryRegistry.container.reminders.saveDefinition(
      ReminderDefinition(
        id: 'reminder-${now.microsecondsSinceEpoch}',
        title: draft.title,
        note: draft.note,
        startDate: _dateKey(draft.date),
        allDay: !draft.timed,
        time: draft.timed ? _timeKey(draft.time) : null,
        recurrence: draft.recurrence,
        recurrenceEnd: draft.end == null ? null : _dateKey(draft.end!),
        weekdays: draft.weekdays,
        monthDays: draft.monthDays,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    notifySchedulePlanChanged();
    await _load();
  }

  Future<void> _edit(ReminderDefinition previous) async {
    final draft = await showModalBottomSheet<_ReminderDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderEditor(initial: previous),
    );
    if (draft == null) return;
    final boundary = DateTime.now().toUtc();
    final repository = AppRepositoryRegistry.container.reminders;
    await repository.saveDefinition(
      ReminderDefinition(
        id: previous.id,
        title: previous.title,
        note: previous.note,
        startDate: previous.startDate,
        allDay: previous.allDay,
        time: previous.time,
        recurrence: previous.recurrence,
        recurrenceEnd: previous.recurrenceEnd,
        weekdays: previous.weekdays,
        monthDays: previous.monthDays,
        active: false,
        createdAt: previous.createdAt,
        updatedAt: boundary,
        effectiveFrom: previous.effectiveFrom,
        retiredAt: boundary,
      ),
    );
    await repository.saveDefinition(
      ReminderDefinition(
        id: '${previous.id}-r${boundary.microsecondsSinceEpoch}',
        title: draft.title,
        note: draft.note,
        startDate: _dateKey(draft.date),
        allDay: !draft.timed,
        time: draft.timed ? _timeKey(draft.time) : null,
        recurrence: draft.recurrence,
        recurrenceEnd: draft.end == null ? null : _dateKey(draft.end!),
        weekdays: draft.weekdays,
        monthDays: draft.monthDays,
        active: true,
        createdAt: boundary,
        updatedAt: boundary,
        effectiveFrom: boundary,
      ),
    );
    notifySchedulePlanChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('REMINDERS'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        tabs: const [
          Tab(text: 'TODAY'),
          Tab(text: 'ALL'),
          Tab(text: 'RECURRING'),
          Tab(text: 'COMPLETED'),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _create,
      child: const Icon(Icons.add),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabs,
            children: [
              _OccurrenceList(
                values: _today,
                empty: '今日のREMINDERはありません',
                onToggle: _toggle,
                onEdit: _edit,
              ),
              _OccurrenceList(
                values: _all,
                empty: '今後のREMINDERはありません',
                onToggle: _toggle,
                onEdit: _edit,
              ),
              _DefinitionList(values: _recurring, onEdit: _edit),
              _OccurrenceList(
                values: _completed,
                empty: '完了済みREMINDERはありません',
                onToggle: _toggle,
                onEdit: _edit,
              ),
            ],
          ),
  );
}

class _OccurrenceList extends StatelessWidget {
  const _OccurrenceList({
    required this.values,
    required this.empty,
    required this.onToggle,
    required this.onEdit,
  });
  final List<ReminderOccurrence> values;
  final String empty;
  final ValueChanged<ReminderOccurrence> onToggle;
  final ValueChanged<ReminderDefinition> onEdit;
  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.cardPadding,
    children: values.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(child: Text(empty)),
            ),
          ]
        : values
              .map(
                (value) => ListTile(
                  onTap: () => onEdit(value.definition),
                  leading: Icon(
                    value.status == ReminderOccurrenceStatus.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(value.definition.title),
                  subtitle: Text(
                    '${value.localDate}${value.definition.time == null ? '  終日' : '  ${value.definition.time}'}',
                  ),
                  trailing: TextButton(
                    onPressed: () => onToggle(value),
                    child: Text(
                      value.status == ReminderOccurrenceStatus.completed
                          ? '未完了に戻す'
                          : '完了',
                    ),
                  ),
                ),
              )
              .toList(),
  );
}

class _DefinitionList extends StatelessWidget {
  const _DefinitionList({required this.values, required this.onEdit});
  final List<ReminderDefinition> values;
  final ValueChanged<ReminderDefinition> onEdit;
  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.cardPadding,
    children: values.isEmpty
        ? const [
            Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('繰り返しREMINDERはありません')),
            ),
          ]
        : values
              .map(
                (value) => ListTile(
                  title: Text(value.title),
                  subtitle: Text(_recurrenceLabel(value.recurrence)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => onEdit(value),
                  ),
                ),
              )
              .toList(),
  );
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({this.initial});
  final ReminderDefinition? initial;
  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _timed = false;
  ReminderRecurrence _recurrence = ReminderRecurrence.none;
  DateTime? _end;
  final Set<int> _weekdays = <int>{};
  final Set<int> _monthDays = <int>{};
  String? _error;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _title.text = initial.title;
    _note.text = initial.note ?? '';
    _date = DateTime.parse(initial.startDate);
    _timed = !initial.allDay;
    _time = timeOfDayFromClock(initial.time);
    _recurrence = initial.recurrence;
    _end = initial.recurrenceEnd == null
        ? null
        : DateTime.tryParse(initial.recurrenceEnd!);
    _weekdays.addAll(initial.weekdays);
    _monthDays.addAll(initial.monthDays);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final weekdays = _effectiveWeekdays;
    final monthDays = _effectiveMonthDays;
    if (title.isEmpty) {
      setState(() => _error = 'タイトルを入力してください。');
      return;
    }
    if (_end != null && DateUtils.dateOnly(_end!).isBefore(_date)) {
      setState(() => _error = '終了日は開始日以降にしてください。');
      return;
    }
    if (_recurrence == ReminderRecurrence.customWeekdays &&
        weekdays.isEmpty) {
      setState(() => _error = '曜日を1つ以上選択してください。');
      return;
    }
    if (_recurrence == ReminderRecurrence.customMonthDays &&
        monthDays.isEmpty) {
      setState(() => _error = '日付を1つ以上選択してください。');
      return;
    }
    Navigator.pop(
      context,
      _ReminderDraft(
        title: title,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        date: _date,
        timed: _timed,
        time: _time,
        recurrence: _recurrence,
        end: _end,
        weekdays: weekdays,
        monthDays: monthDays,
      ),
    );
  }

  List<int> get _effectiveWeekdays => switch (_recurrence) {
    ReminderRecurrence.weekly || ReminderRecurrence.biweekly =>
      _weekdays.isEmpty ? [_date.weekday] : _weekdays.toList()..sort(),
    ReminderRecurrence.customWeekdays => _weekdays.toList()..sort(),
    _ => const [],
  };

  List<int> get _effectiveMonthDays => switch (_recurrence) {
    ReminderRecurrence.monthly =>
      _monthDays.isEmpty ? [_date.day] : _monthDays.toList()..sort(),
    ReminderRecurrence.customMonthDays => _monthDays.toList()..sort(),
    _ => const [],
  };

  Future<void> _pickDate({required bool end}) async {
    final value = await showDatePicker(
      context: context,
      firstDate: _date,
      lastDate: DateTime(2100),
      initialDate: end ? (_end ?? _date) : _date,
    );
    if (value != null) setState(() => end ? _end = value : _date = value);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Text(widget.initial == null ? 'REMINDER' : 'REMINDERを編集'),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'タイトル'),
          onChanged: (_) => setState(() => _error = null),
        ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'メモ'),
        ),
        ListTile(
          title: Text('日付  ${_date.year}/${_date.month}/${_date.day}'),
          onTap: () => _pickDate(end: false),
        ),
        SwitchListTile(
          title: const Text('時刻'),
          value: _timed,
          onChanged: (value) => setState(() => _timed = value),
        ),
        if (_timed)
          ListTile(
            title: Text('時刻  ${_time.format(context)}'),
            onTap: () async {
              final value = await showSharedTimePicker(context, initialTime: _time);
              if (value != null) setState(() => _time = value);
            },
          ),
        DropdownButtonFormField<ReminderRecurrence>(
          initialValue: _recurrence,
          decoration: const InputDecoration(labelText: '繰り返し'),
          items: ReminderRecurrence.values
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text(_recurrenceLabel(value))),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _recurrence = value!;
            _error = null;
          }),
        ),
        if (_recurrence != ReminderRecurrence.none) ...[
          const SizedBox(height: 12),
          Text('繰り返しの設定', style: Theme.of(context).textTheme.titleSmall),
          _recurrenceSettings(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('終了日を指定する'),
            value: _end != null,
            onChanged: (value) => setState(() => _end = value ? _date : null),
          ),
          if (_end != null)
            ListTile(
              title: Text('繰り返しの終了  ${_end!.year}/${_end!.month}/${_end!.day}'),
              onTap: () => _pickDate(end: true),
            ),
        ],
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
        OperationButton(
          text: '保存',
          icon: Icons.check,
          onPressed: _save,
          role: OperationActionRole.primary,
        ),
      ],
      ),
    ),
  );

  Widget _recurrenceSettings() {
    final weekdayRule = _recurrence == ReminderRecurrence.weekly ||
        _recurrence == ReminderRecurrence.biweekly ||
        _recurrence == ReminderRecurrence.customWeekdays;
    final monthRule = _recurrence == ReminderRecurrence.monthly ||
        _recurrence == ReminderRecurrence.customMonthDays;
    if (weekdayRule) {
      return Wrap(
        spacing: 6,
        children: List.generate(7, (index) {
          final day = index + 1;
          final selected = (_weekdays.isEmpty &&
                  _recurrence != ReminderRecurrence.customWeekdays
              ? _date.weekday == day
              : _weekdays.contains(day));
          return FilterChip(
            label: Text(_weekdayLabel(day)),
            selected: selected,
            onSelected: (value) => setState(() {
              if (value) {
                _weekdays.add(day);
              } else {
                _weekdays.remove(day);
              }
              _error = null;
            }),
          );
        }),
      );
    }
    if (monthRule) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(31, (index) {
          final day = index + 1;
          final selected = (_monthDays.isEmpty &&
                  _recurrence != ReminderRecurrence.customMonthDays
              ? _date.day == day
              : _monthDays.contains(day));
          return FilterChip(
            label: Text('$day'),
            selected: selected,
            onSelected: (value) => setState(() {
              if (value) {
                _monthDays.add(day);
              } else {
                _monthDays.remove(day);
              }
              _error = null;
            }),
          );
        }),
      );
    }
    return Text(_recurrenceDescription(_recurrence, _date));
  }
}

class _ReminderDraft {
  const _ReminderDraft({
    required this.title,
    required this.note,
    required this.date,
    required this.timed,
    required this.time,
    required this.recurrence,
    this.end,
    this.weekdays = const [],
    this.monthDays = const [],
  });
  final String title;
  final String? note;
  final DateTime date;
  final bool timed;
  final TimeOfDay time;
  final ReminderRecurrence recurrence;
  final DateTime? end;
  final List<int> weekdays;
  final List<int> monthDays;
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _timeKey(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _recurrenceLabel(ReminderRecurrence value) => switch (value) {
  ReminderRecurrence.none => 'なし',
  ReminderRecurrence.daily => '毎日',
  ReminderRecurrence.weekdays => '平日',
  ReminderRecurrence.weekends => '週末',
  ReminderRecurrence.weekly => '毎週',
  ReminderRecurrence.biweekly => '隔週',
  ReminderRecurrence.monthly => '毎月',
  ReminderRecurrence.yearly => '毎年',
  ReminderRecurrence.customWeekdays => '曜日指定',
  ReminderRecurrence.customMonthDays => '日付指定',
};

String _weekdayLabel(int day) => const ['月', '火', '水', '木', '金', '土', '日'][day - 1];

String _recurrenceDescription(ReminderRecurrence recurrence, DateTime date) =>
    switch (recurrence) {
      ReminderRecurrence.daily => '開始日から毎日',
      ReminderRecurrence.weekdays => '月〜金',
      ReminderRecurrence.weekends => '土・日',
      ReminderRecurrence.yearly => '毎年 ${date.month}月${date.day}日',
      _ => '',
    };
