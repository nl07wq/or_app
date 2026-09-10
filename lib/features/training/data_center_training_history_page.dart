import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/repositories/training_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import 'models/training_record_read_model.dart';
import 'services/training_history_overview_adapter.dart';
import 'services/training_volume_formatter.dart';
import 'services/training_exercise_history_adapter.dart';
import 'services/training_exercise_identity.dart';
import 'services/training_history_domain_service.dart';

/// Data Center analytics. The existing TrainingHistoryPage remains the raw
/// formal-record list and is intentionally not reused as this page.
class DataCenterTrainingHistoryPage extends StatefulWidget {
  const DataCenterTrainingHistoryPage({
    super.key,
    this.recordsLoader,
    this.overviewAdapter = const TrainingHistoryOverviewAdapter(),
    this.clock,
  });

  final Future<List<TrainingRecordReadModel>> Function()? recordsLoader;
  final TrainingHistoryOverviewAdapter overviewAdapter;
  final DateTime Function()? clock;

  @override
  State<DataCenterTrainingHistoryPage> createState() =>
      _DataCenterTrainingHistoryPageState();
}

class _DataCenterTrainingHistoryPageState
    extends State<DataCenterTrainingHistoryPage> {
  late final Future<List<TrainingRecordReadModel>> _records;
  var _period = TrainingHistoryOverviewPeriod.oneMonth;
  var _view = _TrainingHistoryView.overview;
  var _exerciseMetric = _ExerciseMetric.weight;
  TrainingExerciseIdentity? _selectedExercise;
  static const _exerciseAdapter = TrainingExerciseHistoryAdapter();

  @override
  void initState() {
    super.initState();
    _records = (widget.recordsLoader ?? TrainingRepository.getReadModels)();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TRAINING HISTORY')),
    body: FutureBuilder<List<TrainingRecordReadModel>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('TRAINING HISTORYを読み込めませんでした。'));
        }
        final all = widget.overviewAdapter.build(
          snapshot.requireData,
          period: TrainingHistoryOverviewPeriod.all,
          referenceDate: widget.clock?.call(),
        );
        final overview = widget.overviewAdapter.build(
          snapshot.requireData,
          period: _period,
          referenceDate: widget.clock?.call(),
        );
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.query_stats_outlined,
              title: 'TRAINING HISTORY',
            ),
            AppSpacing.gapSM,
            _PeriodSelector(
              selected: _period,
              onSelected: (period) => setState(() => _period = period),
            ),
            AppSpacing.gapSM,
            _ViewSelector(
              selected: _view,
              onSelected: (value) => setState(() => _view = value),
            ),
            AppSpacing.gapLG,
            if (all.isEmpty)
              const _EmptyHistoryState()
            else if (_view == _TrainingHistoryView.overview && overview.isEmpty)
              const _EmptyPeriodState()
            else if (_view == _TrainingHistoryView.exercise)
              _ExerciseView(
                records: snapshot.requireData,
                period: _period,
                referenceDate: widget.clock?.call(),
                selected: _selectedExercise,
                metric: _exerciseMetric,
                onSelected: (identity) =>
                    setState(() => _selectedExercise = identity),
                onMetricSelected: (metric) =>
                    setState(() => _exerciseMetric = metric),
                adapter: _exerciseAdapter,
              )
            else ...[
              const SectionHeader(
                icon: Icons.summarize_outlined,
                title: 'STRENGTH OVERVIEW',
              ),
              AppSpacing.gapSM,
              _SummaryGrid(overview: overview),
              AppSpacing.gapXL,
              _MetricSection(
                title: 'RECORDED VOLUME',
                note: '正式に記録された全セットを含みます。',
                points: [
                  for (final point in overview.points)
                    _ChartPoint(point.date, point.recordedVolume),
                ],
                axisFormatter: TrainingVolumeFormatter.axisLabel,
                detailFormatter: TrainingVolumeFormatter.format,
              ),
              AppSpacing.gapXL,
              _MetricSection(
                title: 'REPS',
                points: [
                  for (final point in overview.points)
                    _ChartPoint(point.date, point.recordedReps.toDouble()),
                ],
                axisFormatter: _formatInteger,
                detailFormatter: (value) => '${_formatInteger(value)} reps',
              ),
              AppSpacing.gapXL,
              _MetricSection(
                title: 'RECORDED SETS',
                points: [
                  for (final point in overview.points)
                    _ChartPoint(point.date, point.recordedSetCount.toDouble()),
                ],
                axisFormatter: _formatInteger,
                detailFormatter: (value) => '${_formatInteger(value)} sets',
              ),
              AppSpacing.gapXL,
              _MetricSection(
                title: 'STRENGTH FREQUENCY',
                note: 'MONDAY START · STRENGTH SESSIONS PER WEEK',
                weeklyBars: true,
                points: [
                  for (final point in overview.frequencyPoints)
                    _ChartPoint(point.weekStart, point.sessions.toDouble()),
                ],
                axisFormatter: _formatInteger,
                detailFormatter: (value) => '${_formatInteger(value)} sessions',
              ),
            ],
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );
}

