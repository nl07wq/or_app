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
import '../models/activity_history_models.dart';
import '../services/activity_history_analytics.dart';
import '../services/activity_history_source_resolver.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({
    super.key,
    this.resolver,
    this.operationDateService,
  });

  final ActivityHistorySourceResolver? resolver;
  final OperationDateService? operationDateService;

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  static const _analytics = ActivityHistoryAnalytics();
  late final ActivityHistorySourceResolver _resolver;
  late final OperationDateService _operationDateService;
  late final DataCenterHistoryRangePreference _rangePreference;
  BodyHistoryPeriod _period = BodyHistoryPeriod.oneWeek;
  DateTimeRange? _customRange;
  Future<_ActivityViewModel>? _model;
  DateTime? _dailyWindowEnd;
  bool _trendExpanded = false;
  bool _weeklyExpanded = false;
  bool _monthlyExpanded = false;

  @override
  void initState() {
    super.initState();
    _resolver =
        widget.resolver ??
        ActivityHistorySourceResolver(
          activityRepository: AppRepositoryRegistry.container.activity,
          dailyAggregateRepository:
              AppRepositoryRegistry.container.dailyAggregates,
        );
    _operationDateService =
        widget.operationDateService ??
        OperationDateService(AppRepositoryRegistry.container.operationState);
    _rangePreference = DataCenterHistoryRangePreference();
    _model = _restoreAndLoad();
  }

  Future<_ActivityViewModel> _restoreAndLoad() async {
    final saved = await _rangePreference.load();
    _period = saved.period;
    _customRange = saved.customRange;
    return _load();
  }

  Future<_ActivityViewModel> _load() async {
    final operationDate = await _operationDateService.current();
    final range = resolveDataCenterHistoryRange(
      _period,
      DateTime.parse(operationDate.value),
      customRange: _customRange,
    );
    final days = _period == BodyHistoryPeriod.allTime
        ? await _resolver.resolveAvailableThrough(_date(range.end))
        : await _resolver.resolve(
            startDate: _date(range.start),
            endDate: _date(range.end),
          );
    final actualRange = days.isEmpty
        ? range
        : DateTimeRange(
            start: DateTime.parse(days.first.operationDate),
            end: range.end,
          );
    _dailyWindowEnd ??= actualRange.end;
    if (_dailyWindowEnd!.isAfter(actualRange.end)) {
      _dailyWindowEnd = actualRange.end;
    }
    return _ActivityViewModel(
      range: actualRange,
      summary: _analytics.summarize(days),
      operationDate: DateTime.parse(operationDate.value),
    );
  }

  Future<void> _select(BodyHistoryPeriod period) async {
    if (period == BodyHistoryPeriod.custom) {
      final operationDate = await _operationDateService.current();
      if (!mounted) return;
      final anchor = DateTime.parse(operationDate.value);
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: anchor,
        initialDateRange: _customRange,
        helpText: 'SELECT ACTIVITY HISTORY RANGE',
        saveText: 'USE RANGE',
      );
      if (selected == null || !mounted) return;
      _customRange = selected;
    }
    setState(() {
      _period = period;
      _dailyWindowEnd = null;
      _trendExpanded = false;
      _weeklyExpanded = false;
      _monthlyExpanded = false;
      _model = _load();
    });
    await _rangePreference.save(period, customRange: _customRange);
  }

  void _moveDailyWindow(DateTimeRange range, int delta) {
    final candidate = (_dailyWindowEnd ?? range.end).add(Duration(days: delta));
    final earliest = range.start.add(const Duration(days: 6));
    if (candidate.isBefore(earliest) || candidate.isAfter(range.end)) return;
    setState(() => _dailyWindowEnd = candidate);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ACTIVITY HISTORY')),
    body: FutureBuilder<_ActivityViewModel>(
      future: _model,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return const Center(child: Text('ACTIVITY HISTORYを読み込めませんでした。'));
        }
        final model = snapshot.requireData;
        if (model.summary.days.isEmpty) {
          return _ActivityNoData(period: _period, onSelected: _select);
        }
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.directions_walk_outlined,
              title: 'ACTIVITY HISTORY',
            ),
            AppSpacing.gapSM,
            _ActivityPeriodSelector(selected: _period, onSelected: _select),
            AppSpacing.gapSM,
            Text(
              '検索期間: ${_date(model.range.start)} – ${_date(model.range.end)}',
            ),
            if (model.summary.outsideObservationDays > 0) ...[
              AppSpacing.gapXS,
              Text(
                '観測期間: ${_observationRange(model.summary)}（${model.summary.observationDays}日）',
              ),
            ],
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.analytics_outlined,
              title: 'OVERVIEW',
            ),
            AppSpacing.gapSM,
            _ActivityOverview(summary: model.summary),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.show_chart_outlined,
              title: '歩数の推移',
            ),
            AppSpacing.gapSM,
            _ActivityLineChart(days: model.summary.days),
            AppSpacing.gapXL,
            const SectionHeader(icon: Icons.insights_outlined, title: 'TREND'),
            AppSpacing.gapSM,
            _ActivityDailyTrend(
              days: model.summary.days,
              currentOperationDate: model.operationDate,
              expanded: _trendExpanded,
              onToggle: () => setState(() => _trendExpanded = !_trendExpanded),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.date_range_outlined,
              title: 'WEEKLY',
            ),
            AppSpacing.gapSM,
            _ActivityBuckets(
              days: model.summary.days,
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
              _ActivityBuckets(
                days: model.summary.days,
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
            _ActivityDailyHistory(
              days: model.summary.days,
              range: model.range,
              windowEnd: _dailyWindowEnd ?? model.range.end,
              onMove: (delta) => _moveDailyWindow(model.range, delta),
            ),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );
}

