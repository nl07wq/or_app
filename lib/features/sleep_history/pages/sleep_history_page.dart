import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/models/operation_calendar_period.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../body_history/models/body_history_models.dart';
import '../../body_history/services/data_center_history_range_preference.dart';
import '../../body_history/services/history_period_range.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../../repositories/app_repository_container.dart';
import '../models/sleep_history_models.dart';
import '../services/sleep_history_source_resolver.dart';

class SleepHistoryPage extends StatefulWidget {
  const SleepHistoryPage({super.key, this.resolver, this.operationDateService});
  final SleepHistorySourceResolver? resolver;
  final OperationDateService? operationDateService;

  @override
  State<SleepHistoryPage> createState() => _SleepHistoryPageState();
}

class _SleepHistoryPageState extends State<SleepHistoryPage> {
  late final SleepHistorySourceResolver _resolver;
  late final OperationDateService _operationDateService;
  final _preference = DataCenterHistoryRangePreference();
  BodyHistoryPeriod _period = BodyHistoryPeriod.oneWeek;
  DateTimeRange? _customRange;
  SleepHistoryMetric _metric = SleepHistoryMetric.duration;
  bool _weeklyExpanded = false;
  bool _monthlyExpanded = false;
  DateTime? _dailyWindowEnd;
  Future<_SleepViewModel>? _model;

  @override
  void initState() {
    super.initState();
    final container = AppRepositoryRegistry.container;
    _resolver =
        widget.resolver ??
        SleepHistorySourceResolver(
          statusRepository: container.status,
          dailyAggregateRepository: container.dailyAggregates,
        );
    _operationDateService =
        widget.operationDateService ??
        OperationDateService(container.operationState);
    _model = _restoreAndLoad();
  }

  Future<_SleepViewModel> _restoreAndLoad() async {
    final selection = await _preference.load();
    _period = selection.period;
    _customRange = selection.customRange;
    return _load();
  }

  Future<_SleepViewModel> _load() async {
    final operationDate = DateTime.parse(
      (await _operationDateService.current()).value,
    );
    final range = resolveDataCenterHistoryRange(
      _period,
      operationDate,
      customRange: _customRange,
    );
    final days = await _resolver.resolve(
      startDate: _date(range.start),
      endDate: _date(range.end),
    );
    _dailyWindowEnd ??= range.end;
    if (_dailyWindowEnd!.isAfter(range.end)) _dailyWindowEnd = range.end;
    return _SleepViewModel(
      range: range,
      operationDate: operationDate,
      summary: _summarize(days),
    );
  }

