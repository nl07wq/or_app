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
  final WeatherService _weatherService = WeatherService();
  WeatherLocation? _weatherLocation;
  WeatherSnapshot? _weatherSnapshot;
  bool _weatherLoading = false;
  bool _weatherRefreshing = false;
  bool _weatherStale = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWeather();
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    if (_weatherRefreshing) return;
    setState(() {
      _weatherLoading = true;
      _weatherRefreshing = forceRefresh;
      _weatherError = null;
    });
    final location = await _weatherService.loadLocation();
    if (location == null) {
      if (!mounted) return;
      setState(() {
        _weatherLocation = null;
        _weatherSnapshot = null;
        _weatherLoading = false;
        _weatherRefreshing = false;
      });
      return;
    }
    final result = await _weatherService.load(
      location,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _weatherLocation = location;
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
    await _loadWeather(forceRefresh: true);
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
                  location: _weatherLocation,
                  snapshot: _weatherSnapshot,
                  selectedDate: _selectedKey,
                  loading: _weatherLoading,
                  stale: _weatherStale,
                  error: _weatherError,
                  refreshing: _weatherRefreshing,
                  onSettings: _openWeatherSettings,
                  onRefresh: () => _loadWeather(forceRefresh: true),
                  onSelectDate: _selectWeatherDate,
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
    required this.location,
    required this.snapshot,
    required this.selectedDate,
    required this.loading,
    required this.stale,
    required this.error,
    required this.refreshing,
    required this.onSettings,
    required this.onRefresh,
    required this.onSelectDate,
  });

  final WeatherLocation? location;
  final WeatherSnapshot? snapshot;
  final String selectedDate;
  final bool loading;
  final bool stale;
  final String? error;
  final bool refreshing;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final matchingDays = snapshot?.daily
        .where((day) => day.date == selectedDate)
        .toList(growable: false);
    final selected = matchingDays == null || matchingDays.isEmpty
        ? null
        : matchingDays.first;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.primary.withValues(alpha: .42)),
          bottom: BorderSide(color: scheme.primary.withValues(alpha: .24)),
        ),
        gradient: LinearGradient(
          colors: [scheme.primary.withValues(alpha: .08), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: scheme.primary, size: 18),
              const SizedBox(width: 7),
              Text(
                'WEATHER / 7 DAYS',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(letterSpacing: 1.1),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh weather',
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                onPressed: refreshing || location == null ? null : onRefresh,
              ),
              IconButton(
                tooltip: 'Weather location',
                icon: const Icon(Icons.settings_outlined, size: 18),
                onPressed: onSettings,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              location?.displayName ?? 'LOCATION NOT SET',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final day in snapshot!.daily)
                    _WeatherDayCell(
                      value: day,
                      selected: day.date == selectedDate,
                      onTap: () => onSelectDate(day.date),
                    ),
                ],
              ),
            ),
            if (stale)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  'OFFLINE / CACHED · LAST UPDATED UTC ${_displayFetchedAt(snapshot!.fetchedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: scheme.secondary),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              _WeatherDetail(day: selected, snapshot: snapshot!),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _OpenMeteoAttribution(),
            ),
          ],
        ],
      ),
    );
  }
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
          width: 74,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
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
              const SizedBox(height: 4),
              Icon(_weatherIcon(value.code), color: scheme.primary, size: 21),
              const SizedBox(height: 4),
              Text(
                '${value.high.round()}°/${value.low.round()}°',
                style: Theme.of(context).textTheme.labelSmall,
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

class _WeatherDetail extends StatelessWidget {
  const _WeatherDetail({required this.day, required this.snapshot});

  final WeatherDaily day;
  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hourly = snapshot.hourly
        .where((value) => value.time.startsWith('${day.date}T'))
        .toList(growable: false);
    final current = hourly.isEmpty ? null : hourly.first;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_weatherIcon(day.code), color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${day.date} · ${weatherConditionLabel(weatherConditionForCode(day.code))}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text('${day.high.round()}° / ${day.low.round()}°'),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _metric(
                'RAIN',
                '${day.precipitationProbability}% · ${day.precipitation.toStringAsFixed(1)} mm',
              ),
              _metric(
                'SUN',
                '${_shortTime(day.sunrise)} / ${_shortTime(day.sunset)}',
              ),
              if (current != null) ...[
                _metric('FEELS', '${current.apparentTemperature.round()}°'),
                _metric('HUMIDITY', '${current.humidity}%'),
                _metric(
                  'WIND',
                  '${current.windSpeed.round()} / ${current.windGust.round()} km/h',
                ),
                _metric('CLOUD', '${current.cloudCover}%'),
              ],
            ],
          ),
          if (hourly.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('HOURLY', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in hourly)
                    Container(
                      width: 61,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: scheme.primary.withValues(alpha: .2),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _shortTime(value.time),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Icon(
                            _weatherIcon(value.code),
                            size: 17,
                            color: scheme.primary,
                          ),
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
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Text('$label $value');
}

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
            Text(_minutes ? 'PICK MINUTE' : 'PICK HOUR'),
            const SizedBox(height: 12),
            SizedBox(
              width: 310,
              height: 310,
              child: _CircularDial(
                values: values,
                selected: _minutes ? _minute : _hour,
                onSelected: (value) => setState(() {
                  if (_minutes) {
                    _minute = value;
                  } else {
                    _hour = value;
                    _minutes = true;
                  }
                }),
              ),
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

class _CircularDial extends StatelessWidget {
  const _CircularDial({
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      final radius = size * .39;
      return Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DialPainter(values.length, values.indexOf(selected)),
          ),
          for (var index = 0; index < values.length; index++)
            Transform.translate(
              offset: Offset(
                radius *
                    math.cos(index / values.length * math.pi * 2 - math.pi / 2),
                radius *
                    math.sin(index / values.length * math.pi * 2 - math.pi / 2),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: values[index] == selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => onSelected(values[index]),
                  child: Text(values[index].toString().padLeft(2, '0')),
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.cyan,
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 8, height: 8),
          ),
        ],
      );
    },
  );
}

class _DialPainter extends CustomPainter {
  const _DialPainter(this.count, this.selectedIndex);
  final int count, selectedIndex;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .39;
    final paint = Paint()
      ..color = Colors.cyan.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, paint);
    final angle = selectedIndex / count * math.pi * 2 - math.pi / 2;
    canvas.drawLine(
      center,
      center + Offset(radius * math.cos(angle), radius * math.sin(angle)),
      paint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.count != count || old.selectedIndex != selectedIndex;
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
