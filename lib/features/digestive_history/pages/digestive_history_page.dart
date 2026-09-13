import 'package:flutter/material.dart';

import '../../../core/models/digestive_event.dart';
import '../../../core/models/operation_calendar_period.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../body_history/models/body_history_models.dart';
import '../../body_history/services/data_center_history_range_preference.dart';
import '../../repositories/app_repository_container.dart';
import '../models/digestive_history_models.dart';
import '../services/digestive_history_analytics.dart';
import '../services/digestive_history_source_resolver.dart';

class DigestiveHistoryPage extends StatefulWidget {
  const DigestiveHistoryPage({super.key, this.resolver, this.clock});

  final DigestiveHistorySourceResolver? resolver;
  final DateTime Function()? clock;

  @override
  State<DigestiveHistoryPage> createState() => _DigestiveHistoryPageState();
}

class _DigestiveHistoryPageState extends State<DigestiveHistoryPage> {
  static const _analytics = DigestiveHistoryAnalytics();
  late final DigestiveHistorySourceResolver _resolver;
  late final DateTime Function() _clock;
  late final DataCenterHistoryRangePreference _rangePreference;
  BodyHistoryPeriod _period = BodyHistoryPeriod.oneWeek;
  DateTimeRange? _customRange;
  Future<_ViewModel>? _model;

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
    _clock = widget.clock ?? DateTime.now;
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
    final range = _period == BodyHistoryPeriod.custom && _customRange != null
        ? _customRange!
        : _rangeFor(_period, _clock());
    final days = _period == BodyHistoryPeriod.allTime
        ? await _resolver.resolveAvailableThrough(_format(range.end))
        : await _resolver.resolve(
            startDate: _format(range.start),
            endDate: _format(range.end),
          );
    final summary = _analytics.summarize(days);
    final actualRange = days.isEmpty
        ? range
        : DateTimeRange(start: DateTime.parse(days.first.operationDate), end: range.end);
    return _ViewModel(range: actualRange, summary: summary);
  }

  Future<void> _select(BodyHistoryPeriod period) async {
    if (period == BodyHistoryPeriod.custom) {
      final now = _clock();
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
      _model = _load();
    });
    await _rangePreference.save(period, customRange: _customRange);
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
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.analytics_outlined,
              title: 'OVERVIEW',
            ),
            AppSpacing.gapSM,
            _Overview(summary: model.summary),
            AppSpacing.gapXL,
            const SectionHeader(icon: Icons.bar_chart_outlined, title: 'TREND'),
            AppSpacing.gapSM,
            _DailyCountTrend(days: model.summary.days),
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
            _BucketList(days: model.summary.days, weekly: true),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.calendar_month_outlined,
              title: 'MONTHLY',
            ),
            AppSpacing.gapSM,
            _BucketList(days: model.summary.days, weekly: false),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.history_outlined,
              title: 'DAILY HISTORY',
            ),
            AppSpacing.gapSM,
            _DailyHistory(days: model.summary.days.reversed.toList()),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );

  static DateTimeRange _rangeFor(BodyHistoryPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (period) {
      BodyHistoryPeriod.oneWeek => today.subtract(const Duration(days: 6)),
      BodyHistoryPeriod.fifteenDays => today.subtract(const Duration(days: 14)),
      BodyHistoryPeriod.oneMonth => _monthsBefore(today, 1),
      BodyHistoryPeriod.threeMonths => _monthsBefore(today, 3),
      BodyHistoryPeriod.sixMonths => _monthsBefore(today, 6),
      BodyHistoryPeriod.oneYear => _yearsBefore(today, 1),
      BodyHistoryPeriod.allTime => DateTime(1),
      BodyHistoryPeriod.custom => today.subtract(const Duration(days: 6)),
    };
    return DateTimeRange(start: start, end: today);
  }

  static String _format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static DateTime _monthsBefore(DateTime date, int months) {
    final month = date.month - months;
    final lastDay = DateTime(date.year, month + 1, 0).day;
    return DateTime(date.year, month, date.day.clamp(1, lastDay));
  }

  static DateTime _yearsBefore(DateTime date, int years) {
    final year = date.year - years;
    final lastDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(year, date.month, date.day.clamp(1, lastDay));
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
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      _Metric(
        'RECORDING COVERAGE',
        '${summary.knownDays} / ${summary.calendarDays} DAYS',
        '${(summary.recordingCoverage * 100).round()}%',
      ),
      _Metric('BM DAYS', '${summary.yesDays}', 'CONFIRMED'),
      _Metric(
        'CONFIRMED NO DAYS',
        '${summary.confirmedNoDays}',
        'UNKNOWN ${summary.unknownDays}',
      ),
      _Metric(
        'TOTAL BM',
        '${summary.totalExactEvents}',
        'EXACT COUNT: ${summary.exactCountDays} DAYS',
      ),
      _Metric(
        'BM / RECORDED DAY',
        _decimal(summary.averagePerExactCountDay),
        'EXACT-COUNT DAYS',
      ),
      _Metric(
        'NO CONTINUITY',
        '${summary.currentConfirmedNoStreak} DAYS',
        'LONGEST ${summary.longestConfirmedNoStreak}',
      ),
      _Metric(
        'DAYS SINCE LAST RECORDED BM DAY',
        summary.daysSinceLatestConfirmedBmDate?.toString() ?? '—',
        summary.latestConfirmedBmDate ?? 'UNAVAILABLE',
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          AppSpacing.gapSM,
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          AppSpacing.gapXS,
          Text(detail),
        ],
      ),
    ),
  );
}

