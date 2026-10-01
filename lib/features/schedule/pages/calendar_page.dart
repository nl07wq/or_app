import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../weather/weather_models.dart';
import '../../weather/weather_link.dart';
import '../../weather/weather_service.dart';
import '../clock_dial_geometry.dart';
import '../models/schedule_record.dart';
import '../models/schedule_plan_revision.dart';

enum _WeatherDisclosure { collapsed, sevenDay, details, hourly }

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
  final WeatherService _weatherService = WeatherService();
  WeatherLocationPreferences _weatherPreferences =
      const WeatherLocationPreferences(locations: [], activeLocationId: null);
  WeatherSnapshot? _weatherSnapshot;
  bool _weatherLoading = false;
  bool _weatherRefreshing = false;
  bool _weatherStale = false;
  String? _weatherError;
  _WeatherDisclosure _weatherDisclosure = _WeatherDisclosure.collapsed;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWeather();
  }

  Future<void> _loadWeather({
    bool forceRefresh = false,
    WeatherLocation? location,
  }) async {
    if (_weatherLoading) return;
    setState(() {
      _weatherLoading = true;
      _weatherRefreshing = forceRefresh;
      _weatherError = null;
    });
    final preferences = await _weatherService.loadLocations();
    final selectedLocation = location ?? preferences.activeLocation;
    if (selectedLocation == null) {
      if (!mounted) return;
      setState(() {
        _weatherPreferences = preferences;
        _weatherSnapshot = null;
        _weatherLoading = false;
        _weatherRefreshing = false;
      });
      return;
    }
    final result = await _weatherService.load(
      selectedLocation,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _weatherPreferences = preferences;
      _weatherSnapshot = result.snapshot;
      _weatherStale = result.isStale;
      _weatherError = result.snapshot == null ? 'WEATHER UNAVAILABLE' : null;
      _weatherLoading = false;
      _weatherRefreshing = false;
    });
  }

  Future<void> _openWeatherSettings() async {
    await Navigator.of(context).pushNamed(AppRoutes.weatherSettings);
    if (!mounted) return;
    setState(() => _weatherDisclosure = _WeatherDisclosure.collapsed);
    await _loadWeather();
  }

  Future<void> _switchWeatherLocation(int direction) async {
    final locations = _weatherPreferences.locations;
    if (locations.length < 2) return;
    final activeId = _weatherPreferences.activeLocationId;
    final index = locations.indexWhere(
      (location) => location.stableId == activeId,
    );
    final next =
        locations[(index + direction + locations.length) % locations.length];
    await _weatherService.setActiveLocation(next.stableId);
    if (!mounted) return;
    setState(() {
      _weatherPreferences = WeatherLocationPreferences(
        locations: locations,
        activeLocationId: next.stableId,
      );
      _weatherSnapshot = null;
      _weatherStale = false;
    });
    await _loadWeather(location: next);
  }

  void _selectWeatherDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return;
    setState(() {
      _selected = _dateOnly(date);
      _month = DateTime(date.year, date.month);
      if (_weatherDisclosure == _WeatherDisclosure.hourly) {
        _weatherDisclosure = _WeatherDisclosure.details;
      }
    });
    _load();
  }

  void _toggleWeatherDisclosure() => setState(() {
    _weatherDisclosure = switch (_weatherDisclosure) {
      _WeatherDisclosure.collapsed => _WeatherDisclosure.sevenDay,
      _WeatherDisclosure.sevenDay => _WeatherDisclosure.collapsed,
      _WeatherDisclosure.details => _WeatherDisclosure.sevenDay,
      _WeatherDisclosure.hourly => _WeatherDisclosure.details,
    };
  });

  /// Calendar actions retain their normal callback path; this only folds the
  /// contextual Weather layer before that action proceeds.
  void _collapseWeatherForCalendarAction() {
    if (_weatherDisclosure != _WeatherDisclosure.collapsed) {
      setState(() {
        _weatherDisclosure = _WeatherDisclosure.collapsed;
      });
    }
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
      notifySchedulePlanChanged();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
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
                _CalendarWeatherHud(
                  preferences: _weatherPreferences,
                  snapshot: _weatherSnapshot,
                  selectedDate: _selectedKey,
                  loading: _weatherLoading,
                  stale: _weatherStale,
                  error: _weatherError,
                  refreshing: _weatherRefreshing,
                  disclosure: _weatherDisclosure,
                  onSettings: _openWeatherSettings,
                  onRefresh: () => _loadWeather(forceRefresh: true),
                  onSelectDate: _selectWeatherDate,
                  onSwipeLocation: _switchWeatherLocation,
                  onToggleDisclosure: _toggleWeatherDisclosure,
                  onShowDetails: () => setState(
                    () => _weatherDisclosure = _WeatherDisclosure.details,
                  ),
                  onToggleHourly: () => setState(() {
                    _weatherDisclosure =
                        _weatherDisclosure == _WeatherDisclosure.hourly
                        ? _WeatherDisclosure.details
                        : _WeatherDisclosure.hourly;
                  }),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _collapseWeatherForCalendarAction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSpacing.gapLG,
                      _MonthGrid(
                        month: _month,
                        selected: _selected,
                        byDate: _byDate,
                        onPrevious: () {
                          _collapseWeatherForCalendarAction();
                          setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month - 1,
                            ),
                          );
                          _load();
                        },
                        onNext: () {
                          _collapseWeatherForCalendarAction();
                          setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          );
                          _load();
                        },
                        onToday: () {
                          _collapseWeatherForCalendarAction();
                          final now = _dateOnly(DateTime.now());
                          setState(() {
                            _selected = now;
                            _month = DateTime(now.year, now.month);
                          });
                          _load();
                        },
                        onSelect: (date) {
                          _collapseWeatherForCalendarAction();
                          setState(() => _selected = date);
                        },
                      ),
                      AppSpacing.gapLG,
                      SectionHeader(
                        icon: Icons.timeline,
                        title: "TODAY'S TIMELINE",
                      ),
                      Text(
                        '${_selected.month.toString().padLeft(2, '0')} / ${_selected.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      AppSpacing.gapSM,
                      if (_selectedSchedules.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'NO PLANNED ENTRIES',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final record in _selectedSchedules)
                        Dismissible(
                          key: ValueKey('schedule-entry-${record.id}'),
                          direction: DismissDirection.endToStart,
                          background: const _TimelineDeleteBackground(),
                          confirmDismiss: (_) => _confirmDelete(record),
                          onDismissed: (_) => _deleteRecord(record),
                          child: _TimelineEntry(
                            record: record,
                            onTap: () {
                              _collapseWeatherForCalendarAction();
                              _openEditor(record);
                            },
                            onReminderToggle:
                                record.kind == ScheduleEntryKind.reminder
                                ? () => _toggleReminder(record)
                                : null,
                            onMove: (minutes) => _moveTimed(record, minutes),
                          ),
                        ),
                      AppSpacing.gapMD,
                      OperationButton(
                        text: 'ADD ENTRY',
                        icon: Icons.add,
                        onPressed: () {
                          _collapseWeatherForCalendarAction();
                          _openEditor();
                        },
                        role: OperationActionRole.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
  );

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
    notifySchedulePlanChanged();
    await _load();
  }

  Future<void> _moveTimed(ScheduleRecord record, int minutes) async {
    final start = _parseClock(record.startTime ?? '');
    if (start == null) return;
    final shifted = _formatClock((start + minutes) % 1440);
    final end = _parseClock(record.endTime ?? '');
    final shiftedEnd = end == null
        ? null
        : _formatClock((end + minutes) % 1440);
    await AppRepositoryRegistry.container.schedules.save(
      ScheduleRecord(
        id: record.id,
        localDate: record.localDate,
        type: record.type,
        title: record.title,
        kind: record.kind,
        allDay: record.allDay,
        startTime: shifted,
        endTime: shiftedEnd,
        breakDuration: record.breakDuration,
        memo: record.memo,
        completed: record.completed,
        createdAt: record.createdAt,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    notifySchedulePlanChanged();
    await _load();
  }

  Future<bool> _confirmDelete(ScheduleRecord record) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('DELETE ENTRY?'),
            content: Text('Remove "${record.title}" from the planner?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DELETE'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteRecord(ScheduleRecord record) async {
    await AppRepositoryRegistry.container.schedules.delete(record.id);
    notifySchedulePlanChanged();
    await _load();
  }
}

class _TimelineDeleteBackground extends StatelessWidget {
  const _TimelineDeleteBackground();

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .5),
    child: Icon(
      Icons.delete_outline,
      color: Theme.of(context).colorScheme.onErrorContainer,
    ),
  );
}