class _ActivityViewModel {
  const _ActivityViewModel({
    required this.range,
    required this.summary,
    required this.operationDate,
  });
  final DateTimeRange range;
  final ActivityHistoryPeriodSummary summary;
  final DateTime operationDate;
}

class _ActivityPeriodSelector extends StatelessWidget {
  const _ActivityPeriodSelector({
    required this.selected,
    required this.onSelected,
  });
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

class _ActivityNoData extends StatelessWidget {
  const _ActivityNoData({required this.period, required this.onSelected});
  final BodyHistoryPeriod period;
  final ValueChanged<BodyHistoryPeriod> onSelected;
  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.cardPadding,
    children: [
      const SectionHeader(
        icon: Icons.directions_walk_outlined,
        title: 'ACTIVITY HISTORY',
      ),
      AppSpacing.gapSM,
      _ActivityPeriodSelector(selected: period, onSelected: onSelected),
      AppSpacing.gapXL,
      const OperationCard(child: Text('NO DATA\n選択期間に利用可能な正式な歩数記録はありません。')),
    ],
  );
}

class _ActivityOverview extends StatelessWidget {
  const _ActivityOverview({required this.summary});
  final ActivityHistoryPeriodSummary summary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 3 : 2;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: constraints.maxWidth < 350 ? 1.1 : 1.35,
        children: [
          _ActivityMetric(
            '計測率',
            '${summary.measuredDays} / ${summary.observationDays}日',
            '${(summary.measurementCoverage * 100).round()}%・未計測${summary.unmeasuredDays}日',
          ),
          _ActivityMetric(
            '合計歩数',
            summary.measuredDays == 0 ? '—' : '${_number(summary.totalSteps)}歩',
            '計測対象 ${summary.measuredDays}日',
          ),
          _ActivityMetric(
            '計測日平均',
            '${_number(summary.averageMeasuredSteps?.round())}歩',
            '計測対象 ${summary.measuredDays}日',
          ),
          _ActivityMetric('最大歩数', '${_number(summary.maximumSteps)}歩', ''),
          _ActivityMetric('計測日数', '${summary.measuredDays}日', ''),
          _ActivityMetric('未計測日', '${summary.unmeasuredDays}日', ''),
        ],
      );
    },
  );
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.fade,
        ),
        if (detail.isNotEmpty) ...[
          AppSpacing.gapXS,
          Text(detail, maxLines: 1, overflow: TextOverflow.fade),
        ],
      ],
    ),
  );
}