  Future<void> _select(BodyHistoryPeriod value) async {
    if (value == BodyHistoryPeriod.custom) {
      final anchor = DateTime.parse(
        (await _operationDateService.current()).value,
      );
      if (!mounted) return;
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: anchor,
        initialDateRange: _customRange,
        helpText: 'SELECT SLEEP HISTORY RANGE',
        saveText: 'USE RANGE',
      );
      if (range == null || !mounted) return;
      _customRange = range;
    }
    setState(() {
      _period = value;
      _dailyWindowEnd = null;
      _weeklyExpanded = false;
      _monthlyExpanded = false;
      _model = _load();
    });
    await _preference.save(value, customRange: _customRange);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SLEEP HISTORY')),
    body: FutureBuilder<_SleepViewModel>(
      future: _model,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return const Center(child: Text('SLEEP HISTORYを読み込めませんでした。'));
        }
        final model = snapshot.requireData;
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.bedtime_outlined,
              title: 'SLEEP HISTORY',
            ),
            AppSpacing.gapSM,
            _PeriodSelector(selected: _period, onSelected: _select),
            AppSpacing.gapSM,
            Text(
              '検索期間: ${_date(model.range.start)} – ${_date(model.range.end)}',
            ),
            if (_observationLabel(model.summary) case final observation?) ...[
              AppSpacing.gapXS,
              Text('観測期間: $observation（${model.summary.observedDays}日）'),
            ],
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.analytics_outlined,
              title: 'OVERVIEW',
            ),
            AppSpacing.gapSM,
            _Overview(summary: model.summary),
            AppSpacing.gapXL,
            OperationCard(
              child: SegmentedButton<SleepHistoryMetric>(
                segments: const [
                  ButtonSegment(
                    value: SleepHistoryMetric.duration,
                    label: Text('睡眠時間'),
                  ),
                  ButtonSegment(
                    value: SleepHistoryMetric.score,
                    label: Text('スコア'),
                  ),
                ],
                selected: {_metric},
                onSelectionChanged: (value) =>
                    setState(() => _metric = value.first),
              ),
            ),
            AppSpacing.gapXL,
            SectionHeader(
              icon: Icons.show_chart_outlined,
              title: '${_metric.label}の推移',
            ),
            AppSpacing.gapSM,
            _LineChart(days: model.summary.days, metric: _metric),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.date_range_outlined,
              title: 'WEEKLY',
            ),
            AppSpacing.gapSM,
            _Buckets(
              days: model.summary.days,
              metric: _metric,
              weekly: true,
              expanded: _weeklyExpanded,
              onToggle: () =>
                  setState(() => _weeklyExpanded = !_weeklyExpanded),
            ),
            if (_showsMonthly(_period, model.range)) ...[
              AppSpacing.gapXL,
              const SectionHeader(
                icon: Icons.calendar_month_outlined,
                title: 'MONTHLY',
              ),
              AppSpacing.gapSM,
              _Buckets(
                days: model.summary.days,
                metric: _metric,
                weekly: false,
                expanded: _monthlyExpanded,
                onToggle: () =>
                    setState(() => _monthlyExpanded = !_monthlyExpanded),
              ),
            ],
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.history_outlined,
              title: 'DAILY HISTORY',
            ),
            AppSpacing.gapSM,
            _DailyHistory(
              days: model.summary.days,
              range: model.range,
              windowEnd: _dailyWindowEnd ?? model.range.end,
              onMove: (delta) {
                final candidate = (_dailyWindowEnd ?? model.range.end).add(
                  Duration(days: delta),
                );
                if (!candidate.isAfter(model.range.end) &&
                    !candidate
                        .subtract(const Duration(days: 6))
                        .isBefore(model.range.start)) {
                  setState(() => _dailyWindowEnd = candidate);
                }
              },
            ),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );
}

