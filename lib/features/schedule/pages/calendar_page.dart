import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
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
import '../weather_forecast_summary.dart';

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
  // The Weather surface has a master disclosure, while its console sections
  // retain their own state during a Calendar session. Keeping these concerns
  // separate prevents a date selection from implicitly changing a section.
  bool _weatherExpanded = false;
  bool _weatherHourlyExpanded = true;
  bool _weatherDetailsExpanded = false;
  bool _weatherSevenDayExpanded = true;

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
    setState(() => _weatherExpanded = false);
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
    });
    _load();
  }

  void _shiftWeatherDate(int direction) {
    final days =
        _weatherSnapshot?.daily.take(7).toList(growable: false) ??
        const <WeatherDaily>[];
    final index = days.indexWhere((day) => day.date == _selectedKey);
    if (index < 0) return;
    final next = (index + direction).clamp(0, days.length - 1);
    if (next == index) return;
    _selectWeatherDate(days[next].date);
  }

  void _toggleWeatherDisclosure() =>
      setState(() => _weatherExpanded = !_weatherExpanded);

  /// Calendar actions retain their normal callback path; this only folds the
  /// contextual Weather layer before that action proceeds.
  void _collapseWeatherForCalendarAction() {
    if (_weatherExpanded) {
      setState(() => _weatherExpanded = false);
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
                  expanded: _weatherExpanded,
                  hourlyExpanded: _weatherHourlyExpanded,
                  detailsExpanded: _weatherDetailsExpanded,
                  sevenDayExpanded: _weatherSevenDayExpanded,
                  onSettings: _openWeatherSettings,
                  onRefresh: () => _loadWeather(forceRefresh: true),
                  onSelectDate: _selectWeatherDate,
                  onSwipeDate: _shiftWeatherDate,
                  onSwipeLocation: _switchWeatherLocation,
                  onToggleDisclosure: _toggleWeatherDisclosure,
                  onToggleHourly: () => setState(
                    () => _weatherHourlyExpanded = !_weatherHourlyExpanded,
                  ),
                  onToggleDetails: () => setState(
                    () => _weatherDetailsExpanded = !_weatherDetailsExpanded,
                  ),
                  onToggleSevenDay: () => setState(
                    () => _weatherSevenDayExpanded = !_weatherSevenDayExpanded,
                  ),
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
    required this.expanded,
    required this.hourlyExpanded,
    required this.detailsExpanded,
    required this.sevenDayExpanded,
    required this.onSettings,
    required this.onRefresh,
    required this.onSelectDate,
    required this.onSwipeDate,
    required this.onSwipeLocation,
    required this.onToggleDisclosure,
    required this.onToggleHourly,
    required this.onToggleDetails,
    required this.onToggleSevenDay,
  });

  final WeatherLocationPreferences preferences;
  final WeatherSnapshot? snapshot;
  final String selectedDate;
  final bool loading;
  final bool stale;
  final String? error;
  final bool refreshing;
  final bool expanded;
  final bool hourlyExpanded;
  final bool detailsExpanded;
  final bool sevenDayExpanded;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<int> onSwipeDate;
  final ValueChanged<int> onSwipeLocation;
  final VoidCallback onToggleDisclosure;
  final VoidCallback onToggleHourly;
  final VoidCallback onToggleDetails;
  final VoidCallback onToggleSevenDay;

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
                  expanded: expanded,
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
                      onSwipeDate: onSwipeDate,
                      onTap: expanded
                          ? () => _showDailyForecastDetail(
                              context,
                              selected,
                              snapshot!,
                            )
                          : onToggleDisclosure,
                    ),
                  if (expanded && selected != null) ...[
                    const SizedBox(height: 5),
                    _WeatherConsoleSectionHeader(
                      title: '時間別予報',
                      expanded: hourlyExpanded,
                      onTap: onToggleHourly,
                    ),
                    if (hourlyExpanded)
                      _WeatherHourlyTimeline(day: selected, values: hourly),
                    const SizedBox(height: 6),
                    _WeatherConsoleSectionHeader(
                      title: '気象詳細',
                      expanded: detailsExpanded,
                      onTap: onToggleDetails,
                    ),
                    if (detailsExpanded)
                      _WeatherDetails(day: selected, snapshot: snapshot!),
                    const SizedBox(height: 6),
                    _WeatherConsoleSectionHeader(
                      title: '週間天気予報',
                      expanded: sevenDayExpanded,
                      onTap: onToggleSevenDay,
                    ),
                    if (sevenDayExpanded)
                      _WeatherForecastList(
                        values: snapshot!.daily.take(7).toList(growable: false),
                        snapshot: snapshot!,
                        selectedDate: selectedDate,
                        onSelectDate: onSelectDate,
                      ),
                  ],
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
                ],
              ],
            ),
          ),
          if (snapshot != null && expanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 5, 12, 0),
              child: _OpenMeteoAttribution(),
            ),
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
    required this.expanded,
    required this.loading,
    required this.canRefresh,
    required this.onRefresh,
    required this.onSettings,
    required this.onSwitchLocation,
    required this.onToggleDisclosure,
  });

  final WeatherLocationPreferences preferences;
  final WeatherLocation? location;
  final bool expanded;
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
                  Text(
                    '天気',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      weatherHeaderLocationText(location?.displayName),
                      key: const ValueKey('weather-header-location'),
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
                    !expanded ? Icons.expand_more : Icons.expand_less,
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

/// Header space belongs to the active city/area. Saved locations may carry a
/// wider regional suffix for settings, but that suffix is intentionally not
/// allowed to turn the primary name into a misleading partial truncation.
String weatherHeaderLocationText(String? displayName) {
  if (displayName == null || displayName.trim().isEmpty) return '場所未設定';
  return displayName.split(RegExp(r'\s*/\s*|\s*,\s*')).first.trim();
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

class _WeatherConsoleSectionHeader extends StatelessWidget {
  const _WeatherConsoleSectionHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      expanded: expanded,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    letterSpacing: .8,
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherForecastList extends StatelessWidget {
  const _WeatherForecastList({
    required this.values,
    required this.snapshot,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final List<WeatherDaily> values;
  final WeatherSnapshot snapshot;
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
                snapshot: snapshot,
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
    required this.snapshot,
    required this.selected,
    required this.today,
    required this.globalLow,
    required this.globalHigh,
    required this.onTap,
  });

  final WeatherDaily value;
  final WeatherSnapshot snapshot;
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
        onTap: () {
          // A new date selection is a state change only. Re-tapping the
          // already selected row is the explicit request for its forecast.
          if (!weatherForecastRowOpensDetail(selected: selected)) {
            onTap();
            return;
          }
          _showDailyForecastDetail(context, value, snapshot);
        },
        // Detail peek deliberately bypasses selection. This lets a user read
        // another day without moving the Selected Day or Calendar authority.
        onLongPress: () => _showDailyForecastDetail(context, value, snapshot),
        child: Container(
          key: ValueKey('weather-forecast-row-${value.date}'),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? scheme.surface.withValues(alpha: .30) : null,
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: .78)
                  : scheme.primary.withValues(alpha: .18),
            ),
            borderRadius: BorderRadius.circular(7),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: .12),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: .10),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final railWidth = weatherTemperatureRailWidth(
                constraints.maxWidth * .68,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(today ? '今日' : _weekdayJapanese(date.weekday)),
                        Text(
                          '${date.month}/${date.day}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 3),
                        Icon(
                          _weatherIcon(value.code),
                          color: scheme.primary,
                          size: 27,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${value.high.round()}°',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '最高 ${value.high.round()}° / 最低 ${value.low.round()}°',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '最低 ${value.low.round()}°',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SizedBox(
                                key: ValueKey(
                                  'weather-temperature-rail-${value.date}',
                                ),
                                width: railWidth,
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
                            const SizedBox(width: 6),
                            Text(
                              '最高 ${value.high.round()}°',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _weatherConditionJapanese(value.code),
                                key: ValueKey(
                                  'weather-forecast-secondary-${value.date}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurface.withValues(
                                        alpha: .72,
                                      ),
                                    ),
                              ),
                            ),
                            Text(
                              '☔ ${value.precipitationProbability}%',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: scheme.secondary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${value.precipitation.toStringAsFixed(1)}mm',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right,
                              key: ValueKey(
                                'weather-forecast-detail-${value.date}',
                              ),
                              size: 15,
                              color: scheme.primary.withValues(alpha: .48),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
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

/// Keeps the temperature rail within its own logical column. The 208px
/// reservation covers day/icon, low/high values, precipitation, and explicit
/// gaps so the painter cannot draw beneath numeric telemetry.
double weatherTemperatureRailWidth(double rowWidth) =>
    (rowWidth - 208).clamp(44.0, 250.0).toDouble();

/// A row owns both its date selection and its visual rail. A different date
/// never opens a surface; a second, deliberate tap requests the daily detail.
bool weatherForecastRowOpensDetail({required bool selected}) => selected;

/// Reuses the existing forecast-intelligence output for the compact weekly
/// daypart cue. It never derives a new precipitation claim from raw values.
String? weatherForecastPeakPrecipitationTiming(WeatherForecastSummary summary) {
  final timing = RegExp(
    r'最大降水確率\s*\d+%（([^）]+)）',
  ).firstMatch(summary.supporting.join(' '));
  return timing?.group(1);
}

Future<void> _showDailyForecastDetail(
  BuildContext context,
  WeatherDaily day,
  WeatherSnapshot snapshot,
) {
  final date = DateTime.parse(day.date);
  final hourly = _hourlyForDay(snapshot, day);
  final forecast = _representativeHourly(hourly);
  final summary = WeatherForecastSummaryEngine.summarize(
    day: day,
    hourly: hourly,
  );
  final observationLabel = forecast == null
      ? null
      : '${DateTime.parse(forecast.time).hour}時の予報';
  final uvValue = day.uvIndexMax ?? forecast?.uvIndex;
  final peakTiming = day.precipitation > 0
      ? weatherForecastPeakPrecipitationTiming(summary)
      : null;
  return _showWeatherExplanation(
    context,
    _WeatherExplanation(
      title: '${date.month}月${date.day}日（${_weekdayJapanese(date.weekday)}）',
      value:
          '${_weatherConditionJapanese(day.code)} · 最低気温 ${day.low.round()}° / 最高気温 ${day.high.round()}° · 降水確率 ${day.precipitationProbability}% · ${day.precipitation.toStringAsFixed(1)}mm',
      body: '日次の予報値と、表示可能な時間別予報値をまとめています。',
      forecastSummary: summary.primary,
      supportingData: summary.supporting,
      detailSections: [
        _WeatherDetailSection(
          title: '気温・降水',
          tonalStrength: .035,
          metrics: [
            _WeatherDetailMetric(label: '最低気温', value: '${day.low.round()}°'),
            _WeatherDetailMetric(label: '最高気温', value: '${day.high.round()}°'),
            if (forecast != null)
              _WeatherDetailMetric(
                label: '体感温度',
                value: '${forecast.apparentTemperature.round()}°',
                context:
                    '$observationLabel（気温 ${forecast.temperature.round()}°）',
              ),
            _WeatherDetailMetric(
              label: '降水量',
              value: '${day.precipitation.toStringAsFixed(1)}mm',
            ),
            _WeatherDetailMetric(
              label: '最大降水確率',
              value: '${day.precipitationProbability}%',
              context: peakTiming,
            ),
          ],
        ),
        if (forecast != null)
          _WeatherDetailSection(
            title: '風・湿度・露点',
            tonalStrength: .022,
            metrics: [
              _WeatherDetailMetric(
                label: '風向',
                value: _windDirection(forecast.windDirection),
                context: observationLabel,
              ),
              _WeatherDetailMetric(
                label: '風速',
                value: '${forecast.windSpeed.round()}km/h',
              ),
              _WeatherDetailMetric(
                label: '突風',
                value: '${forecast.windGust.round()}km/h',
              ),
              _WeatherDetailMetric(label: '湿度', value: '${forecast.humidity}%'),
              if (forecast.dewPoint != null)
                _WeatherDetailMetric(
                  label: '露点',
                  value: '${forecast.dewPoint!.round()}°',
                ),
            ],
          ),
        _WeatherDetailSection(
          title: '観測指標',
          tonalStrength: .035,
          metrics: [
            if (forecast?.visibility != null)
              _WeatherDetailMetric(
                label: '視程',
                value: _visibilityValue(forecast!.visibility!),
                context: _visibilityCategoryJapanese(forecast.visibility!),
              ),
            if (uvValue != null)
              _WeatherDetailMetric(
                label: 'UV指数',
                value: uvValue.toStringAsFixed(0),
                context: _uvCategoryJapanese(uvValue),
              ),
            if (forecast != null)
              _WeatherDetailMetric(
                label: '雲量',
                value: '${forecast.cloudCover}%',
              ),
            if (forecast?.surfacePressure != null)
              _WeatherDetailMetric(
                label: '気圧',
                value: '${forecast!.surfacePressure!.round()}hPa',
              ),
          ],
        ),
        _WeatherDetailSection(
          title: '日の出・日の入り',
          tonalStrength: .022,
          metrics: [
            _WeatherDetailMetric(label: '日の出', value: _shortTime(day.sunrise)),
            _WeatherDetailMetric(label: '日の入り', value: _shortTime(day.sunset)),
            _WeatherDetailMetric(
              label: 'DAYLIGHT',
              value: _daylightDuration(day.sunrise, day.sunset),
            ),
          ],
        ),
      ].where((section) => section.metrics.isNotEmpty).toList(growable: false),
    ),
  );
}

class _WeatherSummary extends StatelessWidget {
  const _WeatherSummary({
    required this.day,
    required this.snapshot,
    required this.onSwipeDate,
    required this.onTap,
  });

  final WeatherDaily day;
  final WeatherSnapshot snapshot;
  final ValueChanged<int> onSwipeDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hourly = _hourlyForDay(snapshot, day);
    final representative = _representativeHourly(hourly);
    final summary = WeatherForecastSummaryEngine.summarize(
      day: day,
      hourly: hourly,
    );
    final date = DateTime.parse(day.date);
    final isToday = _sameDay(date, DateTime.now());
    final tomorrow = _sameDay(
      date,
      DateTime.now().add(const Duration(days: 1)),
    );
    final label = isToday
        ? '今日'
        : tomorrow
        ? '明日'
        : '${date.month}/${date.day}（${_weekdayJapanese(date.weekday)}）';
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 120) onSwipeDate(velocity < 0 ? 1 : -1);
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          key: const ValueKey('weather-selected-day'),
          margin: const EdgeInsets.fromLTRB(12, 3, 12, 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.primary.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: .12),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label  ${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(_weatherIcon(day.code), color: scheme.primary, size: 23),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _weatherConditionJapanese(day.code),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text('最低 ${day.low.round()}° · 最高 ${day.high.round()}°'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '降水 ${day.precipitationProbability}% · ${day.precipitation.toStringAsFixed(1)}mm${representative == null ? '' : ' · 風 ${representative.windSpeed.round()}km/h'}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 5),
              Text(
                summary.primary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherDetails extends StatelessWidget {
  const _WeatherDetails({required this.day, required this.snapshot});

  final WeatherDaily day;
  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hourly = _hourlyForDay(snapshot, day);
    final forecast = _representativeHourly(hourly);
    final daySummary = WeatherForecastSummaryEngine.summarize(
      day: day,
      hourly: hourly,
    );
    final uvValue = day.uvIndexMax ?? forecast?.uvIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('カードをタップすると詳細を表示'),
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
                            microHud: _MicroHudKind.feelsLike,
                            instrumentValue: forecast == null
                                ? null
                                : forecast.apparentTemperature -
                                      forecast.temperature,
                            onExplain: () => _showWeatherExplanation(
                              context,
                              _WeatherExplanation(
                                title: '体感温度',
                                value: forecast == null
                                    ? '--'
                                    : '体感 ${forecast.apparentTemperature.round()}° / 気温 ${forecast.temperature.round()}°',
                                body: '気温だけでなく、湿度や風などを考慮した体感上の温度です。',
                                forecastSummary: forecast == null
                                    ? daySummary.primary
                                    : _feelsLikeSummary(forecast),
                                supportingData: daySummary.supporting,
                              ),
                            ),
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
                            microHud: _MicroHudKind.humidity,
                            instrumentValue: forecast?.humidity.toDouble(),
                            onExplain: () => _showWeatherExplanation(
                              context,
                              _WeatherExplanation(
                                title: '湿度・露点',
                                value: forecast == null
                                    ? '--'
                                    : '湿度 ${forecast.humidity}% / 露点 ${forecast.dewPoint?.round() ?? '--'}°',
                                body: '湿度は空気中の水分量の割合です。露点は空気中の水蒸気が結露し始める温度です。',
                                forecastSummary: forecast == null
                                    ? daySummary.primary
                                    : 'この日の湿度は ${forecast.humidity}%、露点は ${forecast.dewPoint?.round() ?? '--'}° の予報です。',
                                supportingData: daySummary.supporting,
                              ),
                            ),
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
                            microHud: _MicroHudKind.precipitation,
                            instrumentValue: day.precipitationProbability
                                .toDouble(),
                            onExplain: () => _showWeatherExplanation(
                              context,
                              _WeatherExplanation(
                                title: '降水',
                                value:
                                    '${day.precipitation.toStringAsFixed(1)} mm / ${day.precipitationProbability}%',
                                body: 'mmは予想される降水量、%はその日の降水確率を示します。',
                                forecastSummary:
                                    'この日の降水量は ${day.precipitation.toStringAsFixed(1)}mm、最大降水確率は ${day.precipitationProbability}% の予報です。',
                                supportingData: daySummary.supporting,
                              ),
                            ),
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
                            microHud: _MicroHudKind.visibility,
                            instrumentValue: forecast?.visibility,
                            onExplain: () => _showWeatherExplanation(
                              context,
                              _WeatherExplanation(
                                title: '視程',
                                value: forecast?.visibility == null
                                    ? '--'
                                    : '${_visibilityValue(forecast!.visibility!)} / ${_visibilityCategoryJapanese(forecast.visibility!)}',
                                body: '水平方向にどの程度遠くまで見通せるかを示します。',
                                forecastSummary: forecast?.visibility == null
                                    ? daySummary.primary
                                    : 'この日の視程は ${_visibilityValue(forecast!.visibility!)}で、見通しは ${_visibilityCategoryJapanese(forecast.visibility!)}の予報です。',
                                supportingData: daySummary.supporting,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _TelemetryGrid(
                        columns: twoColumns ? 2 : 1,
                        children: [
                          _UvTelemetryModule(
                            value: uvValue,
                            onExplain: () => _showWeatherExplanation(
                              context,
                              _WeatherExplanation(
                                title: 'UV指数',
                                value: uvValue == null
                                    ? '--'
                                    : '${uvValue.toStringAsFixed(0)} / ${_uvCategoryJapanese(uvValue)}',
                                body: '紫外線の強さを表す指数です。値が高いほど紫外線が強くなります。',
                                forecastSummary: uvValue == null
                                    ? daySummary.primary
                                    : 'この日のUV指数は ${uvValue.toStringAsFixed(0)}（${_uvCategoryJapanese(uvValue)}）の予報です。',
                                supportingData: daySummary.supporting,
                              ),
                            ),
                          ),
                          _TelemetryModule(
                            label: '雲量',
                            value: forecast == null
                                ? '--'
                                : '${forecast.cloudCover}%',
                            detail: '',
                            icon: Icons.cloud_outlined,
                            microHud: _MicroHudKind.cloud,
                            instrumentValue: forecast?.cloudCover.toDouble(),
                            onExplain: () => _showWeatherExplanation(
                              context,
                              _WeatherExplanation(
                                title: '雲量',
                                value: forecast == null
                                    ? '--'
                                    : '${forecast.cloudCover}%',
                                body: '空全体のうち雲に覆われている割合の目安です。',
                                forecastSummary: forecast == null
                                    ? daySummary.primary
                                    : 'この日の雲量は ${forecast.cloudCover}% の予報です。',
                                supportingData: daySummary.supporting,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _PressureTelemetryModule(
                        value: forecast?.surfacePressure,
                        onExplain: () => _showWeatherExplanation(
                          context,
                          _WeatherExplanation(
                            title: '気圧',
                            value: forecast?.surfacePressure == null
                                ? '--'
                                : '${forecast!.surfacePressure!.round()} hPa',
                            body: 'この地点付近の地表面気圧の予報値です。',
                            forecastSummary: forecast?.surfacePressure == null
                                ? daySummary.primary
                                : 'この日の地表面気圧は ${forecast!.surfacePressure!.round()} hPa の予報です。',
                            supportingData: daySummary.supporting,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _WindTelemetryModule(
                        value: forecast,
                        onExplain: () => _showWeatherExplanation(
                          context,
                          _WeatherExplanation(
                            title: '風',
                            value: forecast == null
                                ? '--'
                                : '風速 ${forecast.windSpeed.round()} km/h / 突風 ${forecast.windGust.round()} km/h / ${_windDirection(forecast.windDirection)}',
                            body: '風速は通常の風の強さ、突風は一時的に強く吹く風です。風向は風が吹いてくる方向です。',
                            forecastSummary: _windForecastSummary(daySummary),
                            supportingData: daySummary.supporting,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _SunTelemetryModule(
                        sunrise: day.sunrise,
                        sunset: day.sunset,
                        isToday: _sameDay(
                          DateTime.parse(day.date),
                          DateTime.now(),
                        ),
                        onExplain: () => _showWeatherExplanation(
                          context,
                          _WeatherExplanation(
                            title: '日の出・日の入り',
                            value:
                                '日の出 ${_shortTime(day.sunrise)} / 日の入り ${_shortTime(day.sunset)}',
                            body: '曲線は、日の出から日の入りまでの日中時間帯を示しています。',
                            forecastSummary:
                                '日照可能時間は約 ${_daylightDuration(day.sunrise, day.sunset)} です。',
                            supportingData: daySummary.supporting,
                          ),
                        ),
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

class _WeatherExplanation {
  const _WeatherExplanation({
    required this.title,
    required this.value,
    required this.body,
    this.forecastSummary,
    this.forecastSummaryLabel = '選択日の予報',
    this.supportingData = const [],
    this.detailSections = const [],
  });

  final String title;
  final String value;
  final String body;
  final String? forecastSummary;
  final String forecastSummaryLabel;
  final List<String> supportingData;
  final List<_WeatherDetailSection> detailSections;
}

class _WeatherDetailSection {
  const _WeatherDetailSection({
    required this.title,
    required this.metrics,
    this.tonalStrength = .025,
  });

  final String title;
  final List<_WeatherDetailMetric> metrics;
  final double tonalStrength;
}

class _WeatherDetailMetric {
  const _WeatherDetailMetric({
    required this.label,
    required this.value,
    this.context,
  });

  final String label;
  final String value;
  final String? context;
}

Future<void> _showWeatherExplanation(
  BuildContext context,
  _WeatherExplanation explanation,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .28),
  isScrollControlled: true,
  builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .92),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: .62),
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .42),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: .14),
                    Colors.black.withValues(alpha: .18),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .78,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 34,
                          height: 2,
                          color: scheme.primary.withValues(alpha: .45),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: scheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              explanation.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: '閉じる',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      if (explanation.value != '--')
                        Text(
                          explanation.value,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.primary),
                        ),
                      if (explanation.forecastSummary != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: .10),
                            border: Border(
                              left: BorderSide(
                                color: scheme.primary.withValues(alpha: .72),
                                width: 2,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                explanation.forecastSummaryLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                explanation.forecastSummary!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 16,
                                      height: 1.42,
                                      color: scheme.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        for (final item in explanation.supportingData)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: .9,
                                    ),
                                  ),
                            ),
                          ),
                      ],
                      for (final section in explanation.detailSections)
                        _WeatherDetailTelemetrySection(section: section),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(),
                      ),
                      Text(
                        '指標について',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: .62),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        explanation.body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: .72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

class _WeatherDetailTelemetrySection extends StatelessWidget {
  const _WeatherDetailTelemetrySection({required this.section});

  final _WeatherDetailSection section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: section.tonalStrength),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 330;
                const gap = 8.0;
                final itemWidth = twoColumns
                    ? (constraints.maxWidth - gap) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: gap,
                  runSpacing: 7,
                  children: [
                    for (final metric in section.metrics)
                      SizedBox(
                        width: itemWidth,
                        child: _WeatherDetailMetricValue(metric: metric),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherDetailMetricValue extends StatelessWidget {
  const _WeatherDetailMetricValue({required this.metric});

  final _WeatherDetailMetric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: scheme.primary.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: .64),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              height: 1.15,
            ),
          ),
          if (metric.context case final metricContext?)
            Text(
              metricContext,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: .58),
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

enum _MicroHudKind { feelsLike, humidity, precipitation, visibility, uv, cloud }

class _TelemetryModule extends StatelessWidget {
  const _TelemetryModule({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.onExplain,
    this.microHud,
    this.instrumentValue,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback onExplain;
  final _MicroHudKind? microHud;
  final double? instrumentValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExplain,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .46),
            border: Border.all(color: scheme.primary.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: .07),
                Colors.transparent,
              ],
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
              if (microHud != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: SizedBox(
                    key: ValueKey('weather-micro-hud-${microHud!.name}'),
                    width: double.infinity,
                    height: 9,
                    child: CustomPaint(
                      painter: _MicroHudPainter(
                        color: scheme.primary,
                        kind: microHud!,
                        value: instrumentValue,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicroHudPainter extends CustomPainter {
  const _MicroHudPainter({
    required this.color,
    required this.kind,
    required this.value,
  });

  final Color color;
  final _MicroHudKind kind;
  final double? value;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = color.withValues(alpha: .16)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = color.withValues(alpha: .78)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final left = 2.0;
    final right = size.width - 2;
    canvas.drawLine(Offset(left, y), Offset(right, y), track);
    if (value == null) return;
    final normalized = switch (kind) {
      _MicroHudKind.feelsLike => ((value! + 6) / 12).clamp(0.0, 1.0),
      _MicroHudKind.humidity ||
      _MicroHudKind.precipitation ||
      _MicroHudKind.cloud => (value! / 100).clamp(0.0, 1.0),
      _MicroHudKind.visibility => (value! / 30000).clamp(0.0, 1.0),
      _MicroHudKind.uv => (value! / 11).clamp(0.0, 1.0),
    };
    if (kind == _MicroHudKind.uv || kind == _MicroHudKind.cloud) {
      const segments = 6;
      final width = (right - left - (segments - 1) * 2) / segments;
      for (var index = 0; index < segments; index += 1) {
        final isActive = normalized * segments > index;
        final paint = Paint()
          ..color = color.withValues(alpha: isActive ? .72 : .16);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              left + index * (width + 2),
              y - (kind == _MicroHudKind.cloud ? 2 : 2.5),
              width,
              kind == _MicroHudKind.cloud ? 4 : 5,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      return;
    }
    final x = left + (right - left) * normalized;
    if (kind == _MicroHudKind.feelsLike) {
      final middle = (left + right) / 2;
      canvas.drawLine(Offset(middle, y - 3.5), Offset(middle, y + 3.5), track);
      canvas.drawCircle(Offset(x, y), 3, active);
      return;
    }
    canvas.drawLine(Offset(left, y), Offset(x, y), active);
    canvas.drawCircle(Offset(x, y), 2.6, active);
  }

  @override
  bool shouldRepaint(covariant _MicroHudPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.kind != kind ||
      oldDelegate.value != value;
}

class _WindTelemetryModule extends StatelessWidget {
  const _WindTelemetryModule({required this.value, required this.onExplain});
  final WeatherHourly? value;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final direction = value?.windDirection;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExplain,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .46),
            border: Border.all(color: scheme.primary.withValues(alpha: .32)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CustomPaint(
                size: const Size(82, 82),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value == null ? '--' : '${value!.windSpeed.round()}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Text('km/h'),
                        ),
                      ],
                    ),
                    Text(
                      value == null
                          ? 'GUST -- · 風向 --'
                          : 'GUST ${value!.windGust.round()} km/h · ${_windDirection(direction)}',
                      style: Theme.of(context).textTheme.labelSmall,
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

class _WindCompassPainter extends CustomPainter {
  const _WindCompassPainter({required this.color, required this.direction});
  final Color color;
  final double? direction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final fine = Paint()
      ..color = color.withValues(alpha: .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, fine);
    canvas.drawCircle(
      center,
      radius - 7,
      Paint()
        ..color = color.withValues(alpha: .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var index = 0; index < 36; index++) {
      final angle = index * math.pi * 2 / 36 - math.pi / 2;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inner =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (radius - (index % 9 == 0 ? 6 : 3));
      canvas.drawLine(inner, outer, fine);
    }
    final textStyle = TextStyle(
      color: color.withValues(alpha: .8),
      fontSize: 9,
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
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 10);
    final pointer = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, pointer);
    canvas.drawCircle(tip, 2.8, pointer);
    canvas.drawCircle(center, 3, pointer);
  }

  @override
  bool shouldRepaint(covariant _WindCompassPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}

class _UvTelemetryModule extends StatelessWidget {
  const _UvTelemetryModule({required this.value, required this.onExplain});
  final double? value;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    return _TelemetryModule(
      label: 'UV指数',
      value: value == null ? '--' : value!.toStringAsFixed(0),
      detail: value == null ? '--' : _uvCategoryJapanese(value!),
      icon: Icons.wb_sunny_outlined,
      microHud: _MicroHudKind.uv,
      instrumentValue: value,
      onExplain: onExplain,
    );
  }
}

class _SunTelemetryModule extends StatelessWidget {
  const _SunTelemetryModule({
    required this.sunrise,
    required this.sunset,
    required this.isToday,
    required this.onExplain,
  });
  final String sunrise;
  final String sunset;
  final bool isToday;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExplain,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .46),
            border: Border.all(color: scheme.primary.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: .07),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '日の出・日の入り',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    'DAYLIGHT ${_daylightDuration(sunrise, sunset)}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: CustomPaint(
                  painter: _SolarArcPainter(
                    color: scheme.primary,
                    sunrise: sunrise,
                    sunset: sunset,
                    progress: isToday
                        ? weatherSolarProgress(sunrise, sunset)
                        : null,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('日の出 ${_shortTime(sunrise)}'),
                  Text('日の入り ${_shortTime(sunset)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressureTelemetryModule extends StatelessWidget {
  const _PressureTelemetryModule({
    required this.value,
    required this.onExplain,
  });
  final double? value;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExplain,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .46),
            border: Border.all(color: scheme.primary.withValues(alpha: .3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CustomPaint(
                size: const Size(108, 58),
                painter: _PressureGaugePainter(
                  color: scheme.primary,
                  pressure: value,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('気圧', style: Theme.of(context).textTheme.labelSmall),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value == null ? '--' : '${value!.round()}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Text('hPa'),
                        ),
                      ],
                    ),
                    Text(
                      'REF 1013',
                      style: Theme.of(context).textTheme.labelSmall,
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

class _PressureGaugePainter extends CustomPainter {
  const _PressureGaugePainter({required this.color, required this.pressure});
  final Color color;
  final double? pressure;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = math.min(size.width / 2 - 6, size.height - 8);
    final normalized = pressure == null
        ? .5
        : ((pressure! - 980) / 70).clamp(0.0, 1.0);
    for (var index = 0; index < 30; index += 1) {
      final progress = index / 29;
      final angle = math.pi + math.pi * progress;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final segmentLength = index % 5 == 0 ? 7.0 : 4.0;
      final inner =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (radius - segmentLength);
      final active = (progress - normalized).abs() < .055;
      final paint = Paint()
        ..color = color.withValues(alpha: active ? .88 : .25)
        ..strokeWidth = active ? 2.2 : 1.1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, paint);
    }
    final refAngle = math.pi + math.pi * ((1013 - 980) / 70);
    final ref =
        center + Offset(math.cos(refAngle), math.sin(refAngle)) * (radius - 10);
    canvas.drawCircle(ref, 1.8, Paint()..color = color.withValues(alpha: .55));
    final pointer = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final angle = math.pi + math.pi * normalized;
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * (radius - 13),
      pointer,
    );
  }

  @override
  bool shouldRepaint(covariant _PressureGaugePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pressure != pressure;
}

class _SolarArcPainter extends CustomPainter {
  const _SolarArcPainter({
    required this.color,
    required this.sunrise,
    required this.sunset,
    required this.progress,
  });
  final Color color;
  final String sunrise;
  final String sunset;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sunriseFraction = weatherSolarDayFraction(sunrise) ?? .25;
    final sunsetFraction = weatherSolarDayFraction(sunset) ?? .75;
    const horizontalInset = 5.0;
    const horizonY = 31.0;
    final horizon = Paint()
      ..color = color.withValues(alpha: .28)
      ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(horizontalInset, horizonY),
      Offset(size.width - horizontalInset, horizonY),
      horizon,
    );
    for (final hour in [0, 6, 12, 18, 24]) {
      final x =
          horizontalInset + (size.width - horizontalInset * 2) * (hour / 24);
      canvas.drawLine(
        Offset(x, horizonY - 3),
        Offset(x, horizonY + 3),
        horizon,
      );
      final label = TextPainter(
        text: TextSpan(
          text: hour == 24 ? '24' : hour.toString().padLeft(2, '0'),
          style: TextStyle(color: color.withValues(alpha: .55), fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, horizonY + 5));
    }
    final curve = Paint()
      ..color = color.withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final start = weatherSolarDaylightPoint(
      size,
      sunriseFraction,
      sunsetFraction,
      0,
    );
    final end = weatherSolarDaylightPoint(
      size,
      sunriseFraction,
      sunsetFraction,
      1,
    );
    final path = Path()..moveTo(start.dx, start.dy);
    for (var step = 1; step <= 24; step++) {
      final point = weatherSolarDaylightPoint(
        size,
        sunriseFraction,
        sunsetFraction,
        step / 24,
      );
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, curve);
    canvas.drawCircle(start, 2, Paint()..color = color.withValues(alpha: .7));
    canvas.drawCircle(end, 2, Paint()..color = color.withValues(alpha: .7));
    if (progress != null) {
      final point = Paint()..color = color;
      canvas.drawCircle(
        weatherSolarDaylightPoint(
          size,
          sunriseFraction,
          sunsetFraction,
          progress!,
        ),
        3,
        point,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SolarArcPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.sunrise != sunrise ||
      oldDelegate.sunset != sunset ||
      oldDelegate.progress != progress;
}

double? weatherSolarDayFraction(String time) {
  final parsed = DateTime.tryParse(time);
  if (parsed == null) return null;
  return (parsed.hour * 60 + parsed.minute) / (24 * 60);
}

/// Maps daylight progress to the compact temporal curve. It is deliberately
/// not a solar-altitude calculation: the X position remains real local time.
Offset weatherSolarDaylightPoint(
  Size size,
  double sunriseFraction,
  double sunsetFraction,
  double progress,
) {
  final safe = progress.clamp(0.0, 1.0);
  const inset = 5.0;
  const horizonY = 31.0;
  // This is a compact daylight-progression curve, not solar altitude. The
  // A restrained 30px amplitude keeps the compact curve legible without
  // giving this temporal instrument more visual weight than pressure or wind.
  const amplitude = 30.0;
  final startX = inset + (size.width - inset * 2) * sunriseFraction;
  final endX = inset + (size.width - inset * 2) * sunsetFraction;
  return Offset(
    startX + (endX - startX) * safe,
    horizonY - math.sin(math.pi * safe) * amplitude,
  );
}

class _WeatherHourlyTimeline extends StatelessWidget {
  const _WeatherHourlyTimeline({required this.day, required this.values});

  final WeatherDaily day;
  final List<WeatherHourly> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .26),
            border: Border.all(color: scheme.primary.withValues(alpha: .20)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            key: ValueKey(
              'weather-hourly-${values.isEmpty ? 'empty' : values.first.time.substring(0, 10)}',
            ),
            scrollDirection: Axis.horizontal,
            // Keep direction resolution in Flutter's normal scroll gesture
            // arena: horizontal drags belong here, while vertical drags are
            // rejected and continue to the Calendar page ScrollView.
            dragStartBehavior: DragStartBehavior.start,
            physics: const ClampingScrollPhysics(),
            child: _WeatherHourlySharedGrid(day: day, values: values),
          ),
        ),
      ),
    );
  }
}

class _WeatherHourlySharedGrid extends StatelessWidget {
  const _WeatherHourlySharedGrid({required this.day, required this.values});

  final WeatherDaily day;
  final List<WeatherHourly> values;

  static const _columnWidth = 72.0;
  static const _height = 210.0;
  static const _labelWidth = 46.0;
  // Natural panel inset, not an eighth visual band.
  static const _verticalPadding = 2.0;
  static const _timeRowHeight = 25.0;
  static const _weatherRowHeight = 27.0;
  static const _temperatureRowHeight = 58.0;
  static const _metricRowHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final temperatures = values.map((value) => value.temperature).toList();
    final temperatureLow = temperatures.reduce(math.min).toDouble();
    final temperatureSpan = math
        .max(4.0, temperatures.reduce(math.max) - temperatureLow)
        .toDouble();
    return SizedBox(
      width: _labelWidth + values.length * _columnWidth,
      height: _height,
      child: Stack(
        children: [
          // The timeline is organized by weather metric. These faint bands
          // intentionally span both the label and hour-value areas; individual
          // hour columns remain transparent so this never becomes striping.
          _HourlyRowBand(
            top: _verticalPadding,
            height: _timeRowHeight,
            color: scheme.onSurface.withValues(alpha: .018),
          ),
          _HourlyRowBand(
            top: _verticalPadding + _timeRowHeight,
            height: _weatherRowHeight,
            color: scheme.onSurface.withValues(alpha: .035),
          ),
          _HourlyRowBand(
            top: _verticalPadding + _timeRowHeight + _weatherRowHeight,
            height: _temperatureRowHeight,
            color: scheme.onSurface.withValues(alpha: .018),
          ),
          _HourlyRowBand(
            top:
                _verticalPadding +
                _timeRowHeight +
                _weatherRowHeight +
                _temperatureRowHeight,
            height: _metricRowHeight,
            color: scheme.onSurface.withValues(alpha: .035),
          ),
          _HourlyRowBand(
            top:
                _verticalPadding +
                _timeRowHeight +
                _weatherRowHeight +
                _temperatureRowHeight +
                _metricRowHeight,
            height: _metricRowHeight,
            color: scheme.onSurface.withValues(alpha: .018),
          ),
          _HourlyRowBand(
            top:
                _verticalPadding +
                _timeRowHeight +
                _weatherRowHeight +
                _temperatureRowHeight +
                _metricRowHeight * 2,
            height: _metricRowHeight,
            color: scheme.onSurface.withValues(alpha: .035),
          ),
          _HourlyRowBand(
            top:
                _verticalPadding +
                _timeRowHeight +
                _weatherRowHeight +
                _temperatureRowHeight +
                _metricRowHeight * 3,
            height: _metricRowHeight,
            color: scheme.onSurface.withValues(alpha: .018),
          ),
          Positioned(
            left: _labelWidth,
            right: 0,
            top: _verticalPadding + _timeRowHeight + _weatherRowHeight,
            height: _temperatureRowHeight,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HourlyTemperatureTrendPainter(
                  color: scheme.primary,
                  values: temperatures,
                  columnWidth: _columnWidth,
                  low: temperatureLow,
                  span: temperatureSpan,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HourlyMetricLabels(),
              for (var index = 0; index < values.length; index++)
                _WeatherHourlyTimelineColumn(
                  day: day,
                  values: values,
                  index: index,
                  width: _columnWidth,
                  temperatureLow: temperatureLow,
                  temperatureSpan: temperatureSpan,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyMetricLabels extends StatelessWidget {
  const _HourlyMetricLabels();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _WeatherHourlySharedGrid._labelWidth,
    height: _WeatherHourlySharedGrid._height,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        6,
        _WeatherHourlySharedGrid._verticalPadding,
        2,
        _WeatherHourlySharedGrid._verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _HourlyLabelRow('時間', _WeatherHourlySharedGrid._timeRowHeight),
          _HourlyLabelRow('天気', _WeatherHourlySharedGrid._weatherRowHeight),
          _HourlyLabelRow('気温', _WeatherHourlySharedGrid._temperatureRowHeight),
          _HourlyLabelRow('降水', _WeatherHourlySharedGrid._metricRowHeight),
          _HourlyLabelRow('湿度', _WeatherHourlySharedGrid._metricRowHeight),
          _HourlyLabelRow('雨量', _WeatherHourlySharedGrid._metricRowHeight),
          _HourlyLabelRow('風速', _WeatherHourlySharedGrid._metricRowHeight),
        ],
      ),
    ),
  );
}

class _HourlyLabelRow extends StatelessWidget {
  const _HourlyLabelRow(this.label, this.height);

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    ),
  );
}

class _WeatherHourlyTimelineColumn extends StatelessWidget {
  const _WeatherHourlyTimelineColumn({
    required this.day,
    required this.values,
    required this.index,
    required this.width,
    required this.temperatureLow,
    required this.temperatureSpan,
  });

  final WeatherDaily day;
  final List<WeatherHourly> values;
  final int index;
  final double width;
  final double temperatureLow;
  final double temperatureSpan;

  @override
  Widget build(BuildContext context) {
    final value = values[index];
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('weather-hourly-column-${value.time}'),
      onTap: () => _showHourlyForecastDetail(context, day, values, index),
      child: Container(
        width: width,
        height: _WeatherHourlySharedGrid._height,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: scheme.primary.withValues(alpha: .12)),
          ),
        ),
        child: Padding(
          // Keep the two-pixel panel inset outside all seven metric bands.
          padding: const EdgeInsets.symmetric(
            vertical: _WeatherHourlySharedGrid._verticalPadding,
          ),
          child: Column(
            children: [
              _HourlyValueRow(
                height: _WeatherHourlySharedGrid._timeRowHeight,
                child: Text(
                  _hourJapanese(value.time),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              _HourlyValueRow(
                height: _WeatherHourlySharedGrid._weatherRowHeight,
                child: Icon(
                  _weatherIcon(value.code),
                  size: 17,
                  color: scheme.primary,
                ),
              ),
              _HourlyTemperatureValue(
                value: value.temperature,
                low: temperatureLow,
                span: temperatureSpan,
              ),
              _HourlyValueRow(
                height: _WeatherHourlySharedGrid._metricRowHeight,
                child: Text('${value.precipitationProbability}%'),
              ),
              _HourlyValueRow(
                height: _WeatherHourlySharedGrid._metricRowHeight,
                child: Text('${value.humidity}%'),
              ),
              _HourlyValueRow(
                height: _WeatherHourlySharedGrid._metricRowHeight,
                child: Text(
                  value.precipitation == 0
                      ? '0mm'
                      : '${value.precipitation.toStringAsFixed(1)}mm',
                ),
              ),
              _HourlyValueRow(
                height: _WeatherHourlySharedGrid._metricRowHeight,
                child: Text('${value.windSpeed.round()}km/h'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourlyRowBand extends StatelessWidget {
  const _HourlyRowBand({
    required this.top,
    required this.height,
    required this.color,
  });

  final double top;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top,
    height: height,
    child: IgnorePointer(child: ColoredBox(color: color)),
  );
}

class _HourlyValueRow extends StatelessWidget {
  const _HourlyValueRow({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(child: child),
  );
}

/// Keeps the numeric temperature and its painted trend point on one shared
/// geometry. The value remains readable above its point instead of occupying a
/// separate metric row below the graph.
class _HourlyTemperatureValue extends StatelessWidget {
  const _HourlyTemperatureValue({
    required this.value,
    required this.low,
    required this.span,
  });

  final double value;
  final double low;
  final double span;

  @override
  Widget build(BuildContext context) {
    final pointY = _HourlyTemperatureTrendPainter.pointY(
      value: value,
      low: low,
      span: span,
    );
    return SizedBox(
      height: _WeatherHourlySharedGrid._temperatureRowHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: math.max(1.0, pointY - 18).toDouble(),
            child: Text('${value.round()}°', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _HourlyTemperatureTrendPainter extends CustomPainter {
  const _HourlyTemperatureTrendPainter({
    required this.color,
    required this.values,
    required this.columnWidth,
    required this.low,
    required this.span,
  });

  static const _pointTop = 20.0;
  static const _pointBottom = 54.0;

  final Color color;
  final List<double> values;
  final double columnWidth;
  final double low;
  final double span;

  static double pointY({
    required double value,
    required double low,
    required double span,
  }) =>
      _pointBottom -
      (((value - low) / span).clamp(0.0, 1.0) * (_pointBottom - _pointTop))
          .toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = index * columnWidth + columnWidth / 2;
      final y = pointY(value: values[index], low: low, span: span);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    for (var index = 0; index < values.length; index++) {
      final x = index * columnWidth + columnWidth / 2;
      final y = pointY(value: values[index], low: low, span: span);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyTemperatureTrendPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.columnWidth != columnWidth ||
      oldDelegate.low != low ||
      oldDelegate.span != span ||
      oldDelegate.values != values;
}

Future<void> _showHourlyForecastDetail(
  BuildContext context,
  WeatherDaily day,
  List<WeatherHourly> values,
  int index,
) {
  final value = values[index];
  final summary = WeatherHourlyForecastSummaryEngine.summarize(
    hourly: values,
    index: index,
  );
  return _showWeatherExplanation(
    context,
    _WeatherExplanation(
      title: _hourlyDetailTitle(day, value.time),
      value:
          '${_weatherConditionJapanese(value.code)} · ${value.temperature.round()}°',
      body: '時間別予報は、その時刻の予報値です。',
      forecastSummaryLabel: 'この時間の予報',
      forecastSummary: summary.primary,
      supportingData: [
        '体感 ${value.apparentTemperature.round()}° · 降水 ${value.precipitationProbability}%${value.precipitation > 0 ? ' / ${value.precipitation.toStringAsFixed(1)}mm' : ''}',
        '風 ${value.windSpeed.round()} km/h · 突風 ${value.windGust.round()} km/h${value.windDirection == null ? '' : ' · ${_windDirection(value.windDirection)}'}',
        '湿度 ${value.humidity}% · 雲量 ${value.cloudCover}%',
        if (value.dewPoint != null) '露点 ${value.dewPoint!.round()}°',
        if (value.visibility != null)
          '視程 ${_visibilityValue(value.visibility!)}',
        if (value.surfacePressure != null)
          '気圧 ${value.surfacePressure!.round()} hPa',
        if (value.uvIndex != null) 'UV指数 ${value.uvIndex!.toStringAsFixed(0)}',
        ...summary.supporting,
      ],
    ),
  );
}

// Retained temporarily for source compatibility with older widget tests; the
// production timeline above is the sole rendered hourly implementation.
// ignore: unused_element
class _WeatherHourlyCell extends StatelessWidget {
  const _WeatherHourlyCell({
    required this.day,
    required this.values,
    required this.index,
  });

  final WeatherDaily day;
  final List<WeatherHourly> values;
  final int index;

  @override
  Widget build(BuildContext context) {
    final value = values[index];
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final summary = WeatherHourlyForecastSummaryEngine.summarize(
          hourly: values,
          index: index,
        );
        _showWeatherExplanation(
          context,
          _WeatherExplanation(
            title: _hourlyDetailTitle(day, value.time),
            value:
                '${_weatherConditionJapanese(value.code)} · ${value.temperature.round()}°',
            body: '時間別予報は、その時刻の予報値です。',
            forecastSummaryLabel: 'この時間の予報',
            forecastSummary: summary.primary,
            supportingData: [
              '体感 ${value.apparentTemperature.round()}° · 降水 ${value.precipitationProbability}%${value.precipitation > 0 ? ' / ${value.precipitation.toStringAsFixed(1)}mm' : ''}',
              '風 ${value.windSpeed.round()} km/h · 突風 ${value.windGust.round()} km/h${value.windDirection == null ? '' : ' · ${_windDirection(value.windDirection)}'}',
              '湿度 ${value.humidity}% · 雲量 ${value.cloudCover}%',
              if (value.dewPoint != null) '露点 ${value.dewPoint!.round()}°',
              if (value.visibility != null)
                '視程 ${_visibilityValue(value.visibility!)}',
              if (value.surfacePressure != null)
                '気圧 ${value.surfacePressure!.round()} hPa',
              if (value.uvIndex != null)
                'UV指数 ${value.uvIndex!.toStringAsFixed(0)}',
              ...summary.supporting,
            ],
          ),
        );
      },
      child: Container(
        width: 120,
        height: 166,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .4),
          border: Border.all(color: scheme.primary.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _hourJapanese(value.time),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            Icon(_weatherIcon(value.code), size: 24, color: scheme.primary),
            const SizedBox(height: 5),
            Text(
              '${value.temperature.round()}°',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 3),
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
      ),
    );
  }
}

List<WeatherHourly> _hourlyForDay(WeatherSnapshot snapshot, WeatherDaily day) =>
    snapshot.hourly
        .where((value) => value.time.startsWith('${day.date}T'))
        .toList(growable: false);

String _hourlyDetailTitle(WeatherDaily day, String time) {
  final parsed = DateTime.tryParse(time);
  if (parsed == null) return '時間別予報';
  final today = _sameDay(DateTime.parse(day.date), DateTime.now());
  return today
      ? '${parsed.hour}時の予報'
      : '${parsed.month}月${parsed.day}日（${_weekdayJapanese(parsed.weekday)}）${parsed.hour}時';
}

WeatherHourly? _firstHourly(List<WeatherHourly> values) =>
    values.isEmpty ? null : values.first;

WeatherHourly? _representativeHourly(List<WeatherHourly> values) {
  for (final value in values) {
    if (value.time.endsWith('T12:00')) return value;
  }
  return _firstHourly(values);
}

String _feelsLikeSummary(WeatherHourly forecast) =>
    'この日の体感温度は ${forecast.apparentTemperature.round()}°の予報です。';

String _windForecastSummary(WeatherForecastSummary summary) {
  for (final item in summary.supporting) {
    if (item.contains('風が強まり')) return item;
  }
  return summary.primary;
}

String _daylightDuration(String sunrise, String sunset) {
  final start = DateTime.tryParse(sunrise);
  final end = DateTime.tryParse(sunset);
  if (start == null || end == null) return '--';
  final duration = end.difference(start);
  return '${duration.inHours}時間${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}分';
}

/// A time-progress marker only: this intentionally does not claim solar
/// altitude or introduce astronomical data beyond the provider timestamps.
double? weatherSolarProgress(String sunrise, String sunset, {DateTime? now}) {
  final start = DateTime.tryParse(sunrise);
  final end = DateTime.tryParse(sunset);
  if (start == null || end == null || !end.isAfter(start)) return null;
  final current = now ?? DateTime.now();
  if (current.isBefore(start) || current.isAfter(end)) return null;
  return current.difference(start).inMilliseconds /
      end.difference(start).inMilliseconds;
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
