import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/models/digestive_event.dart';
import '../../../core/models/operation_calendar_period.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../body_history/models/body_history_models.dart';
import '../../body_history/services/data_center_history_range_preference.dart';
import '../../body_history/services/history_period_range.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../../repositories/app_repository_container.dart';
import '../models/digestive_history_models.dart';
import '../services/digestive_history_analytics.dart';
import '../services/digestive_history_source_resolver.dart';

class DigestiveHistoryPage extends StatefulWidget {
  const DigestiveHistoryPage({
    super.key,
    this.resolver,
    this.operationDateService,
  });

  final DigestiveHistorySourceResolver? resolver;
  final OperationDateService? operationDateService;

  @override
  State<DigestiveHistoryPage> createState() => _DigestiveHistoryPageState();
}

class _DigestiveHistoryPageState extends State<DigestiveHistoryPage> {
  static const _analytics = DigestiveHistoryAnalytics();
  late final DigestiveHistorySourceResolver _resolver;
  late final OperationDateService _operationDateService;
  late final DataCenterHistoryRangePreference _rangePreference;
  BodyHistoryPeriod _period = BodyHistoryPeriod.oneWeek;
  DateTimeRange? _customRange;
  Future<_ViewModel>? _model;
  DateTime? _dailyWindowEnd;
  bool _trendExpanded = false;
  bool _weeklyExpanded = false;
  bool _monthlyExpanded = false;

  @override
  void initState() {
    super.initState();
    _resolver =
        widget.resolver ??
        DigestiveHistorySourceResolver(
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

  Future<_ViewModel> _restoreAndLoad() async {
    final saved = await _rangePreference.load();
    _period = saved.period;
    _customRange = saved.customRange;
    return _load();
  }

  Future<_ViewModel> _load() async {
    final operationDate = await _operationDateService.current();
    final range = resolveDataCenterHistoryRange(
      _period,
      DateTime.parse(operationDate.value),
      customRange: _customRange,
    );
    final days = _period == BodyHistoryPeriod.allTime
        ? await _resolver.resolveAvailableThrough(_format(range.end))
        : await _resolver.resolve(
            startDate: _format(range.start),
            endDate: _format(range.end),
          );
    final summary = _analytics.summarize(days);
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
    return _ViewModel(range: actualRange, summary: summary);
  }

  Future<void> _select(BodyHistoryPeriod period) async {
    if (period == BodyHistoryPeriod.custom) {
      final operationDate = await _operationDateService.current();
      if (!mounted) return;
      final now = DateTime.parse(operationDate.value);
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: _customRange,
        helpText: 'SELECT DIGESTIVE HISTORY RANGE',
        saveText: 'USE RANGE',
      );
      if (selected == null || !mounted) return;
      _customRange = selected;
    }
    if (!mounted) return;
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

  void _moveDailyWindow(DateTimeRange range, int days) {
    final current = _dailyWindowEnd ?? range.end;
    final candidate = current.add(Duration(days: days));
    final earliestEnd = range.start.add(const Duration(days: 6));
    if (candidate.isBefore(earliestEnd) || candidate.isAfter(range.end)) return;
    setState(() => _dailyWindowEnd = candidate);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DIGESTIVE HISTORY')),
    body: FutureBuilder<_ViewModel>(
      future: _model,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('DIGESTIVE HISTORYを読み込めませんでした。'));
        }
        final model = snapshot.requireData;
        if (model.summary.knownDays == 0 && model.summary.invalidDays == 0) {
          return _NoData(
            range: model.range,
            period: _period,
            onSelected: _select,
          );
        }
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.monitor_heart_outlined,
              title: 'DIGESTIVE HISTORY',
            ),
            AppSpacing.gapSM,
            _PeriodSelector(selected: _period, onSelected: _select),
            AppSpacing.gapSM,
            Text(
              '検索期間: ${_format(model.range.start)} – ${_format(model.range.end)}',
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
            _Overview(summary: model.summary),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.show_chart_outlined,
              title: '排便回数の推移',
            ),
            AppSpacing.gapSM,
            _DailyCountLineChart(days: model.summary.days),
            AppSpacing.gapXL,
            const SectionHeader(icon: Icons.insights_outlined, title: 'TREND'),
            AppSpacing.gapSM,
            _DailyStatusTrend(
              days: model.summary.days,
              expanded: _trendExpanded,
              onToggle: () => setState(() => _trendExpanded = !_trendExpanded),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.equalizer_outlined,
              title: 'DISTRIBUTION',
            ),
            AppSpacing.gapSM,
            _Distributions(summary: model.summary),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.date_range_outlined,
              title: 'WEEKLY',
            ),
            AppSpacing.gapSM,
            _BucketSection(
              days: model.summary.days,
              weekly: true,
              expanded: _weeklyExpanded,
              onToggle: () =>
                  setState(() => _weeklyExpanded = !_weeklyExpanded),
            ),
            if (_showsDigestiveMonthly(_period, model.range)) ...[
              AppSpacing.gapXL,
              const SectionHeader(
                icon: Icons.calendar_month_outlined,
                title: 'MONTHLY',
              ),
              AppSpacing.gapSM,
              _BucketSection(
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
            _DailyHistoryWindow(
              days: model.summary.days,
              range: model.range,
              windowEnd: _dailyWindowEnd ?? model.range.end,
              onMove: (days) => _moveDailyWindow(model.range, days),
            ),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );

  static String _format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _observationRange(DigestivePeriodSummary summary) {
  final eligible = summary.days
      .where((day) => day.observationEligible)
      .toList();
  if (eligible.isEmpty) return '対象なし';
  return '${eligible.first.operationDate} – ${eligible.last.operationDate}';
}

bool _showsDigestiveMonthly(BodyHistoryPeriod period, DateTimeRange range) {
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

class _ViewModel {
  const _ViewModel({required this.range, required this.summary});
  final DateTimeRange range;
  final DigestivePeriodSummary summary;
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
            selected: selected == period,
            onSelected: (_) => onSelected(period),
          ),
      ],
    ),
  );
}

