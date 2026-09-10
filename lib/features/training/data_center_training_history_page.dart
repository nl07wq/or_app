import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/repositories/training_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import 'models/training_record_read_model.dart';
import 'services/training_history_overview_adapter.dart';
import 'services/training_volume_formatter.dart';

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
            AppSpacing.gapLG,
            if (all.isEmpty)
              const _EmptyHistoryState()
            else if (overview.isEmpty)
              const _EmptyPeriodState()
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
    this.note,
  });

  final String title;
  final String? note;
  final List<_ChartPoint> points;
  final String Function(double value) axisFormatter;
  final String Function(double value) detailFormatter;

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
        child: _TrainingLineChart(
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