class _DailyCountTrend extends StatelessWidget {
  const _DailyCountTrend({required this.days});
  final List<DigestiveDaySummary> days;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DAILY BM COUNT'),
        AppSpacing.gapSM,
        for (final day in days)
          Semantics(
          label:
              '${day.operationDate} ${_displayState(day)} ${day.countKnown ? 'COUNT ${day.exactCount}' : 'COUNT UNAVAILABLE'}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 92, child: Text(day.operationDate)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: day.countKnown
                          ? ((day.exactCount ?? 0) / 4).clamp(0, 1)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    day.countKnown
                        ? '${day.exactCount}'
                        : day.state == DigestiveDayState.yes
                        ? 'PARTIAL'
                      : _displayState(day),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
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
        'AMOUNT',
        summary.amountDistribution,
        DigestiveEvent.amountLabel,
      ),
      _DistributionCard(
        'FORM',
        summary.formDistribution,
        DigestiveEvent.shapeLabel,
      ),
      _DistributionCard(
        'RELIEF',
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
    width: 260,
    child: OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          AppSpacing.gapSM,
          if (distribution.knownTotal == 0) const Text('NO KNOWN EVENT DATA'),
          for (final entry in distribution.knownCounts.entries)
            _DistributionRow(
              label(entry.key),
              entry.value,
              distribution.knownTotal,
            ),
          if (distribution.missingCount > 0)
            Text('UNKNOWN: ${distribution.missingCount}'),
        ],
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

class _BucketList extends StatelessWidget {
  const _BucketList({required this.days, required this.weekly});
  final List<DigestiveDaySummary> days;
  final bool weekly;
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
    return Column(
      children: [
        for (final entry in groups.entries)
          _BucketCard(keyLabel: entry.key, days: entry.value),
      ],
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.keyLabel, required this.days});
  final String keyLabel;
  final List<DigestiveDaySummary> days;
  @override
  Widget build(BuildContext context) {
    final summary = const DigestiveHistoryAnalytics().summarize(days);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OperationCard(
        child: Text(
          '$keyLabel  •  COVERAGE ${summary.knownDays}/${summary.calendarDays}  •  BM ${summary.totalExactEvents}  •  ${_decimal(summary.averagePerExactCountDay)} / RECORDED DAY',
        ),
      ),
    );
  }
}

class _DailyHistory extends StatelessWidget {
  const _DailyHistory({required this.days});
  final List<DigestiveDaySummary> days;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final day in days)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.operationDate,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                  Text('BM: ${_displayState(day)}'),
                Text(
                  day.countKnown
                      ? 'COUNT: ${day.exactCount}'
                      : day.state == DigestiveDayState.yes
                      ? 'COUNT: NOT AVAILABLE'
                      : 'COUNT: —',
                ),
                if (day.quality == DigestiveDataQuality.partial)
                  const Text('PARTIAL FORMAL DATA'),
                for (final event in day.events)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      '${event.sequence == null ? 'EVENT' : '#${event.sequence}'}  Amount: ${event.amount == null ? '—' : DigestiveEvent.amountLabel(event.amount!)}  Form: ${event.shape == null ? '—' : DigestiveEvent.shapeLabel(event.shape!)}  Relief: ${event.relief == null ? '—' : DigestiveEvent.reliefLabel(event.relief!)}',
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

String _stateLabel(DigestiveDayState state) => switch (state) {
  DigestiveDayState.yes => 'YES',
  DigestiveDayState.confirmedNo => 'NO',
  DigestiveDayState.unknown => 'NOT RECORDED',
};

String _displayState(DigestiveDaySummary day) =>
    day.quality == DigestiveDataQuality.invalid
    ? 'UNAVAILABLE'
    : _stateLabel(day.state);

String _decimal(double? value) =>
    value == null ? '—' : value.toStringAsFixed(1);
