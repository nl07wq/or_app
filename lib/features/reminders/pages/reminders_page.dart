import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../repositories/app_repository_container.dart';
import '../../schedule/models/schedule_plan_revision.dart';
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
                empty: '今日のReminderはありません',
                onToggle: _toggle,
              ),
              _OccurrenceList(
                values: _all,
                empty: '今後のReminderはありません',
                onToggle: _toggle,
              ),
              _DefinitionList(values: _recurring, onEdit: _edit),
              _OccurrenceList(
                values: _completed,
                empty: '完了済みReminderはありません',
                onToggle: _toggle,
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
  });
  final List<ReminderOccurrence> values;
  final String empty;
  final ValueChanged<ReminderOccurrence> onToggle;
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
              child: Center(child: Text('繰り返しReminderはありません')),
            ),
          ]
        : values
              .map(
                (value) => ListTile(
                  title: Text(value.title),
                  subtitle: Text(value.recurrence.name.toUpperCase()),
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
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _title.text = initial.title;
    _note.text = initial.note ?? '';
    _date = DateTime.parse(initial.startDate);
    _timed = !initial.allDay;
    final parts = initial.time?.split(':');
    if (parts?.length == 2) {
      _time = TimeOfDay(
        hour: int.tryParse(parts![0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    _recurrence = initial.recurrence;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Wrap(
      children: [
        const Text('REMINDER'),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'TITLE'),
        ),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'NOTE'),
        ),
        ListTile(
          title: Text('DATE  ${_date.year}/${_date.month}/${_date.day}'),
          onTap: () async {
            final value = await showDatePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDate: _date,
            );
            if (value != null) setState(() => _date = value);
          },
        ),
        SwitchListTile(
          title: const Text('TIME'),
          value: _timed,
          onChanged: (value) => setState(() => _timed = value),
        ),
        if (_timed)
          ListTile(
            title: Text('TIME  ${_time.format(context)}'),
            onTap: () async {
              final value = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (value != null) setState(() => _time = value);
            },
          ),
        DropdownButtonFormField<ReminderRecurrence>(
          value: _recurrence,
          decoration: const InputDecoration(labelText: 'RECURRENCE'),
          items: ReminderRecurrence.values
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text(value.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _recurrence = value!),
        ),
        const SizedBox(height: 12),
        OperationButton(
          text: 'SAVE REMINDER',
          icon: Icons.check,
          onPressed: _title.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _ReminderDraft(
                    title: _title.text.trim(),
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                    date: _date,
                    timed: _timed,
                    time: _time,
                    recurrence: _recurrence,
                  ),
                ),
          role: OperationActionRole.primary,
        ),
      ],
    ),
  );
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