class _NoData extends StatelessWidget {
  const _NoData({
    required this.range,
    required this.period,
    required this.onSelected,
  });
  final DateTimeRange range;
  final BodyHistoryPeriod period;
  final ValueChanged<BodyHistoryPeriod> onSelected;
  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.cardPadding,
    children: [
      const SectionHeader(
        icon: Icons.monitor_heart_outlined,
        title: 'DIGESTIVE HISTORY',
      ),
      AppSpacing.gapSM,
      _PeriodSelector(selected: period, onSelected: onSelected),
      AppSpacing.gapXL,
      const OperationCard(
        child: Text('NO DATA\n選択期間に利用可能な正式DIGESTIVE記録はありません。'),
      ),
    ],
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});
  final DigestivePeriodSummary summary;
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
        childAspectRatio: constraints.maxWidth < 350 ? 1.08 : 0.9,
        children: [
          _Metric(
            '記録率',
            '${summary.knownDays} / ${summary.observationDays}日',
            '${(summary.recordingCoverage * 100).round()}%・観測 ${summary.observationDays}日',
          ),
          _Metric('排便あり', '${summary.yesDays}日', '確認済み'),
          _Metric('排便なし', '${summary.confirmedNoDays}日', ''),
          _Metric(
            '排便回数',
            '${summary.totalExactEvents}回',
            '集計対象 ${summary.exactCountDays}日',
          ),
          _Metric(
            '記録日平均',
            '${_decimal(summary.averagePerExactCountDay)}回',
            '集計対象 ${summary.exactCountDays}日',
          ),
          _Metric(
            '連続排便なし',
            '${summary.currentConfirmedNoStreak}日',
            '最長 ${summary.longestConfirmedNoStreak}日',
          ),
        ],
      );
    },
  );
}

/// Restores the original per-day status-bar Trend from 4c6da78. A null
/// progress value intentionally uses Flutter's lightweight indeterminate
/// animation for unresolved days; it never represents a bowel-movement count.
class _DailyStatusTrend extends StatelessWidget {
  const _DailyStatusTrend({
    required this.days,
    required this.expanded,
    required this.onToggle,
  });

