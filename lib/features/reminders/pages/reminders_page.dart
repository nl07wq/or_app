import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/holographic_ambient_background.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../repositories/app_repository_container.dart';
import '../../schedule/models/schedule_plan_revision.dart';
import '../../schedule/widgets/shared_time_picker.dart';
import '../../schedule/widgets/shared_date_time_recurrence_editor.dart';
import '../../notifications/models/notification_configuration.dart';
import '../../notifications/services/notification_profile_controller.dart';
import '../../notifications/widgets/shared_notification_editor.dart';
import '../models/reminder_definition.dart';
import '../models/reminder_occurrence.dart';
import '../services/legacy_reminder_migration_service.dart';
import '../services/reminder_occurrence_service.dart';

enum _DeleteChoice { single, once, future }

typedef _OccurrenceAction = Future<void> Function(ReminderOccurrence value);
typedef _DefinitionAction = Future<void> Function(ReminderDefinition value);

const reminderHudCompletionUsesOuterPolygon = false;
const reminderCompletionVisibleDiameter = 14.0;
const reminderCompletionIconSize = holographicTimelineNodeIconSize;
const reminderCompletionTouchTarget = 48.0;
// Timeline geometry is measured from the rendered marker positions by the
// owning filtered list; it is deliberately not a per-row static fragment.
const reminderCircuitRailIsStatic = false;
const reminderCircuitRailWidth = holographicTimelineRailWidth;

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
  final Map<int, Map<String, ReminderOccurrence>> _retainedCompletedByTab =
      <int, Map<String, ReminderOccurrence>>{};
  bool _loading = true;
  int _loadGeneration = 0;

  ReminderOccurrenceService get _occurrences =>
      ReminderOccurrenceService(AppRepositoryRegistry.container.reminders);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_clearTransientCompleteRetention);
    schedulePlanRevisionNotifier.addListener(_handlePlanRevision);
    _load();
  }

  @override
  void dispose() {
    schedulePlanRevisionNotifier.removeListener(_handlePlanRevision);
    _tabs.removeListener(_clearTransientCompleteRetention);
    _tabs.dispose();
    super.dispose();
  }

  void _handlePlanRevision() {
    if (!mounted) return;
    unawaited(_load(showLoading: false));
  }

  void _clearTransientCompleteRetention() {
    if (_retainedCompletedByTab.isEmpty) return;
    _retainedCompletedByTab.clear();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    final generation = ++_loadGeneration;
    if (showLoading) setState(() => _loading = true);
    final container = AppRepositoryRegistry.container;
    await LegacyReminderMigrationService(
      container.schedules,
      container.reminders,
    ).migrate();
    final today = DateUtils.dateOnly(DateTime.now());
    final todayPending = await _occurrences.inRange(
      DateTimeRange(start: today, end: today),
      includeCompleted: false,
    );
    final allCompact = await _occurrences.nextPendingBySlot(today);
    final definitions = await container.reminders.findDefinitions();
    final completed = await _occurrences.completed();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _today = _withTransientRetained(todayPending, 0);
      _all = _withTransientRetained(allCompact, 1);
      _completed = completed;
      _recurring = definitions
          .where((value) => _isCurrentRecurringDefinition(value, today))
          .toList();
      _loading = false;
    });
    unawaited(
      NotificationProfileController.instance.reconcileFromRepositories(),
    );
  }

  List<ReminderOccurrence> _withTransientRetained(
    List<ReminderOccurrence> values,
    int tabIndex,
  ) {
    final retained = _retainedCompletedByTab[tabIndex];
    if (retained == null || retained.isEmpty) return values;
    final byId = <String, ReminderOccurrence>{
      for (final value in values) value.id: value,
      ...retained,
    };
    return byId.values.toList()
      ..sort((first, second) => first.localDate.compareTo(second.localDate));
  }

  Future<void> _toggle(ReminderOccurrence value, {int? retentionTab}) async {
    if (value.status == ReminderOccurrenceStatus.completed) {
      await _occurrences.restore(value);
      if (retentionTab != null) {
        _retainedCompletedByTab[retentionTab]?.remove(value.id);
      }
    } else {
      await _occurrences.complete(value, DateTime.now());
      if (retentionTab != null) {
        _retainedCompletedByTab.putIfAbsent(
          retentionTab,
          () => <String, ReminderOccurrence>{},
        )[value.id] = ReminderOccurrence(
          definition: value.definition,
          localDate: value.localDate,
          status: ReminderOccurrenceStatus.completed,
        );
      }
    }
    notifySchedulePlanChanged();
  }

  Future<void> _deleteOccurrence(ReminderOccurrence value) async {
    final recurring = value.definition.recurrence != ReminderRecurrence.none;
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REMINDERを削除'),
        content: Text(recurring ? '削除する範囲を選択してください。' : 'このREMINDERを削除しますか？'),
        actions: recurring
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ).actionableFeedback(),
                TextButton(
                  onPressed: () => Navigator.pop(context, _DeleteChoice.once),
                  child: const Text('今回のみ削除'),
                ).actionableFeedback(),
                TextButton(
                  onPressed: () => Navigator.pop(context, _DeleteChoice.future),
                  child: const Text('今後すべて削除'),
                ).actionableFeedback(),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ).actionableFeedback(),
                TextButton(
                  onPressed: () => Navigator.pop(context, _DeleteChoice.single),
                  child: const Text('削除'),
                ).actionableFeedback(),
              ],
      ),
    );
    if (choice == null) return;
    final repository = AppRepositoryRegistry.container.reminders;
    if (choice == _DeleteChoice.once) {
      await _occurrences.skip(value, DateTime.now());
    } else if (choice == _DeleteChoice.future) {
      final boundary = DateTime.parse(
        value.localDate,
      ).subtract(const Duration(days: 1));
      final old = value.definition;
      await repository.saveDefinition(
        _withRecurrenceEnd(old, boundary, DateTime.now().toUtc()),
      );
    } else {
      await repository.deleteDefinition(value.definition.id);
      for (final state in await repository.findStates()) {
        if (state.definitionId == value.definition.id) {
          await repository.deleteState(state.id);
        }
      }
    }
    notifySchedulePlanChanged();
  }

  Future<void> _create() async {
    final draft = await Navigator.of(context).push<_ReminderDraft>(
      MaterialPageRoute(builder: (_) => const _ReminderEditor()),
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
        endTime: draft.timed && draft.endTime != null
            ? _timeKey(draft.endTime!)
            : null,
        recurrence: draft.recurrence,
        recurrenceEnd: draft.end == null ? null : _dateKey(draft.end!),
        weekdays: draft.weekdays,
        monthDays: draft.monthDays,
        monthEnd: draft.monthEnd,
        monthWeek: draft.monthWeek,
        monthWeeks: draft.monthWeeks,
        notificationOffsetsMinutes: draft.notificationOffsetsMinutes,
        notificationTimeZone: draft.notificationTimeZone,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    notifySchedulePlanChanged();
  }

  Future<void> _edit(ReminderDefinition previous) async {
    final draft = await Navigator.of(context).push<_ReminderDraft>(
      MaterialPageRoute(builder: (_) => _ReminderEditor(initial: previous)),
    );
    if (draft == null) return;
    final boundary = DateTime.now().toUtc();
    final repository = AppRepositoryRegistry.container.reminders;
    final nextStartDate = _dateKey(draft.date);
    await repository.saveDefinition(
      ReminderDefinition(
        id: previous.id,
        title: draft.title,
        note: draft.note,
        startDate: nextStartDate,
        allDay: !draft.timed,
        time: draft.timed ? _timeKey(draft.time) : null,
        endTime: draft.timed && draft.endTime != null
            ? _timeKey(draft.endTime!)
            : null,
        recurrence: draft.recurrence,
        recurrenceEnd: draft.end == null ? null : _dateKey(draft.end!),
        weekdays: draft.weekdays,
        monthDays: draft.monthDays,
        monthEnd: draft.monthEnd,
        monthWeek: draft.monthWeek,
        monthWeeks: draft.monthWeeks,
        notificationOffsetsMinutes: draft.notificationOffsetsMinutes,
        notificationTimeZone: draft.notificationTimeZone,
        active: true,
        createdAt: previous.createdAt,
        updatedAt: boundary,
        effectiveFrom: previous.effectiveFrom,
      ),
    );
    if (previous.recurrence == ReminderRecurrence.none &&
        draft.recurrence == ReminderRecurrence.none &&
        previous.startDate != nextStartDate) {
      for (final state in await repository.findStates()) {
        if (state.definitionId != previous.id ||
            state.localDate != previous.startDate) {
          continue;
        }
        await repository.saveState(
          ReminderOccurrenceState(
            id: '${previous.id}@$nextStartDate',
            definitionId: previous.id,
            localDate: nextStartDate,
            status: state.status,
            updatedAt: boundary,
            completedAt: state.completedAt,
          ),
        );
        await repository.deleteState(state.id);
      }
    }
    notifySchedulePlanChanged();
  }

  Future<void> _deleteDefinitionFuture(ReminderDefinition definition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('今後すべて削除'),
        content: const Text('過去と完了履歴は保持します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ).actionableFeedback(),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ).actionableFeedback(),
        ],
      ),
    );
    if (confirmed != true) return;
    final now = DateTime.now();
    final boundary = DateUtils.dateOnly(now).subtract(const Duration(days: 1));
    await AppRepositoryRegistry.container.reminders.saveDefinition(
      _withRecurrenceEnd(definition, boundary, now.toUtc()),
    );
    notifySchedulePlanChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: Navigator.of(context).canPop()
          ? ActionableFeedbackButton(
              enabled: true,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ).actionableFeedback(role: ActionableFeedbackRole.exit),
            )
          : null,
      title: const Text('REMINDERS'),
    ),
    floatingActionButton: _HudAddControl(onPressed: _create),
    body: Stack(
      children: [
        const Positioned.fill(child: HolographicAmbientBackground()),
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: _ReminderFloatingSurface(
                  child: Column(
                    children: [
                      _ReminderHudTabs(controller: _tabs),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : TabBarView(
                                controller: _tabs,
                                children: [
                                  _OccurrenceList(
                                    values: _today,
                                    empty: '今日のREMINDERはありません',
                                    onToggle: (value) =>
                                        _toggle(value, retentionTab: 0),
                                    onEdit: _edit,
                                    onDelete: _deleteOccurrence,
                                  ),
                                  _OccurrenceList(
                                    values: _all,
                                    empty: '今後のREMINDERはありません',
                                    onToggle: (value) =>
                                        _toggle(value, retentionTab: 1),
                                    onEdit: _edit,
                                    onDelete: _deleteOccurrence,
                                  ),
                                  _DefinitionList(
                                    values: _recurring,
                                    onEdit: _edit,
                                    onDelete: _deleteDefinitionFuture,
                                  ),
                                  _OccurrenceList(
                                    values: _completed,
                                    empty: '完了済みREMINDERはありません',
                                    onToggle: _toggle,
                                    onEdit: _edit,
                                    onDelete: _deleteOccurrence,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReminderFloatingSurface extends StatelessWidget {
  const _ReminderFloatingSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('reminder-floating-list-surface'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: .10),
            scheme.surfaceContainerHigh.withValues(alpha: .17),
            scheme.surface.withValues(alpha: .055),
            scheme.surfaceContainerLow.withValues(alpha: .14),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .10),
            blurRadius: 34,
            offset: const Offset(-5, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .46),
            blurRadius: 36,
            offset: const Offset(5, 16),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .18, .76, 1],
          colors: [
            scheme.primary.withValues(alpha: .055),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: .045),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          const Positioned.fill(child: HolographicScanlineOverlay()),
          child,
        ],
      ),
    );
  }
}

class _ReminderHudTabs extends StatelessWidget {
  const _ReminderHudTabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('reminder-hud-tabs'),
    margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: ActionableFeedbackRegion(
      role: ActionableFeedbackRole.silent,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: ShapeDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .22),
          shape: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
        indicatorPadding: const EdgeInsets.symmetric(
          vertical: 4,
          horizontal: 2,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        dividerColor: Colors.transparent,
        labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
        unselectedLabelStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(letterSpacing: .7),
        tabs: const [
          Tab(text: 'TODAY'),
          Tab(text: 'ALL'),
          Tab(text: 'RECURRING'),
          Tab(text: 'COMPLETED'),
        ],
      ),
    ),
  );
}

