import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../body_history/models/body_history_models.dart';
import '../../body_history/services/data_center_history_range_preference.dart';
import '../../body_history/services/history_period_range.dart';
import '../../repositories/app_repository_container.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../models/nutrition_history_models.dart';
import '../services/nutrition_history_chart_engine.dart';
import '../services/nutrition_history_source_resolver.dart';
import '../widgets/nutrition_history_chart.dart';

class NutritionHistoryPage extends StatefulWidget {
  final NutritionHistorySourceResolver? resolver;
  final DateTime Function()? clock;
  final OperationDateService? operationDateService;
  final DataCenterHistoryRangePreference? rangePreference;

  const NutritionHistoryPage({
    super.key,
    this.resolver,
    this.clock,
    this.operationDateService,
    this.rangePreference,
  });

  @override
  State<NutritionHistoryPage> createState() => _NutritionHistoryPageState();
}

class _NutritionHistoryPageState extends State<NutritionHistoryPage> {
  late final NutritionHistorySourceResolver _resolver;
  late final DateTime Function() _clock;
  OperationDateService? _operationDateService;
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
    if (widget.clock == null) {
      _operationDateService =
          widget.operationDateService ??
          OperationDateService(AppRepositoryRegistry.container.operationState);
    }
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
    final anchor = widget.clock != null
        ? _clock()
        : DateTime.parse((await _operationDateService!.current()).value);
    final range = resolveDataCenterHistoryRange(
      _period,
      anchor,
      customRange: _customRange,
    );
    final points = await _resolver.resolve(
      startDate: _format(range.start),
      endDate: _format(range.end),
    );
    return _NutritionHistoryViewModel(range: range, points: points);
  }

  Future<void> _selectPeriod(BodyHistoryPeriod period) async {
    if (period == BodyHistoryPeriod.custom) {
      final now = widget.clock != null
          ? _clock()
          : DateTime.parse((await _operationDateService!.current()).value);
      if (!mounted) return;
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
            if (_nutritionObservationRange(model.points, model.range)
                case final observation?) ...[
              AppSpacing.gapXS,
              Text('観測期間: $observation'),
            ],
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
    child: GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.xs,
      childAspectRatio: 1.3,
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
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
        AppSpacing.gapXS,
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: Theme.of(context).textTheme.titleSmall, maxLines: 1)),
      ],
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

String? _nutritionObservationRange(
  List<NutritionHistoryDataPoint> points,
  DateTimeRange range,
) {
  final observed = points
      .where(
        (point) => NutritionHistoryMetric.values.any(
          (metric) => point.valueFor(metric) != null,
        ),
      )
      .toList();
  if (observed.isEmpty) return null;
  final first = observed.first.operationDate;
  final last = observed.last.operationDate;
  if (first == _format(range.start) && last == _format(range.end)) return null;
  return '$first – $last（${observed.length}日）';
}