  final List<DigestiveDaySummary> days;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visibleDays = expanded || days.length <= 7
        ? days
        : days.reversed.take(7).toList().reversed.toList();
    return OperationCard(
      child: Column(
        children: [
          for (final day in visibleDays)
            Semantics(
              label:
                  '${day.operationDate} ${_dailyStateLabel(day)} ${day.countKnown ? '${day.exactCount}回' : _trendDetail(day)}',
              child: Padding(
                key: ValueKey('digestive-trend-${day.operationDate}'),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(_trendDateLabel(day.operationDate)),
                    ),
                    SizedBox(
                      width: 58,
                      child: Text(
                        _dailyStateLabel(day),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        key: ValueKey(
                          'digestive-trend-bar-${day.operationDate}',
                        ),
                        value: _trendProgress(day),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text(
                        _trendDetail(day),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (days.length > 7)
            TextButton(
              key: const ValueKey('digestive-trend-toggle'),
              onPressed: onToggle,
              child: Text(expanded ? '折りたたむ' : 'さらに表示'),
            ),
        ],
      ),
    );
  }
}

double? _trendProgress(DigestiveDaySummary day) {
  if (!day.observationEligible || day.quality == DigestiveDataQuality.invalid) {
    return 0;
  }
  if (day.countKnown) return ((day.exactCount ?? 0) / 4).clamp(0, 1);
  return null;
}

String _trendDetail(DigestiveDaySummary day) {
  if (!day.observationEligible) return '—';
  if (day.quality == DigestiveDataQuality.invalid) return '利用不可';
  if (day.countKnown) return '${day.exactCount}回';
  return day.state == DigestiveDayState.yes ? '回数不明' : '未記録';
}

String _trendDateLabel(String operationDate) {
  final date = DateTime.parse(operationDate);
  return '${date.month}/${date.day}';
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
        ),
        if (detail.isNotEmpty) ...[
          AppSpacing.gapXS,
          Text(detail, maxLines: 1, overflow: TextOverflow.fade, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    ),
  );
}

class _DailyCountLineChart extends StatelessWidget {
  const _DailyCountLineChart({required this.days});
  final List<DigestiveDaySummary> days;
  @override
  Widget build(BuildContext context) => OperationCard(
    key: const ValueKey('digestive-daily-count-chart'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('日別の正確な回数のみを表示します。未記録・回数不明は線をつなぎません。'),
        AppSpacing.gapSM,
        SizedBox(height: 190, child: _CountChart(days: days)),
      ],
    ),
  );
}

class _CountChart extends StatelessWidget {
  const _CountChart({required this.days});
  final List<DigestiveDaySummary> days;

  @override
  Widget build(BuildContext context) {
    final maxCount = days
        .where((day) => day.countKnown)
        .fold<int>(
          0,
          (max, day) => (day.exactCount ?? 0) > max ? day.exactCount! : max,
        );
    final segments = <List<FlSpot>>[];
    var active = <FlSpot>[];
    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      if (day.observationEligible && day.countKnown) {
        active.add(FlSpot(index.toDouble(), (day.exactCount ?? 0).toDouble()));
      } else if (active.isNotEmpty) {
        segments.add(active);
        active = <FlSpot>[];
      }
    }
    if (active.isNotEmpty) segments.add(active);
    return Semantics(
      label: '排便回数の推移。未記録と回数不明は表示しません。',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxCount + 1).toDouble(),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${days[spot.x.toInt()].operationDate}\n${spot.y.toInt()}回',
                    Theme.of(context).textTheme.labelMedium!,
                  ),
              ],
            ),
          ),
          lineBarsData: [
            for (final segment in segments)
              LineChartBarData(
                spots: segment,
                isCurved: false,
                barWidth: 2,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
          ],
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
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, _) => Text(value.toInt().toString()),
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

class _Distributions extends StatelessWidget {
  const _Distributions({required this.summary});
  final DigestivePeriodSummary summary;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      _DistributionCard(
        '量',
        summary.amountDistribution,
        DigestiveEvent.amountLabel,
      ),
      _DistributionCard(
        '便の形',
        summary.formDistribution,
        DigestiveEvent.shapeLabel,
      ),
      _DistributionCard(
        '残便感',
        summary.reliefDistribution,
        DigestiveEvent.reliefLabel,
      ),
    ],
  );
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard(this.title, this.distribution, this.label);
  final String title;
  final DigestiveDistribution distribution;
  final String Function(int) label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: OperationCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 270;
          final rows = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (distribution.knownTotal == 0) const Text('利用可能な記録なし'),
              for (final entry in distribution.knownCounts.entries)
                _DistributionRow(
                  label(entry.key),
                  entry.value,
                  distribution.knownTotal,
                ),
              if (distribution.missingCount > 0)
                Text('未記録: ${distribution.missingCount}件'),
            ],
          );
          return vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(title), AppSpacing.gapSM, rows],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 68, child: Text(title)),
                    Expanded(child: rows),
                  ],
                );
        },
      ),
    ),
  );
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow(this.label, this.count, this.total);
  final String label;
  final int count;
  final int total;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(width: 75, child: Text(label)),
        Expanded(
          child: LinearProgressIndicator(value: total == 0 ? 0 : count / total),
        ),
        const SizedBox(width: 8),
        Text('$count (${((count / total) * 100).round()}%)'),
      ],
    ),
  );
}