class _OccurrenceList extends StatefulWidget {
  const _OccurrenceList({
    required this.values,
    required this.empty,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ReminderOccurrence> values;
  final String empty;
  final _OccurrenceAction onToggle;
  final _DefinitionAction onEdit;
  final _OccurrenceAction onDelete;

  @override
  State<_OccurrenceList> createState() => _OccurrenceListState();
}

class _OccurrenceListState extends State<_OccurrenceList> {
  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return ListView(
        key: const ValueKey('reminder-occurrence-hud-list'),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(child: Text(widget.empty)),
          ),
        ],
      );
    }
    return ListView(
      key: const ValueKey('reminder-occurrence-hud-list'),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ReminderTimelineList(
            key: const ValueKey('reminder-full-list-timeline'),
            values: widget.values,
            onToggle: widget.onToggle,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
        ),
      ],
    );
  }
}

class _ReminderTimelineList extends StatefulWidget {
  const _ReminderTimelineList({
    super.key,
    required this.values,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ReminderOccurrence> values;
  final _OccurrenceAction onToggle;
  final _DefinitionAction onEdit;
  final _OccurrenceAction onDelete;

  @override
  State<_ReminderTimelineList> createState() => _ReminderTimelineListState();
}

class _ReminderTimelineListState extends State<_ReminderTimelineList> {
  final _timelineKey = GlobalKey();
  final _markerKeys = <String, GlobalKey>{};
  List<Rect> _markerBounds = const [];

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final parent =
          _timelineKey.currentContext?.findRenderObject() as RenderBox?;
      if (parent == null) return;
      final markerBounds = <Rect>[];
      for (final value in widget.values) {
        final box =
            _markerKeys[value.id]?.currentContext?.findRenderObject()
                as RenderBox?;
        if (box != null) {
          final origin = box.localToGlobal(Offset.zero, ancestor: parent);
          markerBounds.add(origin & box.size);
        }
      }
      if (markerBounds.length != _markerBounds.length ||
          markerBounds.indexed.any((entry) {
            final previous = _markerBounds[entry.$1];
            return (entry.$2.center - previous.center).distance > .1 ||
                (entry.$2.width - previous.width).abs() > .1 ||
                (entry.$2.height - previous.height).abs() > .1;
          })) {
        setState(() => _markerBounds = markerBounds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    return Stack(
      key: _timelineKey,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('reminder-full-list-timeline-rail'),
              painter: _ReminderTimelineRailPainter(
                color: Theme.of(context).colorScheme.primary,
                markerBounds: _markerBounds,
              ),
            ),
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < widget.values.length; index++) ...[
              Dismissible(
                key: ValueKey('reminder-${widget.values[index].id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await widget.onDelete(widget.values[index]);
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline),
                ),
                child: _ReminderOccurrenceRow(
                  value: widget.values[index],
                  markerKey: _markerKeys.putIfAbsent(
                    widget.values[index].id,
                    GlobalKey.new,
                  ),
                  onToggle: () => widget.onToggle(widget.values[index]),
                  onEdit: () => widget.onEdit(widget.values[index].definition),
                ),
              ),
              if (index < widget.values.length - 1) const _ReminderRowDivider(),
            ],
          ],
        ),
      ],
    );
  }
}