enum _TrainingHistoryView { overview, exercise }

enum _ExerciseMetric { weight, reps, volume }

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.selected, required this.onSelected});
  final _TrainingHistoryView selected;
  final ValueChanged<_TrainingHistoryView> onSelected;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final view in _TrainingHistoryView.values)
          ChoiceChip(
            label: Text(
              view == _TrainingHistoryView.overview ? 'OVERVIEW' : 'EXERCISE',
            ),
            selected: selected == view,
            onSelected: (_) => onSelected(view),
          ),
      ],
    ),
  );
}

class _ExerciseView extends StatelessWidget {
  const _ExerciseView({
    required this.records,
    required this.period,
    required this.referenceDate,
    required this.selected,
    required this.metric,
    required this.onSelected,
    required this.onMetricSelected,
    required this.adapter,
  });
  final List<TrainingRecordReadModel> records;
  final TrainingHistoryOverviewPeriod period;
  final DateTime? referenceDate;
  final TrainingExerciseIdentity? selected;
  final _ExerciseMetric metric;
  final ValueChanged<TrainingExerciseIdentity> onSelected;
  final ValueChanged<_ExerciseMetric> onMetricSelected;
  final TrainingExerciseHistoryAdapter adapter;
  @override
  Widget build(BuildContext context) {
    final allPoints = adapter.points(
      records,
      period: period,
      referenceDate: referenceDate,
    );
    final identities = adapter.identities(allPoints);
    if (identities.isEmpty) return const _EmptyPeriodState();
    final identity = identities.contains(selected)
        ? selected!
        : identities.first;
    final points = adapter.forIdentity(allPoints, identity);
    final metricPoints = [
      for (final point in points)
        if (_metricValue(point, metric) case final value?)
          _ChartPoint(DateTime.parse(point.operationDate), value),
    ];
    final latest = metricPoints.isEmpty ? null : metricPoints.last;
    final maximum = metricPoints.isEmpty
        ? null
        : metricPoints
              .map((point) => point.value)
              .reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.fitness_center_outlined,
          title: 'EXERCISE',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: DropdownButton<TrainingExerciseIdentity>(
            isExpanded: true,
            itemHeight: null,
            value: identity,
            selectedItemBuilder: (context) => [
              for (final item in identities)
                _ExerciseSelectorEntry(
                  presentation: adapter.selectorPresentation(item),
                ),
            ],
            items: [
              for (final item in identities)
                DropdownMenuItem(
                  value: item,
                  child: _ExerciseSelectorEntry(
                    presentation: adapter.selectorPresentation(item),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onSelected(value);
            },
          ),
        ),
        AppSpacing.gapLG,
        _ExerciseMetricSelector(selected: metric, onSelected: onMetricSelected),
        AppSpacing.gapLG,
        _ExerciseSummary(
          points: points,
          metric: metric,
          latest: latest,
          maximum: maximum,
        ),
        AppSpacing.gapXL,
        if (metricPoints.isEmpty)
          OperationCard(
            child: Text('${_metricTitle(metric)} DATA NOT AVAILABLE'),
          )
        else
          _MetricSection(
            title: '${_metricTitle(metric)} HISTORY',
            points: metricPoints,
            axisFormatter: _axisFormatter(metric),
            detailFormatter: _detailFormatter(metric),
          ),
      ],
    );
  }
}

