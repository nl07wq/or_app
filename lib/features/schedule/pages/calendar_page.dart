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
      _weatherDisclosure = _WeatherDisclosure.collapsed;
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
                  onToggleHourly: () => setState(
                    () => _weatherDisclosure =
                        _weatherDisclosure == _WeatherDisclosure.hourly
                        ? _WeatherDisclosure.details
                        : _WeatherDisclosure.hourly,
                  ),
                ),
                AppSpacing.gapLG,
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
                      onTap: () => _openEditor(record),
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
                  onPressed: () => _openEditor(),
                  role: OperationActionRole.primary,
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
          _WeatherHeader(
            preferences: preferences,
            location: location,
            disclosure: disclosure,
            loading: refreshing,
            canRefresh: location != null,
            onRefresh: onRefresh,
            onSettings: onSettings,
            onSwipeLocation: onSwipeLocation,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    for (final day in snapshot!.daily.take(7))
                      Expanded(
                        child: _WeatherDayCell(
                          value: day,
                          selected: day.date == selectedDate,
                          onTap: () => onSelectDate(day.date),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (stale)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
                child: Text(
                  'OFFLINE / CACHED · UPDATED UTC ${_displayFetchedAt(snapshot!.fetchedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.secondary),
                ),
              ),
            if (selected != null &&
                (disclosure == _WeatherDisclosure.details ||
                    disclosure == _WeatherDisclosure.hourly))
              _WeatherDetails(
                day: selected,
                snapshot: snapshot!,
                hourlyVisible: disclosure == _WeatherDisclosure.hourly,
                onToggleHourly: onToggleHourly,
              ),
            if (disclosure == _WeatherDisclosure.details ||
                disclosure == _WeatherDisclosure.hourly)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 3, 12, 0),
                child: _OpenMeteoAttribution(),
              ),
          ],
        ],
      ),
    );
  }
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
    required this.onSwipeLocation,
    required this.onToggleDisclosure,
  });

  final WeatherLocationPreferences preferences;
  final WeatherLocation? location;
  final _WeatherDisclosure disclosure;
  final bool loading;
  final bool canRefresh;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final ValueChanged<int> onSwipeLocation;
  final VoidCallback onToggleDisclosure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final multiLocation = preferences.locations.length > 1;
    final activeIndex = preferences.locations.indexWhere(
      (value) => value.stableId == preferences.activeLocationId,
    );
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleDisclosure,
            onHorizontalDragEnd: multiLocation
                ? (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() > 120) {
                      onSwipeLocation(velocity < 0 ? 1 : -1);
                    }
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 2, 7),
              child: Row(
                children: [
                  Icon(Icons.cloud_outlined, color: scheme.primary, size: 17),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location == null
                          ? 'WEATHER / LOCATION NOT SET'
                          : 'WEATHER / ${location!.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(letterSpacing: 0.7),
                    ),
                  ),
                  if (multiLocation) ...[
                    _HeaderArrow(
                      icon: Icons.chevron_left,
                      tooltip: 'Previous weather location',
                      onPressed: () => onSwipeLocation(-1),
                    ),
                    Text(
                      '${activeIndex + 1}/${preferences.locations.length}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    _HeaderArrow(
                      icon: Icons.chevron_right,
                      tooltip: 'Next weather location',
                      onPressed: () => onSwipeLocation(1),
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
          tooltip: 'Refresh weather',
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
          tooltip: 'Weather location',
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

class _WeatherDayCell extends StatelessWidget {
  const _WeatherDayCell({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final WeatherDaily value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(value.date);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          '${value.date}, ${weatherConditionLabel(weatherConditionForCode(value.code))}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: scheme.primary.withValues(alpha: .22)),
              bottom: selected
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            children: [
              Text(
                _shortWeekday(date.weekday),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '${date.month}/${date.day}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Icon(_weatherIcon(value.code), color: scheme.primary, size: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${value.high.round()}°/${value.low.round()}°',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Text(
                '${value.precipitationProbability}%',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: scheme.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                '${weatherConditionLabel(weatherConditionForCode(day.code))}  ${day.high.round()}°/${day.low.round()}°',
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
    required this.onToggleHourly,
  });

  final WeatherDaily day;
  final WeatherSnapshot snapshot;
  final bool hourlyVisible;
  final VoidCallback onToggleHourly;

  @override
  Widget build(BuildContext context) {
    final hourly = _hourlyForDay(snapshot, day);
    final current = _firstHourly(hourly);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 3,
            children: [
              Text(
                'SUN ${_shortTime(day.sunrise)} / ${_shortTime(day.sunset)}',
              ),
              if (current != null) ...[
                Text('FEELS ${current.apparentTemperature.round()}°'),
                Text('HUMIDITY ${current.humidity}%'),
                Text('WIND ${current.windSpeed.round()}km/h'),
                Text('GUST ${current.windGust.round()}km/h'),
                Text('CLOUD ${current.cloudCover}%'),
              ],
            ],
          ),
          if (hourly.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggleHourly,
                icon: Icon(
                  hourlyVisible ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                ),
                label: Text(hourlyVisible ? 'HIDE HOURLY' : 'HOURLY'),
              ),
            ),
          if (hourlyVisible)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in hourly)
                    Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .2),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _shortTime(value.time),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Icon(_weatherIcon(value.code), size: 15),
                          Text(
                            '${value.temperature.round()}°',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            '${value.precipitationProbability}%',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
    return SafeArea(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.headlineMedium,
                children: [
                  TextSpan(
                    text: _hour.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: !_minutes
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const TextSpan(text: ' : '),
                  TextSpan(
                    text: _minute.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: _minutes
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _minutes ? 'SET MINUTE' : 'SET HOUR',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final dialSize = math.min(310.0, constraints.maxWidth);
                return SizedBox(
                  width: dialSize,
                  height: dialSize,
                  child: _DirectClockFace(
                    minutes: _minutes,
                    hour: _hour,
                    minute: _minute,
                    hourRing: _dragHourRing ?? clockDialHourRingForHour(_hour),
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
                      radiusFactor: .78,
                      selected: minute == direction * 5,
                    )
                else ...[
                  for (var direction = 0; direction < 12; direction++)
                    _DialNumber(
                      value: direction == 0 ? 0 : direction + 12,
                      direction: direction,
                      radiusFactor: .78,
                      secondary: true,
                      selected:
                          hourRing == ClockDialHourRing.outer &&
                          hour == (direction == 0 ? 0 : direction + 12),
                    ),
                  for (var direction = 0; direction < 12; direction++)
                    _DialNumber(
                      value: direction == 0 ? 12 : direction,
                      direction: direction,
                      radiusFactor: .52,
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
          child: DecoratedBox(
            decoration: selected
                ? BoxDecoration(
                    border: Border.all(color: color, width: 1.4),
                    shape: BoxShape.circle,
                  )
                : const BoxDecoration(),
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
                ),
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
    final outerRadius = dialRadius * .82;
    final numeralOuterRadius = dialRadius * .78;
    final innerRadius = dialRadius * .52;
    final selectedDirection = minutes
        ? minute / 5
        : (hour == 0 || hour == 12 ? 0 : hour % 12);
    final selectedAngle = selectedDirection / 12 * math.pi * 2 - math.pi / 2;
    final angle = dragHandAngle ?? selectedAngle;
    final handRadius = minutes
        ? dialRadius * .73
        : (hourRing == ClockDialHourRing.outer
              ? dialRadius * .55
              : dialRadius * .44);
    final endpoint =
        center +
        Offset(handRadius * math.cos(angle), handRadius * math.sin(angle));
    final faceFill = Paint()
      ..color = color.withValues(alpha: .035)
      ..style = PaintingStyle.fill;
    final trace = Paint()
      ..color = color.withValues(alpha: .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, outerRadius, faceFill);
    canvas.drawCircle(center, outerRadius, trace);
    if (!minutes) {
      canvas.drawCircle(
        center,
        innerRadius,
        trace..color = color.withValues(alpha: .20),
      );
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
    canvas.drawCircle(
      endpoint,
      4.5,
      Paint()..color = color.withValues(alpha: .94),
    );
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = color.withValues(alpha: .24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      center,
      2.8,
      Paint()..color = color.withValues(alpha: .95),
    );
    // A restrained ring focus makes the selected radial authority legible
    // without turning the endpoint into a large draggable target.
    if (!minutes) {
      final focusRadius = hourRing == ClockDialHourRing.outer
          ? numeralOuterRadius
          : innerRadius;
      final focus =
          center +
          Offset(
            focusRadius * math.cos(selectedAngle),
            focusRadius * math.sin(selectedAngle),
          );
      canvas.drawCircle(
        focus,
        14,
        Paint()
          ..color = color.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintHourTicks(Canvas canvas, Offset center, double radius) {
    for (var direction = 0; direction < 12; direction++) {
      final angle = direction / 12 * math.pi * 2 - math.pi / 2;
      final major = direction % 3 == 0;
      final outer = radius * .82;
      final inner = radius * (major ? .74 : .77);
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
      final outer = radius * .82;
      final inner = radius * (major ? .73 : .78);
      final paint = Paint()
        ..color = color.withValues(alpha: major ? .60 : .20)
        ..strokeWidth = major ? 1.35 : .65
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center + Offset(inner * math.cos(angle), inner * math.sin(angle)),
        center + Offset(outer * math.cos(angle), outer * math.sin(angle)),
        paint,
      );
    }
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

String _shortWeekday(int weekday) =>
    const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][weekday - 1];

String _shortTime(String value) {
  final separator = value.indexOf('T');
  return separator == -1
      ? value
      : value.substring(separator + 1, separator + 6);
}

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