class _ReminderTimelineRailPainter extends CustomPainter {
  const _ReminderTimelineRailPainter({
    required this.color,
    required this.markerBounds,
  });

  final Color color;
  final List<Rect> markerBounds;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: holographicTimelineRailOpacity)
      ..strokeWidth = reminderCircuitRailWidth
      ..strokeCap = StrokeCap.butt;
    for (var index = 0; index < markerBounds.length - 1; index++) {
      final upper = markerBounds[index];
      final lower = markerBounds[index + 1];
      canvas.drawLine(
        Offset(upper.center.dx, upper.bottom),
        Offset(lower.center.dx, lower.top),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReminderTimelineRailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.markerBounds != markerBounds;
}

class _ReminderRowDivider extends StatelessWidget {
  const _ReminderRowDivider();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 52),
    height: 1,
    color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
  );
}

class _ReminderOccurrenceRow extends StatelessWidget {
  const _ReminderOccurrenceRow({
    required this.value,
    required this.markerKey,
    required this.onToggle,
    required this.onEdit,
  });
  final ReminderOccurrence value;
  final Key markerKey;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final completed = value.status == ReminderOccurrenceStatus.completed;
    final colorScheme = Theme.of(context).colorScheme;
    final secondary = colorScheme.onSurface.withValues(alpha: .65);
    return Semantics(
      label: '${value.definition.title} ${completed ? '完了' : '未完了'}',
      child: InkWell(
        key: ValueKey('reminder-row-${value.id}'),
        onTap: onEdit,
        onLongPress: onEdit,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReminderCircuitNode(
                id: value.id,
                child: _HudCompletionControl(
                  key: ValueKey('reminder-toggle-${value.id}'),
                  markerKey: markerKey,
                  completed: completed,
                  onPressed: onToggle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.definition.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: completed ? secondary : null,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      _ReminderSubtitle(
                        summary:
                            '${value.localDate}${value.definition.time == null ? '  終日' : '  ${value.definition.time}'}',
                        note: value.definition.note,
                        completed: completed,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).actionableFeedback(),
    );
  }
}

class _ReminderCircuitNode extends StatelessWidget {
  const _ReminderCircuitNode({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('reminder-circuit-node-$id'),
    width: reminderCompletionTouchTarget,
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: reminderCompletionTouchTarget,
          height: reminderCompletionTouchTarget,
          child: child,
        ),
      ),
    ),
  );
}