class _SleepViewModel {
  const _SleepViewModel({
    required this.range,
    required this.operationDate,
    required this.summary,
  });
  final DateTimeRange range;
  final DateTime operationDate;
  final SleepHistorySummary summary;
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});
  final BodyHistoryPeriod selected;
  final ValueChanged<BodyHistoryPeriod> onSelected;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final period in BodyHistoryPeriod.values)
          ChoiceChip(
            label: Text(period.label),
            selected: period == selected,
            onSelected: (_) => onSelected(period),
          ),
      ],
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});
  final SleepHistorySummary summary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 350 ? 2 : 3;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: constraints.maxWidth < 350 ? 1.15 : 1.0,
        children: [
          _Metric('記録日数', '${summary.observedDays}日', '睡眠またはスコア'),
          _Metric(
            '平均睡眠',
            _duration(summary.averageDurationMinutes?.round()),
            '記録 ${summary.durationDays}日',
          ),
          _Metric(
            '平均スコア',
            _score(summary.averageScore?.round()),
            '記録 ${summary.scoreDays}日',
          ),
          _Metric('最長睡眠', _duration(summary.longestDurationMinutes), ''),
          _Metric('最高スコア', _score(summary.highestScore), ''),
          _Metric('記録日数', '${summary.observedDays}日', ''),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.detail);
  final String title;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              title,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
        ),
        SizedBox(
          height: 18,
          child: Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    ),
  );
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.days, required this.metric});
  final List<SleepHistoryDay> days;
  final SleepHistoryMetric metric;
  @override
  Widget build(BuildContext context) {
    final segments = <List<FlSpot>>[];
    var segment = <FlSpot>[];
    for (var index = 0; index < days.length; index += 1) {
      final value = _value(days[index], metric);
      if (value == null) {
        if (segment.isNotEmpty) segments.add(segment);
        segment = <FlSpot>[];
      } else {
        segment.add(FlSpot(index.toDouble(), value.toDouble()));
      }
    }
    if (segment.isNotEmpty) segments.add(segment);
    final max = segments
        .expand((segment) => segment)
        .fold<double>(0, (value, spot) => spot.y > value ? spot.y : value);
    return OperationCard(
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: max == 0 ? 1 : max * 1.1,
            borderData: FlBorderData(show: false),
            lineBarsData: [
              for (final values in segments)
                LineChartBarData(
                  spots: values,
                  isCurved: false,
                  dotData: const FlDotData(show: true),
                ),
            ],
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: days.length <= 8
                      ? 1
                      : (days.length / 6).ceilToDouble(),
                  getTitlesWidget: (value, _) {
                    final index = value.round();
                    if (index < 0 || index >= days.length) {
                      return const SizedBox();
                    }
                    return Text(
                      _short(DateTime.parse(days[index].operationDate)),
                      style: Theme.of(context).textTheme.labelSmall,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Buckets extends StatelessWidget {
  const _Buckets({
    required this.days,
    required this.metric,
    required this.weekly,
    required this.expanded,
    required this.onToggle,
  });
  final List<SleepHistoryDay> days;
  final SleepHistoryMetric metric;
  final bool weekly;
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<SleepHistoryDay>>{};
    for (final day in days) {
      final date = DateTime.parse(day.operationDate);
      final period = weekly
          ? OperationCalendarPeriod.week(date)
          : OperationCalendarPeriod.month(date);
      groups.putIfAbsent(period.id, () => []).add(day);
    }
    final buckets =
        groups.values.map((value) => _Bucket(value, weekly, metric)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return Column(
      children: [
        _BucketChart(buckets: buckets, metric: metric, weekly: weekly),
        AppSpacing.gapSM,
        for (final bucket
            in expanded || buckets.length <= 3
                ? buckets
                : buckets.sublist(buckets.length - 3))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OperationCard(
              child: Row(
                children: [
                  Expanded(child: Text(bucket.title)),
                  Text(
                    bucket.value == null
                        ? 'データなし'
                        : metric == SleepHistoryMetric.duration
                        ? _duration(bucket.value)
                        : _score(bucket.value),
                  ),
                ],
              ),
            ),
          ),
        if (buckets.length > 3)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onToggle,
              child: Text(expanded ? '折りたたむ' : 'さらに表示'),
            ),
          ),
      ],
    );
  }
}

class _BucketChart extends StatelessWidget {
  const _BucketChart({
    required this.buckets,
    required this.metric,
    required this.weekly,
  });
  final List<_Bucket> buckets;
  final SleepHistoryMetric metric;
  final bool weekly;

  @override
  Widget build(BuildContext context) {
    final measured = <int, _Bucket>{
      for (var index = 0; index < buckets.length; index += 1)
        if (buckets[index].value != null) index: buckets[index],
    };
    if (measured.isEmpty) return const SizedBox.shrink();
    final maximum = measured.values
        .map((bucket) => bucket.value!)
        .reduce((a, b) => a > b ? a : b);
    return OperationCard(
      child: SizedBox(
        height: 156,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maximum == 0 ? 1 : maximum * 1.1,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barTouchData: BarTouchData(enabled: false),
            barGroups: [
              for (final entry in measured.entries)
                BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.value!.toDouble(),
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ],
                ),
            ],
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, _) {
                    final bucket = measured[value.round()];
                    if (bucket == null) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        weekly
                            ? '${bucket.start.month}/${bucket.start.day}'
                            : '${bucket.start.year % 100}/${bucket.start.month}月',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bucket {
  _Bucket(this.days, this.weekly, this.metric)
    : start = weekly
          ? OperationCalendarPeriod.week(
              DateTime.parse(days.first.operationDate),
            ).start
          : OperationCalendarPeriod.month(
              DateTime.parse(days.first.operationDate),
            ).start;
  final List<SleepHistoryDay> days;
  final bool weekly;
  final SleepHistoryMetric metric;
  final DateTime start;
  String get title => weekly
      ? '${start.month}/${start.day} - ${start.add(const Duration(days: 6)).month}/${start.add(const Duration(days: 6)).day}'
      : '${start.year}年${start.month}月';
  int? get value {
    final values = days
        .map((day) => _value(day, metric))
        .whereType<int>()
        .toList();
    return values.isEmpty
        ? null
        : (values.reduce((a, b) => a + b) / values.length).round();
  }
}

class _DailyHistory extends StatelessWidget {
  const _DailyHistory({
    required this.days,
    required this.range,
    required this.windowEnd,
    required this.onMove,
  });
  final List<SleepHistoryDay> days;
  final DateTimeRange range;
  final DateTime windowEnd;
  final ValueChanged<int> onMove;
  @override
  Widget build(BuildContext context) {
    final map = {for (final day in days) day.operationDate: day};
    final start = windowEnd.subtract(const Duration(days: 6));
    return OperationCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: start.isAfter(range.start) ? () => onMove(-7) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_short(start)} - ${_short(windowEnd)}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: windowEnd.isBefore(range.end)
                    ? () => onMove(7)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          for (var i = 6; i >= 0; i--)
            if (map[_date(start.add(Duration(days: i)))] case final day?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(_short(DateTime.parse(day.operationDate))),
                    ),
                    Expanded(
                      child: Text(
                        day.observed
                            ? '睡眠 ${_duration(day.durationMinutes)}'
                            : 'データなし',
                      ),
                    ),
                    Text('スコア ${_score(day.score)}'),
                  ],
                ),
              )
            else
              const SizedBox(),
        ],
      ),
    );
  }
}

