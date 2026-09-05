import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../body_history/models/body_history_models.dart';
import '../../body_history/services/data_center_history_range_preference.dart';
import '../../repositories/app_repository_container.dart';
import '../models/nutrition_history_models.dart';
import '../services/nutrition_history_chart_engine.dart';
import '../services/nutrition_history_source_resolver.dart';
import '../widgets/nutrition_history_chart.dart';

class NutritionHistoryPage extends StatefulWidget {
  final NutritionHistorySourceResolver? resolver;
  final DateTime Function()? clock;
  final DataCenterHistoryRangePreference? rangePreference;

  const NutritionHistoryPage({
    super.key,
    this.resolver,
    this.clock,
    this.rangePreference,
  });

  @override
  State<NutritionHistoryPage> createState() => _NutritionHistoryPageState();
}

class _NutritionHistoryPageState extends State<NutritionHistoryPage> {
  late final NutritionHistorySourceResolver _resolver;
  late final DateTime Function() _clock;
  late final DataCenterHistoryRangePreference _rangePreference;
  BodyHistoryPeriod _period = BodyHistoryPeriod.oneWeek;
  DateTimeRange? _customRange;
  Future<_NutritionHistoryViewModel>? _model;

  @override
  void initState() {
    super.initState();
    _resolver =
        widget.resolver ??
        NutritionHistorySourceResolver(
          dailyAggregateRepository:
              AppRepositoryRegistry.container.dailyAggregates,
        );
    _clock = widget.clock ?? DateTime.now;
    _rangePreference =
        widget.rangePreference ?? DataCenterHistoryRangePreference();
    _model = _restoreAndLoad();
  }

  Future<_NutritionHistoryViewModel> _restoreAndLoad() async {
    final selection = await _rangePreference.load();
    _period = selection.period;
    _customRange = selection.customRange;
    return _load();
  }

  void _reload() => _model = _load();

  Future<_NutritionHistoryViewModel> _load() async {
    final range = _selectedRange();
    final points = await _resolver.resolve(
      startDate: _format(range.start),
      endDate: _format(range.end),
    );
    return _NutritionHistoryViewModel(range: range, points: points);
  }

  DateTimeRange _selectedRange() {
    final value = _clock();
    final today = DateTime(value.year, value.month, value.day);
    if (_period == BodyHistoryPeriod.custom && _customRange != null) {
      return _customRange!;
    }
    final start = switch (_period) {
      BodyHistoryPeriod.oneWeek => today.subtract(const Duration(days: 6)),
      BodyHistoryPeriod.fifteenDays => today.subtract(const Duration(days: 14)),
      BodyHistoryPeriod.oneMonth => _monthsBefore(today, 1),
      BodyHistoryPeriod.threeMonths => _monthsBefore(today, 3),
      BodyHistoryPeriod.sixMonths => _monthsBefore(today, 6),
      BodyHistoryPeriod.oneYear => _yearsBefore(today, 1),
      BodyHistoryPeriod.allTime => DateTime(1),
      BodyHistoryPeriod.custom => today,
    };
    return DateTimeRange(start: start, end: today);
  }

  Future<void> _selectPeriod(BodyHistoryPeriod period) async {
    if (period == BodyHistoryPeriod.custom) {
      final now = _clock();
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: _customRange,
        helpText: 'SELECT NUTRITION HISTORY RANGE',
        saveText: 'USE RANGE',
      );
      if (selected == null || !mounted) return;
      _customRange = selected;
    }
    if (!mounted) return;
    setState(() {
      _period = period;
      _reload();
    });
    await _rangePreference.save(period, customRange: _customRange);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NUTRITION HISTORY')),
    body: FutureBuilder<_NutritionHistoryViewModel>(
      future: _model,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('NUTRITION HISTORYを読み込めませんでした。'));
        }
        final model = snapshot.requireData;
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.restaurant_outlined,
              title: 'NUTRITION HISTORY',
            ),
            AppSpacing.gapSM,
            _PeriodSelector(selected: _period, onSelected: _selectPeriod),
            AppSpacing.gapSM,
            Text(
              '検索期間: ${_format(model.range.start)} – ${_format(model.range.end)}',
            ),
            for (final metric in NutritionHistoryMetric.values) ...[
              AppSpacing.gapXL,
              _MetricSection(
                source: model.points,
                metric: metric,
                period: _period,
                searchRange: model.range,
              ),
            ],
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );

  static DateTime _monthsBefore(DateTime date, int months) {
    final targetMonth = date.month - months;
    final firstOfFollowingMonth = DateTime(date.year, targetMonth + 1, 1);
    final lastDay = firstOfFollowingMonth.subtract(const Duration(days: 1)).day;
    return DateTime(date.year, targetMonth, date.day.clamp(1, lastDay));
  }

  static DateTime _yearsBefore(DateTime date, int years) {
    final year = date.year - years;
    final lastDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(year, date.month, date.day.clamp(1, lastDay));
  }
}