class _HudCompletionControl extends StatelessWidget {
  const _HudCompletionControl({
    super.key,
    required this.markerKey,
    required this.completed,
    required this.onPressed,
  });
  final Key markerKey;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    return Semantics(
      label: completed ? '未完了に戻す' : '完了にする',
      button: true,
      child: SizedBox(
        width: reminderCompletionTouchTarget,
        height: reminderCompletionTouchTarget,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: KeyedSubtree(
              key: markerKey,
              child: Icon(
                key: ValueKey(
                  completed
                      ? 'reminder-completion-check-circle'
                      : 'reminder-completion-circle',
                ),
                completed ? Icons.check_circle : Icons.circle_outlined,
                size: reminderCompletionIconSize,
                color: completed
                    ? accent
                    : colorScheme.primary.withValues(
                        alpha: holographicTimelineNodeOpacity,
                      ),
              ),
            ),
          ),
        ).actionableFeedback(),
      ),
    );
  }
}

class _HudAddControl extends StatelessWidget {
  const _HudAddControl({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    return Semantics(
      button: true,
      label: 'REMINDERを追加',
      child: Tooltip(
        message: 'REMINDERを追加',
        child: Material(
          key: const ValueKey('reminder-add-control'),
          color: colorScheme.primary.withValues(alpha: .18),
          elevation: 4,
          shadowColor: colorScheme.primary.withValues(alpha: .28),
          shape: shape,
          child: SizedBox(
            width: 56,
            height: 56,
            child: InkWell(
              onTap: onPressed,
              customBorder: shape,
              child: Icon(Icons.add, color: colorScheme.primary),
            ).actionableFeedback(),
          ),
        ),
      ),
    );
  }
}

class _DefinitionList extends StatelessWidget {
  const _DefinitionList({
    required this.values,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ReminderDefinition> values;
  final _DefinitionAction onEdit;
  final _DefinitionAction onDelete;
  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('reminder-definition-hud-list'),
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
    itemCount: values.isEmpty ? 1 : values.length,
    itemBuilder: (context, index) {
      if (values.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: 32),
          child: Center(child: Text('繰り返しREMINDERはありません')),
        );
      }
      final value = values[index];
      return Dismissible(
        key: ValueKey('recurring-${value.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await onDelete(value);
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          color: Theme.of(context).colorScheme.error,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_outline),
        ),
        child: InkWell(
          key: ValueKey('recurring-row-${value.id}'),
          onTap: () => onEdit(value),
          onLongPress: () => onEdit(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 12),
                  child: Icon(Icons.notifications_none),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      _ReminderSubtitle(
                        summary: _recurrenceSummary(value),
                        note: value.note,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).actionableFeedback(),
      );
    },
    separatorBuilder: (_, _) => Container(
      height: 1,
      margin: const EdgeInsets.only(left: 52),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .18),
    ),
  );
}