class _ExerciseSelectorEntry extends StatelessWidget {
  const _ExerciseSelectorEntry({required this.presentation});

  final TrainingExerciseSelectorPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          presentation.exerciseLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium,
        ),
        if (presentation.equipmentLabel case final equipmentLabel?)
          Text(
            equipmentLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall,
          ),
      ],
    );
  }
}

class _ExerciseMetricSelector extends StatelessWidget {
  const _ExerciseMetricSelector({
    required this.selected,
    required this.onSelected,
  });

  final _ExerciseMetric selected;
  final ValueChanged<_ExerciseMetric> onSelected;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final metric in _ExerciseMetric.values)
          ChoiceChip(
            label: Text(_metricSelectorLabel(metric)),
            selected: selected == metric,
            onSelected: (_) => onSelected(metric),
          ),
      ],
    ),
  );
}

class _ExerciseSummary extends StatelessWidget {
  const _ExerciseSummary({
    required this.points,
    required this.metric,
    required this.latest,
    required this.maximum,
  });
  final List<ExerciseHistoryPoint> points;
  final _ExerciseMetric metric;
  final _ChartPoint? latest;
  final double? maximum;
  @override
  Widget build(BuildContext context) => _SummaryGridLike(
    children: [
      _SummaryMetric(
        'LAST TRAINED',
        _formatDate(DateTime.parse(points.last.operationDate)),
        '',
      ),
      _SummaryMetric(
        _latestLabel(metric),
        latest == null ? '—' : _summaryValue(metric, latest!.value),
        latest == null ? '' : _summaryUnit(metric, latest!.value),
      ),
      _SummaryMetric(
        _maxLabel(metric),
        maximum == null ? '—' : _summaryValue(metric, maximum!),
        maximum == null ? '' : _summaryUnit(metric, maximum!),
      ),
    ],
  );
}

class _SummaryGridLike extends StatelessWidget {
  const _SummaryGridLike({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final child in children)
        SizedBox(
          width: (MediaQuery.sizeOf(context).width - AppSpacing.lg * 3) / 2,
          child: child,
        ),
    ],
  );
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final TrainingHistoryOverviewPeriod selected;
  final ValueChanged<TrainingHistoryOverviewPeriod> onSelected;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final period in TrainingHistoryOverviewPeriod.values)
          ChoiceChip(
            label: Text(period.label),
            selected: period == selected,
            onSelected: (_) => onSelected(period),
          ),
      ],
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview});

  final TrainingHistoryOverview overview;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 360
          ? (constraints.maxWidth - AppSpacing.sm) / 2
          : constraints.maxWidth;
      final cards = [
        _SummaryMetric('STRENGTH SESSIONS', '${overview.sessionCount}', ''),
        _SummaryMetric('STRENGTH DAYS', '${overview.trainingDays}', ''),
        _SummaryMetric(
          'RECORDED VOLUME',
          TrainingVolumeFormatter.display(overview.recordedVolume).value,
          TrainingVolumeFormatter.display(overview.recordedVolume).unit,
        ),
        _SummaryMetric('TOTAL REPS', '${overview.recordedReps}', 'reps'),
      ];
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final metric in cards) SizedBox(width: width, child: metric),
        ],
      );
    },
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric(this.label, this.value, this.unit);

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => OperationCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        AppSpacing.gapXS,
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        if (unit.isNotEmpty)
          Text(unit, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({
    required this.title,
    required this.points,
    required this.axisFormatter,
    required this.detailFormatter,
    this.weeklyBars = false,
    this.note,
  });

  final String title;
  final String? note;
  final List<_ChartPoint> points;
  final String Function(double value) axisFormatter;
  final String Function(double value) detailFormatter;
  final bool weeklyBars;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(icon: Icons.show_chart, title: title),
      if (note != null) ...[
        AppSpacing.gapXS,
        Text(note!, style: Theme.of(context).textTheme.bodySmall),
      ],
      AppSpacing.gapSM,
      OperationCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: weeklyBars
            ? _FrequencyBarChart(points: points)
            : _TrainingLineChart(
                points: points,
                axisFormatter: axisFormatter,
                detailFormatter: detailFormatter,
              ),
      ),
    ],
  );
}