class _ActivityLineChart extends StatelessWidget {
  const _ActivityLineChart({required this.days});
  final List<ActivityHistoryDaySummary> days;
  @override
  Widget build(BuildContext context) => OperationCard(
    key: const ValueKey('activity-daily-steps-chart'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('正式に計測された歩数のみを表示します。未計測・観測対象外は線をつなぎません。'),
        AppSpacing.gapSM,
        SizedBox(height: 190, child: _StepsChart(days: days)),
      ],
    ),
  );
}

class _StepsChart extends StatelessWidget {
  const _StepsChart({required this.days});
  final List<ActivityHistoryDaySummary> days;
  @override
  Widget build(BuildContext context) {
    final max = days
        .where((d) => d.isMeasured && d.steps != null)
        .fold<int>(0, (v, d) => d.steps! > v ? d.steps! : v);
    final segments = <List<FlSpot>>[];
    var segment = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day.isMeasured && day.steps != null) {
        segment.add(FlSpot(i.toDouble(), day.steps!.toDouble()));
      } else if (segment.isNotEmpty) {
        segments.add(segment);
        segment = <FlSpot>[];
      }
    }
    if (segment.isNotEmpty) segments.add(segment);
    return Semantics(
      label: '歩数の推移。未計測と観測対象外は表示しません。',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: max == 0 ? 1 : (max * 1.1).ceilToDouble(),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            for (final values in segments)
              LineChartBarData(
                spots: values,
                isCurved: false,
                barWidth: 2,
                dotData: const FlDotData(show: true),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${days[spot.x.toInt()].operationDate}\n${_number(spot.y.toInt())}歩',
                    Theme.of(context).textTheme.labelMedium!,
                  ),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, _) =>
                    Text(_compactNumber(value.toInt())),
              ),
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
                  final date = DateTime.parse(days[index].operationDate);
                  return Text(
                    '${date.month}/${date.day}',
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityDailyTrend extends StatelessWidget {
  const _ActivityDailyTrend({
    required this.days,
    required this.currentOperationDate,
    required this.expanded,
    required this.onToggle,
  });

  final List<ActivityHistoryDaySummary> days;
  final DateTime currentOperationDate;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visibleDays = expanded || days.length <= 7
        ? days
        : days.reversed.take(7).toList().reversed.toList();
    final maximum = days
        .where((day) => day.isMeasured && day.steps != null)
        .fold<int>(0, (value, day) => day.steps! > value ? day.steps! : value);
    return OperationCard(
      child: Column(
        children: [
          for (final day in visibleDays)
            _ActivityTrendRow(
              day: day,
              maximum: maximum,
              isCurrentOperationDate: _sameDate(
                DateTime.parse(day.operationDate),
                currentOperationDate,
              ),
            ),
          if (days.length > 7)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('activity-trend-toggle'),
                onPressed: onToggle,
                child: Text(expanded ? '折りたたむ' : 'さらに表示'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTrendRow extends StatelessWidget {
  const _ActivityTrendRow({
    required this.day,
    required this.maximum,
    required this.isCurrentOperationDate,
  });

  final ActivityHistoryDaySummary day;
  final int maximum;
  final bool isCurrentOperationDate;

  @override
  Widget build(BuildContext context) {
    final measured = day.isMeasured && day.steps != null;
    final unresolved =
        day.state == ActivityHistoryDayState.notMeasured &&
        day.quality != ActivityHistoryQuality.invalid &&
        isCurrentOperationDate;
    final progress = measured
        ? (maximum == 0 ? 0.0 : day.steps! / maximum)
        : (unresolved ? null : 0.0);
    return Semantics(
      label: '${day.operationDate} ${_activityTrendLabel(day)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(_shortDate(DateTime.parse(day.operationDate))),
            ),
            SizedBox(width: 58, child: Text(_activityTrendLabel(day))),
            Expanded(
              child: LinearProgressIndicator(
                key: ValueKey('activity-trend-bar-${day.operationDate}'),
                value: progress,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 64,
              child: Text(
                measured ? '${_number(day.steps)}歩' : '—',
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _activityTrendLabel(ActivityHistoryDaySummary day) =>
    switch (day.state) {
      ActivityHistoryDayState.measured => '計測済',
      ActivityHistoryDayState.measuredZero => '計測済',
      ActivityHistoryDayState.notMeasured =>
        day.quality == ActivityHistoryQuality.invalid ? '利用不可' : '未計測',
      ActivityHistoryDayState.outsideObservation => '観測対象外',
    };

class _ActivityBuckets extends StatelessWidget {
  const _ActivityBuckets({
    required this.days,
    required this.weekly,
    required this.expanded,
    required this.onToggle,
  });
  final List<ActivityHistoryDaySummary> days;
  final bool weekly;
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ActivityHistoryDaySummary>>{};
    for (final day in days) {
      final date = DateTime.parse(day.operationDate);
      final period = weekly
          ? OperationCalendarPeriod.week(date)
          : OperationCalendarPeriod.month(date);
      groups.putIfAbsent(period.id, () => []).add(day);
    }
    final buckets = groups.values
        .map((days) => _ActivityBucket(days: days, weekly: weekly))
        .toList()
        .reversed
        .toList();
    return Column(
      children: [
        if (buckets.length > 1) _BucketChart(buckets: buckets),
        for (final bucket in expanded ? buckets : buckets.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ActivityBucketCard(bucket: bucket),
          ),
        if (buckets.length > 3)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey(
                weekly ? 'activity-weekly-toggle' : 'activity-monthly-toggle',
              ),
              onPressed: onToggle,
              child: Text(expanded ? '折りたたむ' : 'さらに表示'),
            ),
          ),
      ],
    );
  }
}

class _ActivityBucket {
  _ActivityBucket({required this.days, required this.weekly})
    : summary = const ActivityHistoryAnalytics().summarize(days),
      start = weekly
          ? OperationCalendarPeriod.week(
              DateTime.parse(days.first.operationDate),
            ).start
          : OperationCalendarPeriod.month(
              DateTime.parse(days.first.operationDate),
            ).start;
  final List<ActivityHistoryDaySummary> days;
  final bool weekly;
  final ActivityHistoryPeriodSummary summary;
  final DateTime start;
  String get title => weekly
      ? '${start.month}/${start.day} - ${start.add(const Duration(days: 6)).month}/${start.add(const Duration(days: 6)).day}'
      : '${start.year}年${start.month}月';
}

class _ActivityBucketCard extends StatelessWidget {
  const _ActivityBucketCard({required this.bucket});
  final _ActivityBucket bucket;
  @override
  Widget build(BuildContext context) {
    final summary = bucket.summary;
    final unavailable = summary.measuredDays == 0;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bucket.title, style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSM,
          if (unavailable)
            Text(summary.observationDays == 0 ? '観測対象外' : 'データなし')
          else
            Row(
              children: [
                _BucketMetric(
                  '計測率',
                  '${summary.measuredDays}/${summary.observationDays}日',
                ),
                _BucketMetric('合計歩数', '${_compactNumber(summary.totalSteps)}歩'),
                _BucketMetric(
                  '計測日平均',
                  '${_compactNumber(summary.averageMeasuredSteps?.round())}歩',
                ),
                _BucketMetric(
                  '最大歩数',
                  '${_compactNumber(summary.maximumSteps)}歩',
                ),
                _BucketMetric('計測日数', '${summary.measuredDays}日'),
              ],
            ),
        ],
      ),
    );
  }
}

class _BucketMetric extends StatelessWidget {
  const _BucketMetric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              _breakLabel(label),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        Text(value, maxLines: 1, overflow: TextOverflow.fade),
      ],
    ),
  );
}

class _BucketChart extends StatelessWidget {
  const _BucketChart({required this.buckets});
  final List<_ActivityBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final measured = buckets
        .where((bucket) => bucket.summary.measuredDays > 0)
        .toList();
    if (measured.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: OperationCard(child: Text('比較できる計測データはありません。')),
      );
    }
    final showYear =
        measured.map((bucket) => bucket.start.year).toSet().length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OperationCard(
        child: SizedBox(
          height: 126,
          child: BarChart(
            BarChartData(
              maxY:
                  measured
                      .fold<int>(
                        0,
                        (max, bucket) => bucket.summary.totalSteps > max
                            ? bucket.summary.totalSteps
                            : max,
                      )
                      .toDouble() +
                  1,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
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
                      final index = value.toInt();
                      if (index < 0 || index >= measured.length) {
                        return const SizedBox();
                      }
                      return Text(
                        _bucketLabel(measured[index], showYear: showYear),
                        style: Theme.of(context).textTheme.labelSmall,
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < measured.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: measured[i].summary.totalSteps.toDouble(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _bucketLabel(_ActivityBucket bucket, {required bool showYear}) {
  if (bucket.weekly) return '${bucket.start.month}/${bucket.start.day}';
  return showYear
      ? '${bucket.start.year % 100}/${bucket.start.month}'
      : '${bucket.start.month}月';
}

class _ActivityDailyHistory extends StatelessWidget {
  const _ActivityDailyHistory({
    required this.days,
    required this.range,
    required this.windowEnd,
    required this.onMove,
  });
  final List<ActivityHistoryDaySummary> days;
  final DateTimeRange range;
  final DateTime windowEnd;
  final ValueChanged<int> onMove;
  @override
  Widget build(BuildContext context) {
    final map = {for (final day in days) day.operationDate: day};
    final start = windowEnd.subtract(const Duration(days: 6));
    final window = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ].reversed;
    return OperationCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('activity-history-previous-week'),
                onPressed:
                    windowEnd
                        .subtract(const Duration(days: 7))
                        .isBefore(range.start)
                    ? null
                    : () => onMove(-7),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_shortDate(start)} - ${_shortDate(windowEnd)}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: const ValueKey('activity-history-next-week'),
                onPressed:
                    windowEnd.add(const Duration(days: 7)).isAfter(range.end)
                    ? null
                    : () => onMove(7),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          for (final date in window)
            _ActivityDayRow(
              day:
                  map[_date(date)] ??
                  ActivityHistoryDaySummary(
                    operationDate: _date(date),
                    state: ActivityHistoryDayState.outsideObservation,
                    source: ActivityHistorySource.none,
                    quality: ActivityHistoryQuality.unknown,
                    observationEligible: false,
                  ),
            ),
        ],
      ),
    );
  }
}

class _ActivityDayRow extends StatelessWidget {
  const _ActivityDayRow({required this.day});
  final ActivityHistoryDaySummary day;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(_shortDate(DateTime.parse(day.operationDate))),
        ),
        Expanded(child: Text(_activityStateLabel(day))),
        Text(day.isMeasured ? '${_number(day.steps)}歩' : '—'),
      ],
    ),
  );
}