class _CalendarWeatherHud extends StatelessWidget {
  const _CalendarWeatherHud({
    required this.preferences,
    required this.snapshot,
    required this.selectedDate,
    required this.loading,
    required this.stale,
    required this.error,
    required this.refreshing,
    required this.disclosure,
    required this.onSettings,
    required this.onRefresh,
    required this.onSelectDate,
    required this.onSwipeLocation,
    required this.onToggleDisclosure,
    required this.onShowDetails,
    required this.onToggleHourly,
  });

  final WeatherLocationPreferences preferences;
  final WeatherSnapshot? snapshot;
  final String selectedDate;
  final bool loading;
  final bool stale;
  final String? error;
  final bool refreshing;
  final _WeatherDisclosure disclosure;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<int> onSwipeLocation;
  final VoidCallback onToggleDisclosure;
  final VoidCallback onShowDetails;
  final VoidCallback onToggleHourly;

  @override
  Widget build(BuildContext context) {
    final location = preferences.activeLocation;
    final scheme = Theme.of(context).colorScheme;
    final matchingDays = snapshot?.daily
        .where((day) => day.date == selectedDate)
        .toList(growable: false);
    final selected = matchingDays == null || matchingDays.isEmpty
        ? null
        : matchingDays.first;
    final detailsVisible =
        disclosure == _WeatherDisclosure.details ||
        disclosure == _WeatherDisclosure.hourly;
    final hourly = selected == null
        ? const <WeatherHourly>[]
        : _hourlyForDay(snapshot!, selected);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.primary.withValues(alpha: .42)),
          bottom: BorderSide(color: scheme.primary.withValues(alpha: .24)),
        ),
        gradient: LinearGradient(
          colors: [scheme.primary.withValues(alpha: .07), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeatherSurfaceGesture(
            enabled: preferences.locations.length > 1,
            onSwipeLocation: onSwipeLocation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeatherHeader(
                  preferences: preferences,
                  location: location,
                  disclosure: disclosure,
                  loading: refreshing,
                  canRefresh: location != null,
                  onRefresh: onRefresh,
                  onSettings: onSettings,
                  onSwitchLocation: onSwipeLocation,
                  onToggleDisclosure: onToggleDisclosure,
                ),
                if (location == null)
                  _WeatherMessage(
                    text: 'SET A WEATHER LOCATION TO START FORECAST SYNC.',
                    action: 'SET LOCATION',
                    onAction: onSettings,
                  )
                else if (snapshot == null)
                  _WeatherMessage(
                    text: loading
                        ? 'SYNCING WEATHER...'
                        : error ?? 'WEATHER UNAVAILABLE',
                    action: 'RETRY',
                    onAction: onRefresh,
                  )
                else ...[
                  if (selected != null)
                    _WeatherSummary(
                      day: selected,
                      snapshot: snapshot!,
                      onTap: disclosure == _WeatherDisclosure.collapsed
                          ? onToggleDisclosure
                          : onShowDetails,
                    ),
                  if (disclosure != _WeatherDisclosure.collapsed) ...[
                    const SizedBox(height: 3),
                    _WeatherForecastList(
                      values: snapshot!.daily.take(7).toList(growable: false),
                      selectedDate: selectedDate,
                      onSelectDate: onSelectDate,
                    ),
                  ],
                  if (disclosure == _WeatherDisclosure.sevenDay &&
                      selected != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onShowDetails,
                        icon: const Icon(Icons.expand_more, size: 16),
                        label: const Text('DETAILS'),
                      ),
                    ),
                  if (stale)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
                      child: Text(
                        'OFFLINE / CACHED · UPDATED UTC ${_displayFetchedAt(snapshot!.fetchedAt)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                  if (selected != null && detailsVisible)
                    _WeatherDetails(
                      day: selected,
                      snapshot: snapshot!,
                      hourlyVisible: disclosure == _WeatherDisclosure.hourly,
                      hourlyAvailable: hourly.isNotEmpty,
                      onToggleHourly: onToggleHourly,
                    ),
                  if (detailsVisible)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 3, 12, 0),
                      child: _OpenMeteoAttribution(),
                    ),
                ],
              ],
            ),
          ),
          if (detailsVisible && disclosure == _WeatherDisclosure.hourly)
            _WeatherHourlyTimeline(values: hourly),
        ],
      ),
    );
  }
}