class _BucketSection extends StatelessWidget {
  const _BucketSection({
    required this.days,
    required this.weekly,
    required this.expanded,
    required this.onToggle,
  });
  final List<DigestiveDaySummary> days;
  final bool weekly;
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<DigestiveDaySummary>>{};
    for (final day in days) {
      final date = DateTime.parse(day.operationDate);
      final period = weekly
          ? OperationCalendarPeriod.week(date)
          : OperationCalendarPeriod.month(date);
      groups.putIfAbsent(period.id, () => []).add(day);
    }
    final buckets =
        groups.entries
            .map(
              (entry) => _BucketDisplay(
                days: entry.value,
                weekly: weekly,
                start: weekly
                    ? OperationCalendarPeriod.week(
                        DateTime.parse(entry.value.first.operationDate),
                      ).start
                    : OperationCalendarPeriod.month(
                        DateTime.parse(entry.value.first.operationDate),
                      ).start,
              ),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    return Column(
      children: [
        if (buckets.length > 1) _BucketTrend(buckets: buckets),
        for (final bucket
            in expanded || buckets.length <= 3
                ? buckets
                : buckets.sublist(buckets.length - 3))
          _BucketCard(bucket: bucket),
        if (buckets.length > 3)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: ValueKey(
                weekly ? 'digestive-weekly-toggle' : 'digestive-monthly-toggle',
              ),
              onPressed: onToggle,
              child: Text(expanded ? '折りたたむ' : 'さらに表示'),
            ),
          ),
      ],
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.bucket});
  final _BucketDisplay bucket;
  @override
  Widget build(BuildContext context) {
    final summary = bucket.summary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bucket.title, style: Theme.of(context).textTheme.titleMedium),
            AppSpacing.gapSM,
            if (summary.knownDays == 0)
              Text(summary.observationDays == 0 ? '観測対象外' : 'データなし')
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BucketMetric(
                    '記録率',
                    '${summary.knownDays}/${summary.observationDays}日',
                  ),
                  _BucketMetric('排便あり', '${summary.yesDays}日'),
                  if (!bucket.weekly)
                    _BucketMetric('排便なし', '${summary.confirmedNoDays}日'),
                  _BucketMetric('排便回数', '${summary.totalExactEvents}回'),
                  _BucketMetric(
                    '記録日平均',
                    '${_decimal(summary.averagePerExactCountDay)}回',
                  ),
                  _BucketMetric(
                    '最長排便なし',
                    '${summary.longestConfirmedNoStreak}日',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BucketDisplay {
  _BucketDisplay({
    required this.days,
    required this.weekly,
    required this.start,
  }) : summary = const DigestiveHistoryAnalytics().summarize(days);
  final List<DigestiveDaySummary> days;
  final bool weekly;
  final DateTime start;
  final DigestivePeriodSummary summary;
  String get title {
    if (!weekly) return '${start.year}年${start.month}月';
    final end = start.add(const Duration(days: 6));
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }
}

class _BucketMetric extends StatelessWidget {
  const _BucketMetric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              _metricLabel(label),
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Text(value, maxLines: 1, overflow: TextOverflow.clip),
      ],
    ),
  );
}

String _metricLabel(String label) => switch (label) {
  '記録日平均' => '記録日\n平均',
  '最長排便なし' => '最長排便\nなし',
  _ => label,
};