String _activityStateLabel(ActivityHistoryDaySummary day) =>
    switch (day.state) {
      ActivityHistoryDayState.measured => '計測済み',
      ActivityHistoryDayState.measuredZero => '計測済み',
      ActivityHistoryDayState.notMeasured =>
        day.quality == ActivityHistoryQuality.invalid ? '利用不可' : '未計測',
      ActivityHistoryDayState.outsideObservation => '観測対象外',
    };

String _observationRange(ActivityHistoryPeriodSummary summary) {
  final dates = summary.days.where((day) => day.observationEligible).toList();
  if (dates.isEmpty) return '対象なし';
  return '${dates.first.operationDate} – ${dates.last.operationDate}';
}

bool _showsMonthly(BodyHistoryPeriod period, DateTimeRange range) {
  switch (period) {
    case BodyHistoryPeriod.oneWeek:
    case BodyHistoryPeriod.fifteenDays:
      return false;
    case BodyHistoryPeriod.oneMonth:
    case BodyHistoryPeriod.threeMonths:
    case BodyHistoryPeriod.sixMonths:
    case BodyHistoryPeriod.oneYear:
      return true;
    case BodyHistoryPeriod.allTime:
    case BodyHistoryPeriod.custom:
      final oneMonth = resolveDataCenterHistoryRange(
        BodyHistoryPeriod.oneMonth,
        range.end,
      );
      return !range.start.isAfter(oneMonth.start);
  }
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _shortDate(DateTime value) => '${value.month}/${value.day}';
String _number(int? value) => value == null
    ? '—'
    : value.toString().replaceAllMapped(
        RegExp(r'(?<!^)(?=(\d{3})+$)'),
        (_) => ',',
      );
String _compactNumber(int? value) => value == null
    ? '—'
    : value >= 10000
    ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
    : _number(value);
String _breakLabel(String value) => switch (value) {
  '計測日平均' => '計測日\n平均',
  '合計歩数' => '合計\n歩数',
  '最大歩数' => '最大\n歩数',
  '計測日数' => '計測\n日数',
  _ => value,
};