/// Owns a drag that starts on the visible Weather surface, even when its
/// pointer ends beyond that surface. Calendar outside-tap handling must not
/// reinterpret this sequence as a collapse action.
class WeatherSurfaceGesture extends StatelessWidget {
  const WeatherSurfaceGesture({
    super.key,
    required this.enabled,
    required this.onSwipeLocation,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<int> onSwipeLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragEnd: enabled
        ? (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() > 120) {
              onSwipeLocation(velocity < 0 ? 1 : -1);
            }
          }
        : null,
    child: child,
  );
}

class _WeatherHeader extends StatelessWidget {
  const _WeatherHeader({
    required this.preferences,
    required this.location,
    required this.disclosure,
    required this.loading,
    required this.canRefresh,
    required this.onRefresh,
    required this.onSettings,
    required this.onSwitchLocation,
    required this.onToggleDisclosure,
  });

  final WeatherLocationPreferences preferences;
  final WeatherLocation? location;
  final _WeatherDisclosure disclosure;
  final bool loading;
  final bool canRefresh;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final ValueChanged<int> onSwitchLocation;
  final VoidCallback onToggleDisclosure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeIndex = preferences.locations.indexWhere(
      (value) => value.stableId == preferences.activeLocationId,
    );
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleDisclosure,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 2, 7),
              child: Row(
                children: [
                  Icon(Icons.cloud_outlined, color: scheme.primary, size: 17),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location == null
                          ? '天気 / 場所未設定'
                          : '天気 / ${location!.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(letterSpacing: 0.7),
                    ),
                  ),
                  if (preferences.locations.length > 1) ...[
                    _HeaderArrow(
                      icon: Icons.chevron_left,
                      tooltip: 'Previous weather location',
                      onPressed: () => onSwitchLocation(-1),
                    ),
                    Text(
                      '${activeIndex + 1}/${preferences.locations.length}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    _HeaderArrow(
                      icon: Icons.chevron_right,
                      tooltip: 'Next weather location',
                      onPressed: () => onSwitchLocation(1),
                    ),
                  ],
                  Icon(
                    disclosure == _WeatherDisclosure.collapsed
                        ? Icons.expand_more
                        : Icons.expand_less,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '天気を更新',
          visualDensity: VisualDensity.compact,
          icon: loading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          onPressed: loading || !canRefresh ? null : onRefresh,
        ),
        IconButton(
          tooltip: '天気の場所',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.settings_outlined, size: 18),
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _HeaderArrow extends StatelessWidget {
  const _HeaderArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    padding: EdgeInsets.zero,
    icon: Icon(icon, size: 16),
    onPressed: onPressed,
  );
}