class _TrainingLineChart extends StatefulWidget {
  const _TrainingLineChart({
    required this.points,
    required this.axisFormatter,
    required this.detailFormatter,
  });

  final List<_ChartPoint> points;
  final String Function(double value) axisFormatter;
  final String Function(double value) detailFormatter;

  @override
  State<_TrainingLineChart> createState() => _TrainingLineChartState();
}

class _TrainingLineChartState extends State<_TrainingLineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final values = widget.points.map((point) => point.value).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs();
    final verticalPadding = range == 0
        ? (maxValue.abs() * .15 + 1)
        : range * .15;
    final minY = (minValue - verticalPadding).clamp(0.0, double.infinity);
    final maxY = maxValue + verticalPadding;
    final selected = _selectedIndex == null
        ? null
        : widget.points[_selectedIndex!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              minX: widget.points.length == 1 ? -1 : 0,
              maxX: widget.points.length == 1 ? 1 : widget.points.length - 1,
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 3,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: .10),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
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
                    interval: (maxY - minY) / 3,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        widget.axisFormatter(value),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _labelInterval(widget.points.length),
                    getTitlesWidget: (value, _) {
                      final index = value.round();
                      if (index < 0 || index >= widget.points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _formatDate(widget.points[index].date),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchCallback: (_, response) {
                  final spot = response?.lineBarSpots?.firstOrNull;
                  if (spot == null) return;
                  setState(() => _selectedIndex = spot.x.round());
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        '${_formatDate(widget.points[spot.x.round()].date)}\n${widget.detailFormatter(spot.y)}',
                        Theme.of(context).textTheme.labelMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var index = 0; index < widget.points.length; index++)
                      FlSpot(index.toDouble(), widget.points[index].value),
                  ],
                  isCurved: false,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                      radius: _selectedIndex == spot.x.round() ? 4 : 2.5,
                      color: Theme.of(context).colorScheme.primary,
                      strokeColor: Theme.of(context).colorScheme.surface,
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected != null) ...[
          AppSpacing.gapXS,
          Text(
            '${_formatDate(selected.date)} · ${widget.detailFormatter(selected.value)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ],
    );
  }
}

class _ChartPoint {
  const _ChartPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

class _FrequencyBarChart extends StatefulWidget {
  const _FrequencyBarChart({required this.points});

  final List<_ChartPoint> points;