class _ReminderSubtitle extends StatelessWidget {
  const _ReminderSubtitle({
    required this.summary,
    this.note,
    this.completed = false,
  });
  final String summary;
  final String? note;
  final bool completed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        summary,
        style: completed
            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .65),
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      if (note != null && note!.trim().isNotEmpty)
        Text(
          note!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .65),
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
    ],
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
  TimeOfDay? _endTime;
  bool _timed = false;
  ReminderRecurrence _recurrence = ReminderRecurrence.none;
  DateTime? _end;
  final Set<int> _weekdays = <int>{};
  final Set<int> _monthDays = <int>{};
  bool _monthEnd = false;
  int? _monthWeek;
  final Set<int> _monthWeeks = <int>{};
  late NotificationConfiguration _notification = NotificationConfiguration(
    offsetsMinutes: widget.initial?.notificationOffsetsMinutes ?? const [],
    timeZone:
        widget.initial?.notificationTimeZone ??
        NotificationProfileController.instance.timeZone,
  );
  String? _error;
  late final _ReminderEditorBaseline _baseline;
  bool _allowPop = false;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _title.text = initial.title;
      _note.text = initial.note ?? '';
      _date = DateTime.parse(initial.startDate);
      _timed = !initial.allDay;
      _time = timeOfDayFromClock(initial.time);
      _endTime = initial.endTime == null
          ? null
          : timeOfDayFromClock(initial.endTime);
      _recurrence = initial.recurrence;
      _end = initial.recurrenceEnd == null
          ? null
          : DateTime.tryParse(initial.recurrenceEnd!);
      _weekdays.addAll(initial.weekdays);
      _monthDays.addAll(initial.monthDays);
      _monthEnd = initial.monthEnd;
      _monthWeek = initial.monthWeek;
      _monthWeeks.addAll(
        initial.monthWeeks.isNotEmpty
            ? initial.monthWeeks
            : initial.monthWeek == null
            ? const []
            : [initial.monthWeek!],
      );
    } else {
      final now = DateTime.now();
      final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
      _date = DateUtils.dateOnly(nextHour);
      _time = TimeOfDay(hour: nextHour.hour, minute: 0);
    }
    _baseline = _ReminderEditorBaseline(
      title: _title.text,
      note: _note.text,
      date: _date,
      time: _time,
      endTime: _endTime,
      timed: _timed,
      recurrence: _recurrence,
      end: _end,
      weekdays: _weekdays,
      monthDays: _monthDays,
      monthEnd: _monthEnd,
      monthWeek: _monthWeek,
      monthWeeks: _monthWeeks,
      notificationOffsetsMinutes: _notification.offsetsMinutes,
      notificationTimeZone: _notification.timeZone,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isDirty => !_baseline.matches(
    title: _title.text,
    note: _note.text,
    date: _date,
    time: _time,
    endTime: _endTime,
    timed: _timed,
    recurrence: _recurrence,
    end: _end,
    weekdays: _weekdays,
    monthDays: _monthDays,
    monthEnd: _monthEnd,
    monthWeek: _monthWeek,
    monthWeeks: _monthWeeks,
    notificationOffsetsMinutes: _notification.offsetsMinutes,
    notificationTimeZone: _notification.timeZone,
  );

  Future<void> _requestExit() async {
    if (!_isDirty) {
      _close();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('変更内容が保存されていません。破棄しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('編集を続ける'),
          ).actionableFeedback(),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('破棄する'),
          ).actionableFeedback(role: ActionableFeedbackRole.exit),
        ],
      ),
    );
    if (discard == true && mounted) _close();
  }

  void _close([_ReminderDraft? draft]) {
    setState(() => _allowPop = true);
    Navigator.of(context).pop(draft);
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
    if (_recurrence == ReminderRecurrence.customWeekdays && weekdays.isEmpty) {
      setState(() => _error = '曜日を1つ以上選択してください。');
      return;
    }
    if (_recurrence == ReminderRecurrence.customMonthDays &&
        monthDays.isEmpty &&
        !_monthEnd) {
      setState(() => _error = '日付を1つ以上選択してください。');
      return;
    }
    _close(
      _ReminderDraft(
        title: title,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        date: _date,
        timed: _timed,
        time: _time,
        endTime: _endTime,
        recurrence: _recurrence,
        end: _end,
        weekdays: weekdays,
        monthDays: monthDays,
        monthEnd:
            _recurrence == ReminderRecurrence.customMonthDays && _monthEnd,
        monthWeek: _recurrence == ReminderRecurrence.monthlyWeekday
            ? (_monthWeek ?? ((_date.day - 1) ~/ 7) + 1)
            : null,
        monthWeeks: _recurrence == ReminderRecurrence.monthlyWeekday
            ? (_monthWeeks.isEmpty
                  ? [((_date.day - 1) ~/ 7) + 1]
                  : (_monthWeeks.toList()..sort()))
            : const [],
        notificationOffsetsMinutes: _notification.offsetsMinutes,
        notificationTimeZone: _notification.timeZone,
      ),
    );
  }

  List<int> get _effectiveWeekdays =>
      _recurrence == ReminderRecurrence.customWeekdays
      ? (_weekdays.toList()..sort())
      : const [];

  List<int> get _effectiveMonthDays => switch (_recurrence) {
    ReminderRecurrence.monthly =>
      _monthDays.isEmpty ? [_date.day] : _monthDays.toList()
        ..sort(),
    ReminderRecurrence.customMonthDays => _monthDays.toList()..sort(),
    _ => const [],
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestExit();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: ActionableFeedbackButton(
          enabled: true,
          role: ActionableFeedbackRole.exit,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _requestExit,
          ).actionableFeedback(),
        ),
        title: Text(widget.initial == null ? 'REMINDERを追加' : 'REMINDERを編集'),
        actions: [
          ActionableFeedbackButton(
            enabled: true,
            child: TextButton(
              onPressed: _save,
              child: const Text('保存'),
            ).actionableFeedback(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'タイトル'),
                onChanged: (_) => setState(() => _error = null),
              ).inputFeedback(),
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'メモ'),
              ).inputFeedback(),
              SharedDateTimeEditor(
                date: _date,
                allDay: !_timed,
                startTime: _timed ? _time : null,
                endTime: _timed ? _endTime : null,
                onDateChanged: (value) => setState(() => _date = value),
                onAllDayChanged: (value) => setState(() => _timed = !value),
                onStartTimeChanged: (value) => setState(
                  () => _time = value ?? const TimeOfDay(hour: 9, minute: 0),
                ),
                onEndTimeChanged: (value) => setState(() => _endTime = value),
              ),
              SharedRecurrenceEditor(
                startDate: _date,
                value: SharedRecurrenceValue(
                  recurrence: _recurrence,
                  end: _end,
                  weekdays: _weekdays,
                  monthDays: _monthDays,
                  monthEnd: _monthEnd,
                  monthWeek: _monthWeek,
                  monthWeeks: _monthWeeks,
                ),
                onChanged: (value) => setState(() {
                  _recurrence = value.recurrence;
                  _end = value.end;
                  _weekdays
                    ..clear()
                    ..addAll(value.weekdays);
                  _monthDays
                    ..clear()
                    ..addAll(value.monthDays);
                  _monthEnd = value.monthEnd;
                  _monthWeek = value.monthWeek;
                  _monthWeeks
                    ..clear()
                    ..addAll(value.monthWeeks);
                  _error = null;
                }),
              ),
              SharedNotificationEditor(
                value: _notification,
                onChanged: (value) => setState(() => _notification = value),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
      ),
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
    this.endTime,
    required this.recurrence,
    this.end,
    this.weekdays = const [],
    this.monthDays = const [],
    this.monthEnd = false,
    this.monthWeek,
    this.monthWeeks = const [],
    this.notificationOffsetsMinutes = const [],
    this.notificationTimeZone = 'Etc/UTC',
  });
  final String title;
  final String? note;
  final DateTime date;
  final bool timed;
  final TimeOfDay time;
  final TimeOfDay? endTime;
  final ReminderRecurrence recurrence;
  final DateTime? end;
  final List<int> weekdays;
  final List<int> monthDays;
  final bool monthEnd;
  final int? monthWeek;
  final List<int> monthWeeks;
  final List<int> notificationOffsetsMinutes;
  final String notificationTimeZone;
}