class _PeriodSelector extends StatelessWidget {
  final BodyHistoryPeriod selected;
  final ValueChanged<BodyHistoryPeriod> onSelected;

  const _PeriodSelector({required this.selected, required this.onSelected});

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

class _MetricSection extends StatelessWidget {
  static const _engine = NutritionHistoryChartEngine();

  final List<NutritionHistoryDataPoint> source;
  final NutritionHistoryMetric metric;
  final BodyHistoryPeriod period;
  final DateTimeRange searchRange;

  const _MetricSection({
    required this.source,
    required this.metric,
    required this.period,
    required this.searchRange,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final availablePlotWidth = math.max(
        0.0,
        constraints.maxWidth -
            AppSpacing.lg * 2 -
            NutritionHistoryChart.yAxisWidth,
      );
      final model = _engine.build(
        source: source,
        metric: metric,
        period: period,
        startDate: _format(searchRange.start),
        endDate: _format(searchRange.end),
        availablePlotWidth: availablePlotWidth,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(icon: _icon, title: model.metric.label),
          AppSpacing.gapSM,
          Text('表示単位: ${model.granularity.label}'),
          AppSpacing.gapSM,
          if (model.summary case final summary?)
            _SummaryCard(summary: summary, metric: metric),
          if (model.summary != null) AppSpacing.gapSM,
          OperationCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: NutritionHistoryChart(model: model),
          ),
        ],
      );
    },
  );

  IconData get _icon => switch (metric) {
    NutritionHistoryMetric.intakeCalories => Icons.restaurant_outlined,
    NutritionHistoryMetric.estimatedExpenditure =>
      Icons.local_fire_department_outlined,
    NutritionHistoryMetric.calorieBalance => Icons.balance_outlined,
    NutritionHistoryMetric.protein => Icons.fitness_center_outlined,
    NutritionHistoryMetric.fat => Icons.water_drop_outlined,
    NutritionHistoryMetric.carbohydrate => Icons.grain_outlined,
  };
}

class _SummaryCard extends StatelessWidget {
  final NutritionHistorySummary summary;
  final NutritionHistoryMetric metric;

  const _SummaryCard({required this.summary, required this.metric});

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _SummaryValue(label: 'MAX', value: _value(summary.maximum)),
        _SummaryValue(label: 'MIN', value: _value(summary.minimum)),
        _SummaryValue(label: 'AVERAGE', value: _value(summary.average)),
        _SummaryValue(label: 'RECORDS', value: '${summary.measurementCount}'),
      ],
    ),
  );

  String _value(double value) => '${_number(value)} ${metric.unit}';

  static String _number(double value) {
    final rounded = value.roundToDouble();
    final raw = (value - rounded).abs() < 0.001
        ? rounded.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    final parts = raw.split('.');
    final negative = parts.first.startsWith('-');
    final digits = negative ? parts.first.substring(1) : parts.first;
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${negative ? '-' : ''}$grouped'
        '${parts.length == 2 ? '.${parts.last}' : ''}';
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        AppSpacing.gapXS,
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _NutritionHistoryViewModel {
  final DateTimeRange range;
  final List<NutritionHistoryDataPoint> points;

  const _NutritionHistoryViewModel({required this.range, required this.points});
}

String _format(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