  @override
  State<_FrequencyBarChart> createState() => _FrequencyBarChartState();
}

class _FrequencyBarChartState extends State<_FrequencyBarChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final maximum = widget.points.fold<double>(
      1,
      (value, point) => point.value > value ? point.value : value,
    );
    final selected = _selectedIndex == null
        ? null
        : widget.points[_selectedIndex!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              maxY: maximum + 1,
              minY: 0,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.white.withValues(alpha: .10)),
              ),
              borderData: FlBorderData(show: false),
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
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, _) => Text(
                      value == value.roundToDouble()
                          ? value.toStringAsFixed(0)
                          : '',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _labelInterval(widget.points.length),
                    getTitlesWidget: (value, _) {
                      final index = value.round();
                      if (index < 0 || index >= widget.points.length)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _formatDate(widget.points[index].date),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchCallback: (_, response) {
                  final index = response?.spot?.touchedBarGroupIndex;
                  if (index != null) setState(() => _selectedIndex = index);
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    'WEEK OF ${_formatDate(widget.points[group.x.toInt()].date)}\n${rod.toY.toInt()} strength sessions',
                    Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var index = 0; index < widget.points.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: widget.points[index].value,
                        color: Theme.of(context).colorScheme.primary,
                        width: widget.points.length > 20 ? 5 : 10,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (selected != null) ...[
          AppSpacing.gapXS,
          Text(
            'WEEK OF ${_formatDate(selected.date)} · ${selected.value.toInt()} strength sessions',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ],
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) => const OperationCard(
    child: Text('TRAINING HISTORYはまだありません。正式なTraining Recordを保存すると表示されます。'),
  );
}

class _EmptyPeriodState extends StatelessWidget {
  const _EmptyPeriodState();

  @override
  Widget build(BuildContext context) =>
      const OperationCard(child: Text('この期間のTRAINING DATAはありません。期間を変更してください。'));
}

double _labelInterval(int count) => count <= 2 ? 1 : (count - 1) / 2;

String _formatDate(DateTime date) => '${date.month}/${date.day}';

String _formatInteger(double value) => value.round().toString();

String _formatWeight(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

double? _metricValue(ExerciseHistoryPoint point, _ExerciseMetric metric) =>
    switch (metric) {
      _ExerciseMetric.weight => point.maxWeight,
      _ExerciseMetric.reps => point.recordedReps.toDouble(),
      _ExerciseMetric.volume => point.recordedVolume,
    };

String _metricTitle(_ExerciseMetric metric) => switch (metric) {
  _ExerciseMetric.weight => 'WEIGHT',
  _ExerciseMetric.reps => 'REPS',
  _ExerciseMetric.volume => 'RECORDED VOLUME',
};

String _metricSelectorLabel(_ExerciseMetric metric) => switch (metric) {
  _ExerciseMetric.weight => 'WEIGHT',
  _ExerciseMetric.reps => 'REPS',
  _ExerciseMetric.volume => 'VOLUME',
};

String _latestLabel(_ExerciseMetric metric) => 'LATEST ${_metricTitle(metric)}';
String _maxLabel(_ExerciseMetric metric) => 'MAX ${_metricTitle(metric)}';

String _summaryValue(_ExerciseMetric metric, double value) => switch (metric) {
  _ExerciseMetric.weight => _formatWeight(value),
  _ExerciseMetric.reps => _formatInteger(value),
  _ExerciseMetric.volume => TrainingVolumeFormatter.display(value).value,
};

String _summaryUnit(_ExerciseMetric metric, double value) => switch (metric) {
  _ExerciseMetric.weight => 'kg',
  _ExerciseMetric.reps => 'reps',
  _ExerciseMetric.volume => TrainingVolumeFormatter.display(value).unit,
};

String Function(double) _axisFormatter(_ExerciseMetric metric) =>
    switch (metric) {
      _ExerciseMetric.weight => _formatWeight,
      _ExerciseMetric.reps => _formatInteger,
      _ExerciseMetric.volume => TrainingVolumeFormatter.axisLabel,
    };

String Function(double) _detailFormatter(_ExerciseMetric metric) =>
    switch (metric) {
      _ExerciseMetric.weight => (value) => '${_formatWeight(value)} kg',
      _ExerciseMetric.reps => (value) => '${_formatInteger(value)} reps',
      _ExerciseMetric.volume => TrainingVolumeFormatter.format,
    };