class _WeatherMessage extends StatelessWidget {
  const _WeatherMessage({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}

class _WeatherForecastList extends StatelessWidget {
  const _WeatherForecastList({
    required this.values,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final List<WeatherDaily> values;
  final String selectedDate;
  final ValueChanged<String> onSelectDate;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final globalLow = values.map((value) => value.low).reduce(math.min);
    final globalHigh = values.map((value) => value.high).reduce(math.max);
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          children: [
            for (final value in values)
              _WeatherForecastRow(
                value: value,
                selected: value.date == selectedDate,
                today: _sameDay(DateTime.parse(value.date), today),
                globalLow: globalLow,
                globalHigh: globalHigh,
                onTap: () => onSelectDate(value.date),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeatherForecastRow extends StatelessWidget {
  const _WeatherForecastRow({
    required this.value,
    required this.selected,
    required this.today,
    required this.globalLow,
    required this.globalHigh,
    required this.onTap,
  });

  final WeatherDaily value;
  final bool selected;
  final bool today;
  final double globalLow;
  final double globalHigh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(value.date);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${value.date}, ${_weatherConditionJapanese(value.code)}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.primary.withValues(alpha: .18)),
              left: selected
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(today ? '今日' : _weekdayJapanese(date.weekday)),
                    Text(
                      '${date.month}/${date.day}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Icon(_weatherIcon(value.code), color: scheme.primary, size: 19),
              const SizedBox(width: 7),
              SizedBox(width: 36, child: Text('${value.low.round()}°')),
              Expanded(
                child: SizedBox(
                  height: 18,
                  child: CustomPaint(
                    painter: _TemperatureRangePainter(
                      color: scheme.primary,
                      low: value.low,
                      high: value.high,
                      globalLow: globalLow,
                      globalHigh: globalHigh,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 36, child: Text('${value.high.round()}°')),
              SizedBox(
                width: 36,
                child: Text(
                  '${value.precipitationProbability}%',
                  textAlign: TextAlign.end,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemperatureRangePainter extends CustomPainter {
  const _TemperatureRangePainter({
    required this.color,
    required this.low,
    required this.high,
    required this.globalLow,
    required this.globalHigh,
  });
  final Color color;
  final double low;
  final double high;
  final double globalLow;
  final double globalHigh;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = color.withValues(alpha: .16)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = color.withValues(alpha: .8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    final span = math.max(1, globalHigh - globalLow);
    final start = ((low - globalLow) / span) * size.width;
    final end = ((high - globalLow) / span) * size.width;
    canvas.drawLine(
      Offset.zero.translate(0, centerY),
      Offset(size.width, centerY),
      track,
    );
    canvas.drawLine(Offset(start, centerY), Offset(end, centerY), active);
  }

  @override
  bool shouldRepaint(covariant _TemperatureRangePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.globalLow != globalLow ||
      oldDelegate.globalHigh != globalHigh;
}

class _WeatherSummary extends StatelessWidget {
  const _WeatherSummary({
    required this.day,
    required this.snapshot,
    required this.onTap,
  });

  final WeatherDaily day;
  final WeatherSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = _firstHourly(_hourlyForDay(snapshot, day));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 3),
        child: Row(
          children: [
            Icon(_weatherIcon(day.code), size: 17),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_weatherConditionJapanese(day.code)}  ${day.high.round()}°/${day.low.round()}°',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              '${day.precipitationProbability}% · ${day.precipitation.toStringAsFixed(1)}mm${current == null ? '' : ' · ${current.windSpeed.round()}km/h'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherDetails extends StatelessWidget {
  const _WeatherDetails({
    required this.day,
    required this.snapshot,
    required this.hourlyVisible,
    required this.hourlyAvailable,
    required this.onToggleHourly,
  });

  final WeatherDaily day;
  final WeatherSnapshot snapshot;
  final bool hourlyVisible;
  final bool hourlyAvailable;
  final VoidCallback onToggleHourly;

  @override
  Widget build(BuildContext context) {
    final forecast = _representativeHourly(_hourlyForDay(snapshot, day));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '気象詳細',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 300;
              return Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TelemetryGrid(
                        columns: twoColumns ? 2 : 1,
                        children: [
                          _TelemetryModule(
                            label: '体感温度',
                            value: forecast == null
                                ? '--'
                                : '${forecast.apparentTemperature.round()}°',
                            detail: forecast == null
                                ? '--'
                                : '気温 ${forecast.temperature.round()}°',
                            icon: Icons.thermostat_outlined,
                          ),
                          _TelemetryModule(
                            label: '湿度',
                            value: forecast == null
                                ? '--'
                                : '${forecast.humidity}%',
                            detail: forecast?.dewPoint == null
                                ? '露点 --'
                                : '露点 ${forecast!.dewPoint!.round()}°',
                            icon: Icons.water_drop_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _TelemetryGrid(
                        columns: twoColumns ? 2 : 1,
                        children: [
                          _TelemetryModule(
                            label: '降水',
                            value: '${day.precipitation.toStringAsFixed(1)} mm',
                            detail: '${day.precipitationProbability}%',
                            icon: Icons.umbrella_outlined,
                          ),
                          _TelemetryModule(
                            label: '視程',
                            value: forecast?.visibility == null
                                ? '--'
                                : _visibilityValue(forecast!.visibility!),
                            detail: forecast?.visibility == null
                                ? '--'
                                : _visibilityCategoryJapanese(
                                    forecast!.visibility!,
                                  ),
                            icon: Icons.visibility_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _TelemetryGrid(
                        columns: twoColumns ? 2 : 1,
                        children: [
                          _UvTelemetryModule(
                            value: day.uvIndexMax ?? forecast?.uvIndex,
                          ),
                          _TelemetryModule(
                            label: '雲量',
                            value: forecast == null
                                ? '--'
                                : '${forecast.cloudCover}%',
                            detail: '',
                            icon: Icons.cloud_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _PressureTelemetryModule(
                        value: forecast?.surfacePressure,
                      ),
                      const SizedBox(height: 6),
                      _WindTelemetryModule(value: forecast),
                      const SizedBox(height: 6),
                      _SunTelemetryModule(
                        sunrise: day.sunrise,
                        sunset: day.sunset,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (hourlyAvailable)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggleHourly,
                icon: Icon(
                  hourlyVisible ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                ),
                label: Text(hourlyVisible ? '時間別予報を閉じる' : '時間別予報'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TelemetryGrid extends StatelessWidget {
  const _TelemetryGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 6.0;
      final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _TelemetryModule extends StatelessWidget {
  const _TelemetryModule({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .46),
        border: Border.all(color: scheme.primary.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [scheme.primary.withValues(alpha: .07), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: scheme.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (detail.isNotEmpty)
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class _WindTelemetryModule extends StatelessWidget {
  const _WindTelemetryModule({required this.value});
  final WeatherHourly? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final direction = value?.windDirection;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .46),
        border: Border.all(color: scheme.primary.withValues(alpha: .32)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(68, 68),
            painter: _WindCompassPainter(
              color: scheme.primary,
              direction: direction,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('風', style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value == null ? '--' : '${value!.windSpeed.round()} km/h',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  value == null
                      ? '突風 -- · 風向 --'
                      : '突風 ${value!.windGust.round()} km/h · ${_windDirection(direction)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WindCompassPainter extends CustomPainter {
  const _WindCompassPainter({required this.color, required this.direction});
  final Color color;
  final double? direction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final fine = Paint()
      ..color = color.withValues(alpha: .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, fine);
    for (var index = 0; index < 4; index++) {
      final angle = index * math.pi / 2 - math.pi / 2;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inner =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 4);
      canvas.drawLine(inner, outer, fine);
    }
    final textStyle = TextStyle(
      color: color.withValues(alpha: .8),
      fontSize: 8,
    );
    for (final item in <(String, Offset)>[
      ('N', Offset(0, -radius + 8)),
      ('E', Offset(radius - 8, 0)),
      ('S', Offset(0, radius - 8)),
      ('W', Offset(-radius + 8, 0)),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: item.$1, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        center + item.$2 - Offset(painter.width / 2, painter.height / 2),
      );
    }
    if (direction == null) return;
    final angle = direction! * math.pi / 180 - math.pi / 2;
    final tip =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 9);
    final pointer = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, pointer);
    canvas.drawCircle(tip, 2.2, pointer);
    canvas.drawCircle(center, 2, pointer);
  }

  @override
  bool shouldRepaint(covariant _WindCompassPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}

class _UvTelemetryModule extends StatelessWidget {
  const _UvTelemetryModule({required this.value});
  final double? value;

  @override
  Widget build(BuildContext context) {
    return _TelemetryModule(
      label: 'UV指数',
      value: value == null ? '--' : value!.toStringAsFixed(0),
      detail: value == null ? '--' : _uvCategoryJapanese(value!),
      icon: Icons.wb_sunny_outlined,
    );
  }
}

class _SunTelemetryModule extends StatelessWidget {
  const _SunTelemetryModule({required this.sunrise, required this.sunset});
  final String sunrise;
  final String sunset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .46),
        border: Border.all(color: scheme.primary.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [scheme.primary.withValues(alpha: .07), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_twilight_outlined, color: scheme.primary, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('日の出・日の入り', style: Theme.of(context).textTheme.labelSmall),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      '日の出 ${_shortTime(sunrise)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '日の入り ${_shortTime(sunset)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(86, 38),
            painter: _SolarArcPainter(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _PressureTelemetryModule extends StatelessWidget {
  const _PressureTelemetryModule({required this.value});
  final double? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .46),
        border: Border.all(color: scheme.primary.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(78, 42),
            painter: _PressureGaugePainter(color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('気圧', style: Theme.of(context).textTheme.labelSmall),
              Text(
                value == null ? '--' : '${value!.round()} hPa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PressureGaugePainter extends CustomPainter {
  const _PressureGaugePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final bounds = Rect.fromLTWH(4, 4, size.width - 8, size.width - 8);
    canvas.drawArc(bounds, math.pi, math.pi, false, paint);
    final pointer = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height - 2);
    canvas.drawLine(
      center,
      Offset(size.width * .67, size.height * .38),
      pointer,
    );
  }

  @override
  bool shouldRepaint(covariant _PressureGaugePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SolarArcPainter extends CustomPainter {
  const _SolarArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final arc = Paint()
      ..color = color.withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final bounds = Rect.fromLTWH(4, 5, size.width - 8, size.height * 1.6);
    canvas.drawArc(bounds, math.pi, math.pi, false, arc);
    final horizon = Paint()
      ..color = color.withValues(alpha: .25)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(4, size.height - 3),
      Offset(size.width - 4, size.height - 3),
      horizon,
    );
    canvas.drawCircle(Offset(size.width / 2, 8), 2.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SolarArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WeatherHourlyTimeline extends StatelessWidget {
  const _WeatherHourlyTimeline({required this.values});

  final List<WeatherHourly> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '時間別予報',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in values) _WeatherHourlyCell(value: value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherHourlyCell extends StatelessWidget {
  const _WeatherHourlyCell({required this.value});
  final WeatherHourly value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .4),
        border: Border.all(color: scheme.primary.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _hourJapanese(value.time),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Icon(_weatherIcon(value.code), size: 20, color: scheme.primary),
          const SizedBox(height: 3),
          Text(
            '${value.temperature.round()}°',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '体感 ${value.apparentTemperature.round()}°',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Text(
            '降水 ${value.precipitationProbability}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Text(
            '風 ${value.windSpeed.round()} km/h',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

List<WeatherHourly> _hourlyForDay(WeatherSnapshot snapshot, WeatherDaily day) =>
    snapshot.hourly
        .where((value) => value.time.startsWith('${day.date}T'))
        .toList(growable: false);

WeatherHourly? _firstHourly(List<WeatherHourly> values) =>
    values.isEmpty ? null : values.first;

WeatherHourly? _representativeHourly(List<WeatherHourly> values) {
  for (final value in values) {
    if (value.time.endsWith('T12:00')) return value;
  }
  return _firstHourly(values);
}

String _windDirection(double? degrees) {
  if (degrees == null) return '風向 --';
  const labels = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];
  final index = ((degrees % 360) / 22.5).round() % labels.length;
  return '${labels[index]} / ${degrees.round()}°';
}

String _visibilityValue(double meters) =>
    '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';

String _visibilityCategoryJapanese(double meters) => switch (meters) {
  >= 20000 => '非常に良好',
  >= 10000 => '良好',
  >= 4000 => '普通',
  _ => '低い',
};

String _uvCategoryJapanese(double value) => switch (value) {
  <= 2 => '低い',
  <= 5 => '中程度',
  <= 7 => '高い',
  <= 10 => '非常に高い',
  _ => '極端に高い',
};

class _OpenMeteoAttribution extends StatelessWidget {
  const _OpenMeteoAttribution();

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: openWeatherProviderSite,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
    ),
    child: const Text('Weather data: Open-Meteo'),
  );
}

class _TimelineEntry extends StatefulWidget {
  const _TimelineEntry({
    required this.record,
    required this.onTap,
    required this.onMove,
    this.onReminderToggle,
  });
  final ScheduleRecord record;
  final VoidCallback onTap;
  final ValueChanged<int> onMove;
  final VoidCallback? onReminderToggle;
  @override
  State<_TimelineEntry> createState() => _TimelineEntryState();
}

class _TimelineEntryState extends State<_TimelineEntry> {
  Offset? _origin;
  int _previewMinutes = 0;
  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final timed = record.startTime != null && !record.allDay;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: timed
          ? (event) => setState(() => _origin = event.globalPosition)
          : null,
      onLongPressMoveUpdate: timed
          ? (event) {
              final origin = _origin;
              if (origin == null) return;
              setState(
                () => _previewMinutes =
                    ((event.globalPosition.dy - origin.dy) / 12).round() * 15,
              );
            }
          : null,
      onLongPressEnd: timed
          ? (_) {
              final shift = _previewMinutes;
              setState(() {
                _origin = null;
                _previewMinutes = 0;
              });
              if (shift != 0) widget.onMove(shift);
            }
          : null,
      child: Semantics(
        label:
            '${record.kind.name} ${record.title} ${record.startTime ?? 'untimed'}',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  record.allDay ? 'ALL DAY' : record.startTime ?? 'UNTIMED',
                ),
              ),
              Column(
                children: [
                  Icon(
                    record.kind == ScheduleEntryKind.reminder
                        ? (record.completed
                              ? Icons.check_circle
                              : Icons.diamond_outlined)
                        : Icons.circle,
                    size: 14,
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .5),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.title),
                    Text(
                      '${record.type.name.toUpperCase()}${record.endTime == null ? '' : '  ${record.startTime}–${record.endTime}'}${_previewMinutes == 0 ? '' : '  → ${_previewMinutes > 0 ? '+' : ''}${_previewMinutes}m'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (widget.onReminderToggle != null)
                IconButton(
                  icon: Icon(
                    record.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  onPressed: widget.onReminderToggle,
                ),
            ],
          ),
        ),
      ),
    );
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
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 180) onPrevious();
        if ((details.primaryVelocity ?? 0) < -180) onNext();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface.withValues(alpha: .12),
              Colors.transparent,
            ],
          ),
        ),
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
                    '${month.year}\n${_monthName(month.month)}',
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
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'SCHEDULE │ REMINDER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .8),
                ),
              ),
            ),
            const SizedBox(height: 4),
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
                final scheduleCount = schedules
                    .where((value) => value.kind == ScheduleEntryKind.schedule)
                    .length;
                final reminderCount = schedules
                    .where((value) => value.kind == ScheduleEntryKind.reminder)
                    .length;
                final isToday = _sameDay(date, DateTime.now());
                final isSelected = _sameDay(date, selected);
                return InkWell(
                  onTap: () => onSelect(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : isToday
                          ? Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: .7),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${date.day}'),
                            if (isToday)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(
                                  Icons.circle,
                                  size: 4,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                          ],
                        ),
                        if (schedules.isNotEmpty)
                          Text(
                            '${scheduleCount == 0 ? '–' : scheduleCount}│${reminderCount == 0 ? '–' : reminderCount}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _monthName(int month) => const [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
][month - 1];

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
              _DurationControl(label: 'BREAK', controller: _break),
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

class _TimeControl extends StatefulWidget {
  const _TimeControl({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  State<_TimeControl> createState() => _TimeControlState();
}

class _TimeControlState extends State<_TimeControl> {
  void _step(int delta) {
    final value = _parseClock(widget.controller.text) ?? 0;
    widget.controller.text = _formatClock((value + delta) % 1440);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: Theme.of(context).textTheme.labelSmall),
      Row(
        children: [
          IconButton(
            onPressed: () => _step(-15),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final result = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  barrierColor: Colors.black.withValues(alpha: .76),
                  builder: (_) => _ClockDial(initial: widget.controller.text),
                );
                if (result != null) {
                  widget.controller.text = result;
                  setState(() {});
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  widget.controller.text.isEmpty
                      ? 'NOT SET'
                      : widget.controller.text,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          IconButton(onPressed: () => _step(15), icon: const Icon(Icons.add)),
        ],
      ),
      const Divider(height: 1),
    ],
  );
}

class _ClockDial extends StatefulWidget {
  const _ClockDial({required this.initial});
  final String initial;
  @override
  State<_ClockDial> createState() => _ClockDialState();
}

class _ClockDialState extends State<_ClockDial> {
  late int _hour = (int.tryParse(widget.initial.split(':').first) ?? 0).clamp(
    0,
    23,
  );
  late int _minute = widget.initial.contains(':')
      ? (int.tryParse(widget.initial.split(':').last) ?? 0).clamp(0, 59)
      : 0;
  bool _minutes = false;
  ClockDialHourRing? _dragHourRing;
  int? _hourBeforeDrag;
  int? _minuteBeforeDrag;
  bool _hourGestureHasSelection = false;
  double? _dragHandAngle;

  void _selectHour(Offset position, Size size) {
    final offset = position - size.center(Offset.zero);
    final selection = clockDialHourSelectionForOffset(
      offset: offset,
      dialRadius: size.shortestSide / 2,
      previousRing: _dragHourRing ?? clockDialHourRingForHour(_hour),
    );
    if (selection == null) return;
    setState(() {
      _hour = selection.hour;
      _dragHourRing = selection.ring;
      _hourGestureHasSelection = true;
      _dragHandAngle = clockDialHandAngleForOffset(
        offset: offset,
        dialRadius: size.shortestSide / 2,
      );
    });
  }

  void _selectMinute(Offset position, Size size) {
    final offset = position - size.center(Offset.zero);
    final minute = clockDialMinuteForOffset(
      offset: offset,
      dialRadius: size.shortestSide / 2,
    );
    if (minute == null) return;
    setState(() {
      _minute = minute;
      _dragHandAngle = clockDialHandAngleForOffset(
        offset: offset,
        dialRadius: size.shortestSide / 2,
      );
    });
  }

  void _completeHourSelection() {
    if (!_hourGestureHasSelection) {
      _hourBeforeDrag = null;
      return;
    }
    setState(() {
      _dragHourRing = null;
      _hourBeforeDrag = null;
      _hourGestureHasSelection = false;
      _dragHandAngle = null;
      _minutes = true;
    });
  }

  void _beginHourGesture() {
    _hourBeforeDrag = _hour;
    _hourGestureHasSelection = false;
    _dragHandAngle = null;
  }

  void _beginMinuteGesture() {
    _minuteBeforeDrag = _minute;
    _dragHandAngle = null;
  }

  void _completeMinuteGesture() => setState(() {
    _dragHandAngle = null;
    _minuteBeforeDrag = null;
  });

  void _cancelHourGesture() {
    final original = _hourBeforeDrag;
    if (original == null) return;
    setState(() {
      _hour = original;
      _dragHourRing = null;
      _hourBeforeDrag = null;
      _hourGestureHasSelection = false;
      _dragHandAngle = null;
    });
  }

  void _cancelMinuteGesture() {
    final original = _minuteBeforeDrag;
    if (original == null) return;
    setState(() {
      _minute = original;
      _minuteBeforeDrag = null;
      _dragHandAngle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHigh.withValues(alpha: .94),
                scheme.surface.withValues(alpha: .91),
                scheme.surfaceContainerLow.withValues(alpha: .95),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(22),
            ),
            border: Border.all(color: scheme.primary.withValues(alpha: .42)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .32),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 9,
                left: 22,
                right: 22,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        scheme.primary.withValues(alpha: .68),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ClockTelemetry(
                      hour: _hour,
                      minute: _minute,
                      minutes: _minutes,
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // A modal selector receives less vertical room than the
                        // full-screen editor behind it. Keep the complete
                        // instrument, including its action rail, visible on
                        // compact phone viewports rather than clipping the
                        // lower circumference and controls.
                        final maximumDialSize = constraints.maxWidth <= 320
                            ? 200.0
                            : constraints.maxWidth <= 400
                            ? 220.0
                            : 310.0;
                        final dialSize = math.min(
                          maximumDialSize,
                          constraints.maxWidth,
                        );
                        return SizedBox(
                          width: dialSize,
                          height: dialSize,
                          child: _DirectClockFace(
                            minutes: _minutes,
                            hour: _hour,
                            minute: _minute,
                            hourRing:
                                _dragHourRing ??
                                clockDialHourRingForHour(_hour),
                            dragHandAngle: _dragHandAngle,
                            onHourGestureStarted: _beginHourGesture,
                            onHourChanged: _selectHour,
                            onHourCompleted: _completeHourSelection,
                            onHourCancelled: _cancelHourGesture,
                            onMinuteGestureStarted: _beginMinuteGesture,
                            onMinuteChanged: _selectMinute,
                            onMinuteCompleted: _completeMinuteGesture,
                            onMinuteCancelled: _cancelMinuteGesture,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _ClockInstrumentAction(
                          label: 'CANCEL',
                          icon: Icons.close,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _ClockInstrumentAction(
                          label: 'HOUR',
                          icon: Icons.access_time_outlined,
                          active: !_minutes,
                          onTap: () => setState(() => _minutes = false),
                        ),
                        const SizedBox(width: 8),
                        _ClockInstrumentAction(
                          label: 'DONE',
                          icon: Icons.check,
                          active: true,
                          onTap: () => Navigator.pop(
                            context,
                            '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockTelemetry extends StatelessWidget {
  const _ClockTelemetry({
    required this.hour,
    required this.minute,
    required this.minutes,
  });

  final int hour;
  final int minute;
  final bool minutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.headlineMedium;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(
                color: scheme.primary.withValues(alpha: .28),
              ),
            ),
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                scheme.primary.withValues(alpha: .07),
                Colors.transparent,
              ],
            ),
          ),
          child: RichText(
            text: TextSpan(
              style: base?.copyWith(letterSpacing: 1.2),
              children: [
                TextSpan(
                  text: hour.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: !minutes
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: .54),
                  ),
                ),
                TextSpan(
                  text: ' : ',
                  style: TextStyle(
                    color: scheme.primary.withValues(alpha: .58),
                  ),
                ),
                TextSpan(
                  text: minute.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: minutes
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: .54),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          minutes ? 'INSTRUMENT / SET MINUTE' : 'INSTRUMENT / SET HOUR',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.25,
            color: scheme.primary.withValues(alpha: .82),
          ),
        ),
      ],
    );
  }
}

class _ClockInstrumentAction extends StatelessWidget {
  const _ClockInstrumentAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minWidth: 70, minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.primary.withValues(alpha: active ? .68 : .28),
                ),
                bottom: BorderSide(
                  color: scheme.primary.withValues(alpha: active ? .46 : .18),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: active
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: .66),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0,
                    color: active
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: .78),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectClockFace extends StatelessWidget {
  const _DirectClockFace({
    required this.minutes,
    required this.hour,
    required this.minute,
    required this.hourRing,
    required this.dragHandAngle,
    required this.onHourGestureStarted,
    required this.onHourChanged,
    required this.onHourCompleted,
    required this.onHourCancelled,
    required this.onMinuteGestureStarted,
    required this.onMinuteChanged,
    required this.onMinuteCompleted,
    required this.onMinuteCancelled,
  });

  final bool minutes;
  final int hour;
  final int minute;
  final ClockDialHourRing hourRing;
  final double? dragHandAngle;
  final VoidCallback onHourGestureStarted;
  final void Function(Offset position, Size size) onHourChanged;
  final VoidCallback onHourCompleted;
  final VoidCallback onHourCancelled;
  final VoidCallback onMinuteGestureStarted;
  final void Function(Offset position, Size size) onMinuteChanged;
  final VoidCallback onMinuteCompleted;
  final VoidCallback onMinuteCancelled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size.square(constraints.biggest.shortestSide);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (minutes) {
            onMinuteChanged(details.localPosition, size);
            onMinuteCompleted();
          } else {
            onHourChanged(details.localPosition, size);
            onHourCompleted();
          }
        },
        onPanStart: (details) {
          if (minutes) {
            onMinuteGestureStarted();
            onMinuteChanged(details.localPosition, size);
          } else {
            onHourGestureStarted();
            onHourChanged(details.localPosition, size);
          }
        },
        onPanUpdate: (details) {
          if (minutes) {
            onMinuteChanged(details.localPosition, size);
          } else {
            onHourChanged(details.localPosition, size);
          }
        },
        onPanEnd: (_) {
          if (minutes) {
            onMinuteCompleted();
          } else {
            onHourCompleted();
          }
        },
        onPanCancel: () {
          if (minutes) {
            onMinuteCancelled();
          } else {
            onHourCancelled();
          }
        },
        child: CustomPaint(
          size: size,
          painter: _DirectClockFacePainter(
            minutes: minutes,
            hour: hour,
            minute: minute,
            hourRing: hourRing,
            dragHandAngle: dragHandAngle,
            color: Theme.of(context).colorScheme.primary,
          ),
          child: IgnorePointer(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (minutes)
                  for (var direction = 0; direction < 12; direction++)
                    _DialNumber(
                      value: direction * 5,
                      direction: direction,
                      radiusFactor: .67,
                      selected: minute == direction * 5,
                    )
                else ...[
                  for (var direction = 0; direction < 12; direction++)
                    _DialNumber(
                      value: direction == 0 ? 0 : direction + 12,
                      direction: direction,
                      radiusFactor: .70,
                      secondary: true,
                      selected:
                          hourRing == ClockDialHourRing.outer &&
                          hour == (direction == 0 ? 0 : direction + 12),
                    ),
                  for (var direction = 0; direction < 12; direction++)
                    _DialNumber(
                      value: direction == 0 ? 12 : direction,
                      direction: direction,
                      radiusFactor: .47,
                      selected:
                          hourRing == ClockDialHourRing.inner &&
                          hour == (direction == 0 ? 12 : direction),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _DialNumber extends StatelessWidget {
  const _DialNumber({
    required this.value,
    required this.direction,
    required this.radiusFactor,
    required this.selected,
    this.secondary = false,
  });

  final int value;
  final int direction;
  final double radiusFactor;
  final bool selected;
  final bool secondary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final radius = constraints.biggest.shortestSide / 2 * radiusFactor;
      final angle = direction / 12 * math.pi * 2 - math.pi / 2;
      final color = Theme.of(context).colorScheme.primary;
      return Transform.translate(
        offset: Offset(radius * math.cos(angle), radius * math.sin(angle)),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(
              value.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: secondary ? .50 : .84,
                      ),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                shadows: selected
                    ? [
                        Shadow(
                          color: color.withValues(alpha: .52),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DirectClockFacePainter extends CustomPainter {
  const _DirectClockFacePainter({
    required this.minutes,
    required this.hour,
    required this.minute,
    required this.hourRing,
    required this.dragHandAngle,
    required this.color,
  });

  final bool minutes;
  final int hour;
  final int minute;
  final ClockDialHourRing hourRing;
  final double? dragHandAngle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final dialRadius = size.shortestSide / 2;
    final outerRadius = dialRadius * .90;
    final outerNumeralRadius = dialRadius * .70;
    final innerNumeralRadius = dialRadius * .47;
    final selectedDirection = minutes
        ? minute / 5
        : (hour == 0 || hour == 12 ? 0 : hour % 12);
    final selectedAngle = selectedDirection / 12 * math.pi * 2 - math.pi / 2;
    final angle = dragHandAngle ?? selectedAngle;
    final handRadius = minutes
        ? dialRadius * .68
        : (hourRing == ClockDialHourRing.outer
              ? dialRadius * .54
              : dialRadius * .39);
    final endpoint =
        center +
        Offset(handRadius * math.cos(angle), handRadius * math.sin(angle));
    final faceFill = Paint()
      ..color = color.withValues(alpha: .025)
      ..style = PaintingStyle.fill;
    final trace = Paint()
      ..color = color.withValues(alpha: .32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, outerRadius, faceFill);
    canvas.drawCircle(center, outerRadius, trace);
    if (!minutes) {
      _paintHourTicks(canvas, center, dialRadius);
    } else {
      _paintMinuteTicks(canvas, center, dialRadius);
    }
    final hand = Paint()
      ..color = color.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = minutes ? 2.0 : 3.5;
    canvas.drawLine(center, endpoint, hand);
    _paintHandTip(canvas, endpoint, angle, minutes);
    _paintPivot(canvas, center);
    final focusRadius = minutes
        ? dialRadius * .67
        : (hourRing == ClockDialHourRing.outer
              ? outerNumeralRadius
              : innerNumeralRadius);
    _paintSelectedArc(canvas, center, focusRadius, selectedAngle);
  }

  void _paintHandTip(
    Canvas canvas,
    Offset endpoint,
    double angle,
    bool minutes,
  ) {
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final tip = endpoint + direction * (minutes ? 5.5 : 4.5);
    final base = endpoint - direction * (minutes ? 3.0 : 3.5);
    final width = minutes ? 2.5 : 4.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + normal * width).dx, (base + normal * width).dy)
      ..lineTo((base - normal * width).dx, (base - normal * width).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .94));
  }

  void _paintHourTicks(Canvas canvas, Offset center, double radius) {
    for (var direction = 0; direction < 12; direction++) {
      final angle = direction / 12 * math.pi * 2 - math.pi / 2;
      final major = direction % 3 == 0;
      final outer = radius * .90;
      final inner = radius * (major ? .81 : .84);
      final paint = Paint()
        ..color = color.withValues(alpha: major ? .72 : .38)
        ..strokeWidth = major ? 1.8 : 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center + Offset(inner * math.cos(angle), inner * math.sin(angle)),
        center + Offset(outer * math.cos(angle), outer * math.sin(angle)),
        paint,
      );
    }
  }

  void _paintMinuteTicks(Canvas canvas, Offset center, double radius) {
    for (var index = 0; index < 60; index++) {
      final angle = index / 60 * math.pi * 2 - math.pi / 2;
      final major = index % 5 == 0;
      final outer = radius * .90;
      final inner = radius * (major ? .80 : .86);
      final paint = Paint()
        ..color = color.withValues(alpha: major ? .62 : .18)
        ..strokeWidth = major ? 1.3 : .6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center + Offset(inner * math.cos(angle), inner * math.sin(angle)),
        center + Offset(outer * math.cos(angle), outer * math.sin(angle)),
        paint,
      );
    }
  }

  void _paintPivot(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = color.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawCircle(center, 4, Paint()..color = color.withValues(alpha: .34));
    canvas.drawCircle(center, 2, Paint()..color = color.withValues(alpha: .96));
  }

  void _paintSelectedArc(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      angle - .12,
      .24,
      false,
      Paint()
        ..color = color.withValues(alpha: .70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DirectClockFacePainter old) =>
      old.minutes != minutes ||
      old.hour != hour ||
      old.minute != minute ||
      old.hourRing != hourRing ||
      old.dragHandAngle != dragHandAngle ||
      old.color != color;
}

class _DurationControl extends StatefulWidget {
  const _DurationControl({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;
  @override
  State<_DurationControl> createState() => _DurationControlState();
}

class _DurationControlState extends State<_DurationControl> {
  void _step(int delta) {
    final value = (_parseClock(widget.controller.text) ?? 60) + delta;
    widget.controller.text = _formatClock(value.clamp(0, 720));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: Theme.of(context).textTheme.labelSmall),
      Row(
        children: [
          IconButton(
            onPressed: () => _step(-15),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Text(
              widget.controller.text.isEmpty ? '01:00' : widget.controller.text,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(onPressed: () => _step(15), icon: const Icon(Icons.add)),
        ],
      ),
      const Divider(height: 1),
    ],
  );
}

int? _parseClock(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || minute < 0 || minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}

String _formatClock(int total) =>
    '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String _key(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekdayJapanese(int weekday) =>
    const ['月', '火', '水', '木', '金', '土', '日'][weekday - 1];

String _shortTime(String value) {
  final separator = value.indexOf('T');
  return separator == -1
      ? value
      : value.substring(separator + 1, separator + 6);
}

String _hourJapanese(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? _shortTime(value) : '${parsed.hour}時';
}

String _weatherConditionJapanese(int code) =>
    switch (weatherConditionForCode(code)) {
      WeatherCondition.clear || WeatherCondition.mainlyClear => '晴れ',
      WeatherCondition.partlyCloudy => '晴れ時々曇り',
      WeatherCondition.cloudy => '曇り',
      WeatherCondition.fog => '霧',
      WeatherCondition.drizzle => '霧雨',
      WeatherCondition.rain || WeatherCondition.showers => '雨',
      WeatherCondition.snow => '雪',
      WeatherCondition.thunder => '雷雨',
      WeatherCondition.unknown => '不明',
    };

IconData _weatherIcon(int code) => switch (weatherConditionForCode(code)) {
  WeatherCondition.clear ||
  WeatherCondition.mainlyClear => Icons.wb_sunny_outlined,
  WeatherCondition.partlyCloudy ||
  WeatherCondition.cloudy => Icons.cloud_outlined,
  WeatherCondition.fog => Icons.foggy,
  WeatherCondition.drizzle ||
  WeatherCondition.rain ||
  WeatherCondition.showers => Icons.umbrella_outlined,
  WeatherCondition.snow => Icons.ac_unit,
  WeatherCondition.thunder => Icons.thunderstorm_outlined,
  WeatherCondition.unknown => Icons.help_outline,
};

String _displayFetchedAt(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