SleepHistorySummary _summarize(List<SleepHistoryDay> days) {
  final durations = days
      .map((day) => day.durationMinutes)
      .whereType<int>()
      .toList();
  final scores = days.map((day) => day.score).whereType<int>().toList();
  return SleepHistorySummary(
    days: days,
    durationDays: durations.length,
    scoreDays: scores.length,
    averageDurationMinutes: durations.isEmpty
        ? null
        : durations.reduce((a, b) => a + b) / durations.length,
    averageScore: scores.isEmpty
        ? null
        : scores.reduce((a, b) => a + b) / scores.length,
    longestDurationMinutes: durations.isEmpty
        ? null
        : durations.reduce((a, b) => a > b ? a : b),
    highestScore: scores.isEmpty
        ? null
        : scores.reduce((a, b) => a > b ? a : b),
    latestDurationMinutes: durations.isEmpty ? null : durations.last,
    latestScore: scores.isEmpty ? null : scores.last,
  );
}

String? _observationLabel(SleepHistorySummary summary) {
  final observed = summary.days.where((day) => day.observed).toList();
  if (observed.isEmpty) return null;
  final first = observed.first.operationDate;
  final last = observed.last.operationDate;
  return first == summary.days.first.operationDate &&
          last == summary.days.last.operationDate
      ? null
      : '$first – $last';
}

bool _showsMonthly(
  BodyHistoryPeriod period,
  DateTimeRange range,
) => switch (period) {
  BodyHistoryPeriod.oneWeek || BodyHistoryPeriod.fifteenDays => false,
  BodyHistoryPeriod.oneMonth ||
  BodyHistoryPeriod.threeMonths ||
  BodyHistoryPeriod.sixMonths ||
  BodyHistoryPeriod.oneYear => true,
  BodyHistoryPeriod.allTime || BodyHistoryPeriod.custom => !range.start.isAfter(
    resolveDataCenterHistoryRange(BodyHistoryPeriod.oneMonth, range.end).start,
  ),
};
int? _value(SleepHistoryDay day, SleepHistoryMetric metric) =>
    metric == SleepHistoryMetric.duration ? day.durationMinutes : day.score;
String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _short(DateTime value) => '${value.month}/${value.day}';
String _duration(int? value) => value == null
    ? '—'
    : '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
String _score(int? value) => value == null ? '—' : '$value';