class _ReminderEditorBaseline {
  _ReminderEditorBaseline({
    required this.title,
    required this.note,
    required this.date,
    required this.time,
    required this.endTime,
    required this.timed,
    required this.recurrence,
    required this.end,
    required Set<int> weekdays,
    required Set<int> monthDays,
    required this.monthEnd,
    required this.monthWeek,
    required Set<int> monthWeeks,
    required List<int> notificationOffsetsMinutes,
    required this.notificationTimeZone,
  }) : weekdays = Set.unmodifiable(weekdays),
       monthDays = Set.unmodifiable(monthDays),
       monthWeeks = Set.unmodifiable(monthWeeks),
       notificationOffsetsMinutes = List.unmodifiable(
         notificationOffsetsMinutes,
       );

  final String title;
  final String note;
  final DateTime date;
  final TimeOfDay time;
  final TimeOfDay? endTime;
  final bool timed;
  final ReminderRecurrence recurrence;
  final DateTime? end;
  final Set<int> weekdays;
  final Set<int> monthDays;
  final bool monthEnd;
  final int? monthWeek;
  final Set<int> monthWeeks;
  final List<int> notificationOffsetsMinutes;
  final String notificationTimeZone;

  bool matches({
    required String title,
    required String note,
    required DateTime date,
    required TimeOfDay time,
    required TimeOfDay? endTime,
    required bool timed,
    required ReminderRecurrence recurrence,
    required DateTime? end,
    required Set<int> weekdays,
    required Set<int> monthDays,
    required bool monthEnd,
    required int? monthWeek,
    required Set<int> monthWeeks,
    required List<int> notificationOffsetsMinutes,
    required String notificationTimeZone,
  }) =>
      this.title == title &&
      this.note == note &&
      this.date == date &&
      this.time == time &&
      this.endTime == endTime &&
      this.timed == timed &&
      this.recurrence == recurrence &&
      this.end == end &&
      _sameValues(this.weekdays, weekdays) &&
      _sameValues(this.monthDays, monthDays) &&
      this.monthEnd == monthEnd &&
      this.monthWeek == monthWeek &&
      _sameValues(this.monthWeeks, monthWeeks) &&
      _sameList(this.notificationOffsetsMinutes, notificationOffsetsMinutes) &&
      this.notificationTimeZone == notificationTimeZone;

