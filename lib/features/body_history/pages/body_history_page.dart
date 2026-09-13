import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../models/body_history_models.dart';
import '../services/body_history_chart_engine.dart';
import '../services/data_center_history_range_preference.dart';
import '../services/history_period_range.dart';
import '../services/body_history_source_resolver.dart';
import '../widgets/body_history_chart.dart';

class BodyHistoryPage extends StatefulWidget {
  final BodyHistorySourceResolver? resolver;
  final DateTime Function()? clock;
  final OperationDateService? operationDateService;
  final DataCenterHistoryRangePreference? rangePreference;

  const BodyHistoryPage({
    super.key,
    this.resolver,
    this.clock,
    this.operationDateService,
    this.rangePreference,
  });

  @override
  State<BodyHistoryPage> createState() => _BodyHistoryPageState();
}

class _BodyHistoryPageState extends State<BodyHistoryPage> {
  late final BodyHistorySourceResolver _resolver;
  late final DateTime Function() _clock;
  late final OperationDateService _operationDateService;
  late final DataCenterHistoryRangePreference _rangePreference;
  BodyHistoryPeriod _period = BodyHistoryPeriod.oneWeek;
  DateTimeRange? _customRange;
  Future<_BodyHistoryViewModel>? _model;

  @override
  void initState() {
    super.initState();
    final container = AppRepositoryRegistry.container;
    _resolver =
        widget.resolver ??
        BodyHistorySourceResolver(
          statusRepository: container.status,
          dailyAggregateRepository: container.dailyAggregates,
        );
    _clock = widget.clock ?? DateTime.now;
    _operationDateService =
        widget.operationDateService ??
        OperationDateService(container.operationState);
    _rangePreference =
        widget.rangePreference ?? DataCenterHistoryRangePreference();
    _model = _restoreAndLoad();
  }

  Future<_BodyHistoryViewModel> _restoreAndLoad() async {
    final selection = await _rangePreference.load();
    _period = selection.period;
    _customRange = selection.customRange;
    return _load();
  }

  void _reload() => _model = _load();

  Future<_BodyHistoryViewModel> _load() async {
    final anchor = widget.clock != null
        ? _clock()
        : DateTime.parse((await _operationDateService.current()).value);
    final range = resolveDataCenterHistoryRange(
      _period,
      anchor,
      customRange: _customRange,
    );
    final points = await _resolver.resolve(
      startDate: _format(range.start),
      endDate: _format(range.end),
    );
    return _BodyHistoryViewModel(range: range, points: points);
  }

  Future<void> _selectPeriod(BodyHistoryPeriod period) async {
    if (period == BodyHistoryPeriod.custom) {
      final now = widget.clock != null
          ? _clock()
          : DateTime.parse((await _operationDateService.current()).value);
      if (!mounted) return;
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: _customRange,
        helpText: 'SELECT BODY HISTORY RANGE',
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
    appBar: AppBar(title: const Text('BODY HISTORY')),
    body: FutureBuilder<_BodyHistoryViewModel>(
      future: _model,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('BODY HISTORYを読み込めませんでした。'));
        }
        final model = snapshot.requireData;
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.monitor_weight_outlined,
              title: 'BODY HISTORY',
            ),
            AppSpacing.gapSM,
            _PeriodSelector(selected: _period, onSelected: _selectPeriod),
            AppSpacing.gapSM,
            Text(
              '検索期間: ${_format(model.range.start)} – ${_format(model.range.end)}',
            ),
            if (_bodyObservationRange(model.points, model.range)
                case final observation?) ...[
              AppSpacing.gapXS,
              Text('観測期間: $observation'),
            ],
            AppSpacing.gapXL,
            _MetricSection(
              source: model.points,
              metric: BodyHistoryMetric.weight,
              period: _period,
              searchRange: model.range,
            ),
            AppSpacing.gapXL,
            _MetricSection(
              source: model.points,
              metric: BodyHistoryMetric.bodyFat,
              period: _period,
              searchRange: model.range,
            ),
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
  static const _engine = BodyHistoryChartEngine();

  final List<BodyHistoryDataPoint> source;
  final BodyHistoryMetric metric;
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
        constraints.maxWidth - AppSpacing.lg * 2 - BodyHistoryChart.yAxisWidth,
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
            _SummaryCard(model: model, summary: summary),
          if (model.summary != null) AppSpacing.gapSM,
          OperationCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: BodyHistoryChart(model: model),
          ),
        ],
      );
    },
  );

  IconData get _icon => metric == BodyHistoryMetric.weight
      ? Icons.monitor_weight_outlined
      : Icons.percent;
}

class _SummaryCard extends StatelessWidget {
  final BodyHistoryChartModel model;
  final BodyHistorySummary summary;

  const _SummaryCard({required this.model, required this.summary});

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _SummaryValue(label: 'START', value: _value(summary.first)),
        _SummaryValue(label: 'LATEST', value: _value(summary.latest)),
        _SummaryValue(label: 'CHANGE', value: _change(summary.change)),
        _SummaryValue(label: 'MAX', value: _value(summary.maximum)),
        _SummaryValue(label: 'MIN', value: _value(summary.minimum)),
        _SummaryValue(label: 'RECORDS', value: '${summary.measurementCount}'),
      ],
    ),
  );

  String _value(double value) => '${_number(value)}${model.metric.unit}';

  String _change(double value) {
    final sign = value > 0 ? '+' : '';
    final unit = model.metric == BodyHistoryMetric.bodyFat ? 'pt' : 'kg';
    return '$sign${_number(value)}$unit';
  }

  static String _number(double value) {
    final rounded = value.roundToDouble();
    return (value - rounded).abs() < 0.001
        ? rounded.toStringAsFixed(0)
        : value.toStringAsFixed(1);
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

class _BodyHistoryViewModel {
  final DateTimeRange range;
  final List<BodyHistoryDataPoint> points;

  const _BodyHistoryViewModel({required this.range, required this.points});
}

String _format(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String? _bodyObservationRange(
  List<BodyHistoryDataPoint> points,
  DateTimeRange range,
) {
  final observed = points
      .where((point) => point.weightKg != null || point.bodyFatPercent != null)
      .toList();
  if (observed.isEmpty) return null;
  final first = observed.first.operationDate;
  final last = observed.last.operationDate;
  if (first == _format(range.start) && last == _format(range.end)) return null;
  return '$first – $last（${observed.length}日）';
}