class _BucketTrend extends StatelessWidget {
  const _BucketTrend({required this.buckets});
  final List<_BucketDisplay> buckets;
  @override
  Widget build(BuildContext context) {
    final plotted = buckets
        .where((bucket) => bucket.summary.knownDays > 0)
        .toList();
    if (plotted.isEmpty) return const SizedBox.shrink();
    final showYear =
        plotted.map((bucket) => bucket.start.year).toSet().length > 1;
    return SizedBox(
      height: 126,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
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
                  if (index < 0 || index >= plotted.length) {
                    return const SizedBox();
                  }
                  return Text(
                    _digestiveBucketLabel(plotted[index], showYear: showYear),
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var index = 0; index < plotted.length; index++)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: plotted[index].summary.totalExactEvents.toDouble(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _digestiveBucketLabel(_BucketDisplay bucket, {required bool showYear}) {
  if (bucket.weekly) return '${bucket.start.month}/${bucket.start.day}';
  return showYear
      ? '${bucket.start.year % 100}/${bucket.start.month}'
      : '${bucket.start.month}月';
}

class _DailyHistoryWindow extends StatefulWidget {
  const _DailyHistoryWindow({
    required this.days,
    required this.range,
    required this.windowEnd,
    required this.onMove,
  });
  final List<DigestiveDaySummary> days;
  final DateTimeRange range;
  final DateTime windowEnd;
  final ValueChanged<int> onMove;
  @override
  State<_DailyHistoryWindow> createState() => _DailyHistoryWindowState();
}

class _DailyHistoryWindowState extends State<_DailyHistoryWindow> {
  final _expanded = <String>{};
  @override
  Widget build(BuildContext context) {
    final end = DateTime(
      widget.windowEnd.year,
      widget.windowEnd.month,
      widget.windowEnd.day,
    );
    final start = end.subtract(const Duration(days: 6));
    final byDate = {for (final day in widget.days) day.operationDate: day};
    final dates = List.generate(
      7,
      (index) => start.add(Duration(days: index)),
    ).reversed.toList();
    final canBack = start.isAfter(widget.range.start);
    final canForward = end.isBefore(widget.range.end);
    return OperationCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${start.month}/${start.day} - ${end.month}/${end.day}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: canBack ? () => widget.onMove(-7) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: '前の7日間',
              ),
              IconButton(
                onPressed: canForward ? () => widget.onMove(7) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: '次の7日間',
              ),
            ],
          ),
          for (final date in dates)
            _DailyHistoryRow(
              day:
                  byDate[_formatDigestiveDate(date)] ??
                  DigestiveDaySummary(
                    operationDate: _formatDigestiveDate(date),
                    state: DigestiveDayState.unknown,
                    source: DigestiveHistorySource.none,
                    quality: DigestiveDataQuality.unknown,
                    countKnown: false,
                    events: const [],
                  ),
              expanded: _expanded.contains(_formatDigestiveDate(date)),
              onToggle: () => setState(() {
                final key = _formatDigestiveDate(date);
                if (!_expanded.add(key)) _expanded.remove(key);
              }),
            ),
        ],
      ),
    );
  }
}

class _DailyHistoryRow extends StatelessWidget {
  static const _dateColumnWidth = 52.0;

  const _DailyHistoryRow({
    required this.day,
    required this.expanded,
    required this.onToggle,
  });
  final DigestiveDaySummary day;
  final bool expanded;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(day.operationDate);
    final hasEvents = day.events.isNotEmpty;
    return Column(
      children: [
        InkWell(
          onTap: hasEvents ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: _dateColumnWidth,
                  child: Text('${date.month}/${date.day}'),
                ),
                Expanded(
                  child: Text(
                    _dailyStateLabel(day),
                    key: ValueKey(
                      'digestive-daily-status-${day.operationDate}',
                    ),
                  ),
                ),
                Text(_dailyCountLabel(day)),
                if (hasEvents)
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(
              left: _dateColumnWidth,
              bottom: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final event in day.events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        key: ValueKey(
                          'digestive-daily-event-${day.operationDate}-${event.sequence ?? 'unknown'}',
                        ),
                        '#${event.sequence ?? '—'} 量:${event.amount == null ? '—' : DigestiveEvent.amountLabel(event.amount!)}  形:${event.shape == null ? '—' : DigestiveEvent.shapeLabel(event.shape!)}  残便感:${_compactRelief(event.relief)}',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

String _formatDigestiveDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dailyStateLabel(DigestiveDaySummary day) {
  if (!day.observationEligible) return '観測対象外';
  if (day.quality == DigestiveDataQuality.invalid) return '利用不可';
  return switch (day.state) {
    DigestiveDayState.yes => '排便あり',
    DigestiveDayState.confirmedNo => '排便なし',
    DigestiveDayState.unknown => '未記録',
  };
}

String _dailyCountLabel(DigestiveDaySummary day) {
  if (!day.observationEligible) return '—';
  if (day.countKnown) return '${day.exactCount}回';
  return day.state == DigestiveDayState.yes ? '回数不明' : '—';
}

String _compactRelief(int? value) => switch (value) {
  0 => 'あり',
  1 => '普通',
  2 => 'スッキリ',
  _ => '—',
};

String _decimal(double? value) =>
    value == null ? '—' : value.toStringAsFixed(1);