  static bool _sameValues(Set<int> first, Set<int> second) =>
      first.length == second.length && first.containsAll(second);
  static bool _sameList(List<int> first, List<int> second) =>
      first.length == second.length && first.toSet().containsAll(second);
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _timeKey(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

bool _isCurrentRecurringDefinition(
  ReminderDefinition definition,
  DateTime today,
) {
  if (!definition.active || definition.recurrence == ReminderRecurrence.none) {
    return false;
  }
  final end = DateTime.tryParse(definition.recurrenceEnd ?? '');
  return end == null || !DateUtils.dateOnly(end).isBefore(today);
}

ReminderDefinition _withRecurrenceEnd(
  ReminderDefinition definition,
  DateTime boundary,
  DateTime updatedAt,
) {
  final existingEnd = DateTime.tryParse(definition.recurrenceEnd ?? '');
  final requestedEnd = DateUtils.dateOnly(boundary);
  final effectiveEnd = existingEnd != null && existingEnd.isBefore(requestedEnd)
      ? existingEnd
      : requestedEnd;
  return ReminderDefinition(
    id: definition.id,
    title: definition.title,
    note: definition.note,
    startDate: definition.startDate,
    allDay: definition.allDay,
    time: definition.time,
    endTime: definition.endTime,
    recurrence: definition.recurrence,
    recurrenceEnd: _dateKey(effectiveEnd),
    weekdays: definition.weekdays,
    monthDays: definition.monthDays,
    monthEnd: definition.monthEnd,
    monthWeek: definition.monthWeek,
    monthWeeks: definition.monthWeeks,
    notificationOffsetsMinutes: definition.notificationOffsetsMinutes,
    notificationTimeZone: definition.notificationTimeZone,
    active: definition.active,
    createdAt: definition.createdAt,
    updatedAt: updatedAt,
    effectiveFrom: definition.effectiveFrom,
    retiredAt: definition.retiredAt,
  );
}

String _recurrenceLabel(ReminderRecurrence value) => switch (value) {
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

String _recurrenceSummary(ReminderDefinition definition) {
  final label = _recurrenceLabel(definition.recurrence);
  if (definition.recurrence == ReminderRecurrence.customWeekdays) {
    final details = definition.weekdays.map(_weekdayLabel).join('・');
    return details.isEmpty ? label : '$label  $details';
  }
  if (definition.recurrence == ReminderRecurrence.customMonthDays) {
    final details = <String>[
      ...definition.monthDays.map((day) => '$day'),
      if (definition.monthEnd) '月末',
    ].join('・');
    return details.isEmpty ? label : '$label  $details';
  }
  final start = DateTime.parse(definition.startDate);
  return switch (definition.recurrence) {
    ReminderRecurrence.weekly => '$label  ${_weekdayLabel(start.weekday)}曜日',
    ReminderRecurrence.biweekly => '$label  ${_weekdayLabel(start.weekday)}曜日',
    ReminderRecurrence.monthlyWeekday =>
      '$label  ${(definition.monthWeeks.isEmpty ? [definition.monthWeek ?? ((start.day - 1) ~/ 7) + 1] : definition.monthWeeks).map((week) => '第$week').join('・')}・${_weekdayLabel(start.weekday)}',
    ReminderRecurrence.monthly => '$label  ${start.day}日',
    ReminderRecurrence.yearly => '$label  ${start.month}月${start.day}日',
    _ => label,
  };
}

String _weekdayLabel(int day) =>
    const ['月', '火', '水', '木', '金', '土', '日'][day - 1];
