import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/repositories/training_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import 'models/training_record_read_model.dart';
import 'services/training_history_overview_adapter.dart';
import 'services/training_history_range_preference.dart';
import 'services/training_volume_formatter.dart';
import 'services/training_exercise_history_adapter.dart';
import 'services/training_exercise_identity.dart';
import 'services/training_history_domain_service.dart';
import 'services/training_recovery_evidence_adapter.dart';

/// Data Center analytics. The existing TrainingHistoryPage remains the raw
/// formal-record list and is intentionally not reused as this page.
class DataCenterTrainingHistoryPage extends StatefulWidget {
  const DataCenterTrainingHistoryPage({
    super.key,
    this.recordsLoader,
    this.overviewAdapter = const TrainingHistoryOverviewAdapter(),
    this.clock,
    this.rangePreference,
    this.recoveryAdapter,
  });

  final Future<List<TrainingRecordReadModel>> Function()? recordsLoader;
  final TrainingHistoryOverviewAdapter overviewAdapter;
  final DateTime Function()? clock;
  final TrainingHistoryRangePreference? rangePreference;
  final TrainingRecoveryEvidenceAdapter? recoveryAdapter;

  @override
  State<DataCenterTrainingHistoryPage> createState() =>
      _DataCenterTrainingHistoryPageState();
}

class _DataCenterTrainingHistoryPageState
    extends State<DataCenterTrainingHistoryPage> {
  late final Future<List<TrainingRecordReadModel>> _records;
  late final TrainingHistoryRangePreference _rangePreference;
  var _period = TrainingHistoryOverviewPeriod.oneWeek;
  DateTimeRange? _customRange;
  var _view = _TrainingHistoryView.overview;
  var _exerciseMetric = _ExerciseMetric.weight;
  var _volumeMetric = _VolumeMetric.recorded;
  String? _selectedCategory;
  TrainingExerciseIdentity? _selectedEquipment;
  var _allEquipment = false;
  static const _exerciseAdapter = TrainingExerciseHistoryAdapter();
  late final TrainingRecoveryEvidenceAdapter _recoveryAdapter;

  @override
  void initState() {
    super.initState();
    _rangePreference =
        widget.rangePreference ?? TrainingHistoryRangePreference();
    _recoveryAdapter =
        widget.recoveryAdapter ?? const TrainingRecoveryEvidenceAdapter();
    _records = _restoreAndLoad();
  }

  Future<List<TrainingRecordReadModel>> _restoreAndLoad() async {
    final selection = await _rangePreference.load();
    if (mounted) {
      _period = selection.period;
      _customRange = selection.customRange;
    }
    return (widget.recordsLoader ?? TrainingRepository.getReadModels)();
  }

  Future<void> _selectPeriod(TrainingHistoryOverviewPeriod period) async {
    if (period == TrainingHistoryOverviewPeriod.custom) {
      final now = widget.clock?.call() ?? DateTime.now();
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: _customRange,
        helpText: 'SELECT TRAINING HISTORY RANGE',
        saveText: 'USE RANGE',
      );
      if (selected == null || !mounted) return;
      _customRange = selected;
    }
    if (!mounted) return;
    setState(() => _period = period);
    await _rangePreference.save(period, customRange: _customRange);
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
          customRange: _customRange,
        );
        final displayRange = widget.overviewAdapter.selectedRange(
          period: _period,
          referenceDate: widget.clock?.call(),
          customRange: _customRange,
        );
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.query_stats_outlined,
              title: 'TRAINING HISTORY',
            ),
            AppSpacing.gapSM,
            _PeriodSelector(selected: _period, onSelected: _selectPeriod),
            AppSpacing.gapSM,
            Text(
              '表示期間: ${_formatDate(displayRange.start)} – '
              '${_formatDate(displayRange.end)}',
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
                customRange: _customRange,
                selectedCategory: _selectedCategory,
                selectedEquipment: _selectedEquipment,
                allEquipment: _allEquipment,
                metric: _exerciseMetric,
                volumeMetric: _volumeMetric,
                onCategorySelected: (category) => setState(() {
                  _selectedCategory = category;
                  _selectedEquipment = null;
                  _allEquipment = false;
                }),
                onEquipmentSelected: (identity) => setState(() {
                  _selectedEquipment = identity;
                  _allEquipment = false;
                }),
                onAllEquipmentSelected: () =>
                    setState(() => _allEquipment = true),
                onMetricSelected: (metric) =>
                    setState(() => _exerciseMetric = metric),
                onVolumeMetricSelected: (metric) =>
                    setState(() => _volumeMetric = metric),
                adapter: _exerciseAdapter,
              )
            else if (_view == _TrainingHistoryView.recovery)
              _RecoveryView(
                records: snapshot.requireData,
                period: _period,
                referenceDate: widget.clock?.call(),
                customRange: _customRange,
                now: widget.clock?.call() ?? DateTime.now(),
                adapter: _recoveryAdapter,
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

enum _TrainingHistoryView { overview, exercise, recovery }

enum _ExerciseMetric { weight, reps, volume, rpe }

enum _VolumeMetric { recorded, working }

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
            label: Text(switch (view) {
              _TrainingHistoryView.overview => '概要',
              _TrainingHistoryView.exercise => '種目',
              _TrainingHistoryView.recovery => '回復',
            }),
            selected: selected == view,
            onSelected: (_) => onSelected(view),
          ),
      ],
    ),
  );
}

class _RecoveryView extends StatelessWidget {
  const _RecoveryView({
    required this.records,
    required this.period,
    required this.referenceDate,
    required this.customRange,
    required this.now,
    required this.adapter,
  });

  final List<TrainingRecordReadModel> records;
  final TrainingHistoryOverviewPeriod period;
  final DateTime? referenceDate;
  final DateTimeRange? customRange;
  final DateTime now;
  final TrainingRecoveryEvidenceAdapter adapter;

  @override
  Widget build(BuildContext context) {
    final evidence = adapter.evidence(
      records,
      period: period,
      referenceDate: referenceDate,
      customRange: customRange,
      now: now,
    );
    if (evidence.isEmpty) {
      return const OperationCard(child: Text('この期間に回復エビデンスとなるトレーニング記録はありません。'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.health_and_safety_outlined,
          title: '回復',
        ),
        AppSpacing.gapSM,
        for (final item in evidence) ...[
          _RecoveryEvidenceCard(evidence: item),
          AppSpacing.gapSM,
        ],
      ],
    );
  }
}

class _RecoveryEvidenceCard extends StatelessWidget {
  const _RecoveryEvidenceCard({required this.evidence});

  final TrainingRecoveryEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final estimate = evidence.estimate;
    final exactTime = estimate.lastExposureDateTime;
    final progress = estimate.displayProgressRatio;
    final hasProgress =
        estimate.precision == RecoveryPrecision.exact && progress != null;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                muscleGroupDisplayName(estimate.muscleGroup),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (hasProgress)
                Text(
                  _recoveryStatusLabel(estimate.status),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _recoveryStatusColor(estimate.status),
                  ),
                ),
            ],
          ),
          AppSpacing.gapSM,
          if (hasProgress) ...[
            _RecoveryGauge(progress: progress, status: estimate.status),
            AppSpacing.gapSM,
          ],
          _RecoveryEvidenceField(
            label: '最終実施',
            value: exactTime == null
                ? estimate.lastExposureOperationDate!
                : _formatRecoveryDateTime(exactTime),
          ),
          if (exactTime == null) ...[
            AppSpacing.gapXS,
            const _RecoveryEvidenceField(label: '時刻精度', value: '日付のみ'),
          ],
          AppSpacing.gapSM,
          _RecoveryEvidenceField(
            label: '種目',
            value: evidence.source.exerciseLabel,
          ),
          if (evidence.source.equipmentLabel != null) ...[
            AppSpacing.gapXS,
            _RecoveryEvidenceField(
              label: 'EQUIPMENT',
              value: evidence.source.equipmentLabel!,
            ),
          ] else ...[
            AppSpacing.gapXS,
            const _RecoveryEvidenceField(
              label: 'EQUIPMENT',
              value: 'EQUIPMENT NOT RECORDED',
            ),
          ],
          AppSpacing.gapSM,
          _RecoveryEvidenceField(
            label: '回復基準',
            value: estimate.referenceRecoveryDuration == null
                ? '未設定'
                : _formatRecoveryDuration(estimate.referenceRecoveryDuration!),
          ),
          if (estimate.referenceRecoveryDuration != null && !hasProgress) ...[
            AppSpacing.gapXS,
            _RecoveryEvidenceField(
              label: '基準回復進行',
              value: estimate.precision == RecoveryPrecision.dateOnly
                  ? '算出不可（時刻精度: 日付のみ）'
                  : '算出不可',
            ),
          ],
          if (hasProgress) ...[
            AppSpacing.gapXS,
            _RecoveryEvidenceField(
              label: '回復目安',
              value: _formatRecoveryReadyAt(estimate.estimatedReadyAt!),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecoveryGauge extends StatelessWidget {
  const _RecoveryGauge({required this.progress, required this.status});

  final double progress;
  final RecoveryStatus status;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    final color = _recoveryStatusColor(status);
    return Semantics(
      label: '基準回復進行 $percent% ${_recoveryStatusLabel(status)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('基準回復進行', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Text('$percent%', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          AppSpacing.gapXS,
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryEvidenceField extends StatelessWidget {
  const _RecoveryEvidenceField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(value),
    ],
  );
}

class _ExerciseView extends StatelessWidget {
  const _ExerciseView({
    required this.records,
    required this.period,
    required this.referenceDate,
    required this.customRange,
    required this.selectedCategory,
    required this.selectedEquipment,
    required this.allEquipment,
    required this.metric,
    required this.volumeMetric,
    required this.onCategorySelected,
    required this.onEquipmentSelected,
    required this.onAllEquipmentSelected,
    required this.onMetricSelected,
    required this.onVolumeMetricSelected,
    required this.adapter,
  });
  final List<TrainingRecordReadModel> records;
  final TrainingHistoryOverviewPeriod period;
  final DateTime? referenceDate;
  final DateTimeRange? customRange;
  final String? selectedCategory;
  final TrainingExerciseIdentity? selectedEquipment;
  final bool allEquipment;
  final _ExerciseMetric metric;
  final _VolumeMetric volumeMetric;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<TrainingExerciseIdentity> onEquipmentSelected;
  final VoidCallback onAllEquipmentSelected;
  final ValueChanged<_ExerciseMetric> onMetricSelected;
  final ValueChanged<_VolumeMetric> onVolumeMetricSelected;
  final TrainingExerciseHistoryAdapter adapter;
  @override
  Widget build(BuildContext context) {
    final allPoints = adapter.points(
      records,
      period: period,
      referenceDate: referenceDate,
      customRange: customRange,
    );
    final categories = adapter.categories(allPoints);
    if (categories.isEmpty) return const _EmptyPeriodState();
    final category = categories.any((item) => item.key == selectedCategory)
        ? categories.firstWhere((item) => item.key == selectedCategory)
        : categories.first;
    final variants = adapter.equipmentVariants(allPoints, category.key);
    final variant = variants.any((item) => item.identity == selectedEquipment)
        ? variants.firstWhere((item) => item.identity == selectedEquipment)
        : variants.first;
    final showAllEquipment = allEquipment && variants.length > 1;
    final points = showAllEquipment
        ? const <ExerciseHistoryPoint>[]
        : adapter.forIdentity(allPoints, variant.identity);
    final metricPoints = [
      for (final point in points)
        if (_metricValue(point, metric, volumeMetric) case final value?)
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
        const _SelectorCaption('EXERCISE'),
        AppSpacing.gapSM,
        OperationCard(
          child: DropdownButton<String>(
            key: const Key('exercise-category-selector'),
            isExpanded: true,
            value: category.key,
            items: [
              for (final item in categories)
                DropdownMenuItem(
                  value: item.key,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value != null) onCategorySelected(value);
            },
          ),
        ),
        AppSpacing.gapLG,
        const _SelectorCaption('EQUIPMENT'),
        AppSpacing.gapSM,
        OperationCard(
          child: DropdownButton<_EquipmentSelection>(
            key: const Key('exercise-equipment-selector'),
            isExpanded: true,
            value: showAllEquipment
                ? const _EquipmentSelection.all()
                : _EquipmentSelection.specific(variant),
            items: [
              if (variants.length > 1)
                const DropdownMenuItem(
                  value: _EquipmentSelection.all(),
                  child: Text('ALL EQUIPMENT'),
                ),
              for (final item in variants)
                DropdownMenuItem(
                  value: _EquipmentSelection.specific(item),
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value.isAll) {
                onAllEquipmentSelected();
              } else {
                onEquipmentSelected(value.variant!.identity);
              }
            },
          ),
        ),
        AppSpacing.gapMD,
        _ExerciseMetricSelector(selected: metric, onSelected: onMetricSelected),
        if (metric == _ExerciseMetric.volume) ...[
          AppSpacing.gapSM,
          _VolumeMetricSelector(
            selected: volumeMetric,
            onSelected: onVolumeMetricSelected,
          ),
        ],
        AppSpacing.gapMD,
        if (showAllEquipment)
          const _AllEquipmentState()
        else ...[
          _ExerciseSummary(
            points: points,
            metric: metric,
            volumeMetric: volumeMetric,
            latest: latest,
            maximum: maximum,
          ),
          AppSpacing.gapLG,
          if (metricPoints.isEmpty)
            _MetricUnavailableState(metric: metric, volumeMetric: volumeMetric)
          else ...[
            _LatestPreviousChange(
              metric: metric,
              volumeMetric: volumeMetric,
              points: metricPoints,
            ),
            AppSpacing.gapLG,
            _MetricSection(
              title: '${_metricTitle(metric, volumeMetric)} HISTORY',
              points: metricPoints,
              axisFormatter: _axisFormatter(metric, volumeMetric),
              detailFormatter: _detailFormatter(metric, volumeMetric),
              minimumY: metric == _ExerciseMetric.rpe ? 1 : null,
              maximumY: metric == _ExerciseMetric.rpe ? 10 : null,
            ),
          ],
        ],
      ],
    );
  }
}

class _SelectorCaption extends StatelessWidget {
  const _SelectorCaption(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.labelSmall);
}

class _AllEquipmentState extends StatelessWidget {
  const _AllEquipmentState();
  @override
  Widget build(BuildContext context) => const OperationCard(
    child: Text(
      'SELECT EQUIPMENT TO VIEW WEIGHT, REPS, VOLUME, OR RPE HISTORY',
    ),
  );
}

class _EquipmentSelection {
  const _EquipmentSelection.all() : variant = null;
  const _EquipmentSelection.specific(this.variant);

  final TrainingExerciseEquipmentVariant? variant;
  bool get isAll => variant == null;

  @override
  bool operator ==(Object other) =>
      other is _EquipmentSelection && other.variant == variant;

  @override
  int get hashCode => variant.hashCode;
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
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: _CompactChoiceRow(
      labels: [
        for (final metric in _ExerciseMetric.values)
          _metricSelectorLabel(metric),
      ],
      selectedIndex: selected.index,
      onSelected: (index) => onSelected(_ExerciseMetric.values[index]),
    ),
  );
}

class _VolumeMetricSelector extends StatelessWidget {
  const _VolumeMetricSelector({
    required this.selected,
    required this.onSelected,
  });

  final _VolumeMetric selected;
  final ValueChanged<_VolumeMetric> onSelected;

  @override
  Widget build(BuildContext context) => OperationCard(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: _CompactChoiceRow(
      labels: const ['RECORDED', 'WORKING'],
      selectedIndex: selected.index,
      onSelected: (index) => onSelected(_VolumeMetric.values[index]),
    ),
  );
}

class _CompactChoiceRow extends StatelessWidget {
  const _CompactChoiceRow({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < labels.length; index++) ...[
        if (index > 0) const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: ChoiceChip(
            label: SizedBox(
              width: double.infinity,
              child: Text(labels[index], textAlign: TextAlign.center),
            ),
            labelPadding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            selected: selectedIndex == index,
            onSelected: (_) => onSelected(index),
          ),
        ),
      ],
    ],
  );
}

class _ExerciseSummary extends StatelessWidget {
  const _ExerciseSummary({
    required this.points,
    required this.metric,
    required this.volumeMetric,
    required this.latest,
    required this.maximum,
  });
  final List<ExerciseHistoryPoint> points;
  final _ExerciseMetric metric;
  final _VolumeMetric volumeMetric;
  final _ChartPoint? latest;
  final double? maximum;
  @override
  Widget build(BuildContext context) => _SummaryGridLike(
    children: [
      _SummaryMetric(
        'LAST TRAINED',
        _formatDate(DateTime.parse(points.last.operationDate)),
        '',
        compact: true,
      ),
      _SummaryMetric(
        _latestLabel(metric, volumeMetric),
        latest == null
            ? '—'
            : _summaryValue(metric, volumeMetric, latest!.value),
        latest == null ? '' : _summaryUnit(metric, volumeMetric, latest!.value),
        compact: true,
      ),
      if (metric != _ExerciseMetric.rpe)
        _SummaryMetric(
          _maxLabel(metric, volumeMetric),
          maximum == null ? '—' : _summaryValue(metric, volumeMetric, maximum!),
          maximum == null ? '' : _summaryUnit(metric, volumeMetric, maximum!),
          compact: true,
        ),
    ],
  );
}

class _MetricUnavailableState extends StatelessWidget {
  const _MetricUnavailableState({
    required this.metric,
    required this.volumeMetric,
  });

  final _ExerciseMetric metric;
  final _VolumeMetric volumeMetric;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_metricTitle(metric, volumeMetric)} DATA NOT AVAILABLE'),
        if (metric == _ExerciseMetric.volume &&
            volumeMetric == _VolumeMetric.working) ...[
          AppSpacing.gapXS,
          const Text(
            'Working-set classification is not recorded for this history.',
          ),
        ],
      ],
    ),
  );
}

class _LatestPreviousChange extends StatelessWidget {
  const _LatestPreviousChange({
    required this.metric,
    required this.volumeMetric,
    required this.points,
  });

  final _ExerciseMetric metric;
  final _VolumeMetric volumeMetric;
  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final latest = points.last;
    final previous = points.length < 2 ? null : points[points.length - 2];
    return _SummaryGridLike(
      children: [
        _SummaryMetric(
          'LATEST',
          _summaryValue(metric, volumeMetric, latest.value),
          _summaryUnit(metric, volumeMetric, latest.value),
          compact: true,
        ),
        if (previous != null) ...[
          _SummaryMetric(
            'PREVIOUS',
            _summaryValue(metric, volumeMetric, previous.value),
            _summaryUnit(metric, volumeMetric, previous.value),
            compact: true,
          ),
          _SummaryMetric(
            'CHANGE',
            _deltaValue(metric, volumeMetric, latest.value - previous.value),
            _summaryUnit(metric, volumeMetric, latest.value - previous.value),
            compact: true,
          ),
        ],
      ],
    );
  }
}

class _SummaryGridLike extends StatelessWidget {
  const _SummaryGridLike({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < 3; index++) ...[
        if (index > 0) const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: index < children.length ? children[index] : const SizedBox(),
        ),
      ],
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
  const _SummaryMetric(
    this.label,
    this.value,
    this.unit, {
    this.compact = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      padding: compact
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.md,
            )
          : const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: compact
                ? Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1.15,
                    letterSpacing: 0,
                  )
                : Theme.of(context).textTheme.labelSmall,
          ),
          AppSpacing.gapXS,
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: compact
                ? Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 20)
                : Theme.of(context).textTheme.headlineSmall,
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: compact
                  ? Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(fontSize: 10)
                  : Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({
    required this.title,
    required this.points,
    required this.axisFormatter,
    required this.detailFormatter,
    this.weeklyBars = false,
    this.note,
    this.minimumY,
    this.maximumY,
  });

  final String title;
  final String? note;
  final List<_ChartPoint> points;
  final String Function(double value) axisFormatter;
  final String Function(double value) detailFormatter;
  final bool weeklyBars;
  final double? minimumY;
  final double? maximumY;

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
                minimumY: minimumY,
                maximumY: maximumY,
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
    this.minimumY,
    this.maximumY,
  });

  final List<_ChartPoint> points;
  final String Function(double value) axisFormatter;
  final String Function(double value) detailFormatter;
  final double? minimumY;
  final double? maximumY;

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
    final minY =
        widget.minimumY ??
        (minValue - verticalPadding).clamp(0.0, double.infinity);
    final maxY = widget.maximumY ?? maxValue + verticalPadding;
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

String _formatRecoveryDateTime(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _formatRecoveryReadyAt(DateTime date) =>
    '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _formatRecoveryDuration(Duration duration) => '${duration.inHours}時間';

String _recoveryStatusLabel(RecoveryStatus status) => switch (status) {
  RecoveryStatus.loaded => '負荷直後',
  RecoveryStatus.recovering => '回復中',
  RecoveryStatus.nearReady => '回復目安に接近',
  RecoveryStatus.estimatedReady => '回復目安到達',
  RecoveryStatus.noData => '算出不可',
};

Color _recoveryStatusColor(RecoveryStatus status) => switch (status) {
  RecoveryStatus.loaded => AppColors.danger,
  RecoveryStatus.recovering => AppColors.warning,
  RecoveryStatus.nearReady => AppColors.primary,
  RecoveryStatus.estimatedReady => AppColors.success,
  RecoveryStatus.noData => AppColors.secondary,
};

String _formatInteger(double value) => value.round().toString();

String _formatWeight(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

double? _metricValue(
  ExerciseHistoryPoint point,
  _ExerciseMetric metric,
  _VolumeMetric volumeMetric,
) => switch (metric) {
  _ExerciseMetric.weight => point.maxWeight,
  _ExerciseMetric.reps => point.recordedReps.toDouble(),
  _ExerciseMetric.volume =>
    volumeMetric == _VolumeMetric.recorded
        ? point.recordedVolume
        : point.workingSetCount == null || point.workingSetCount == 0
        ? null
        : point.workingVolume,
  _ExerciseMetric.rpe => point.recordedRpeAverage,
};

String _metricTitle(_ExerciseMetric metric, _VolumeMetric volumeMetric) =>
    switch (metric) {
      _ExerciseMetric.weight => 'WEIGHT',
      _ExerciseMetric.reps => 'REPS',
      _ExerciseMetric.volume =>
        volumeMetric == _VolumeMetric.recorded
            ? 'RECORDED VOLUME'
            : 'WORKING VOLUME',
      _ExerciseMetric.rpe => 'RPE',
    };

String _metricSelectorLabel(_ExerciseMetric metric) => switch (metric) {
  _ExerciseMetric.weight => 'WEIGHT',
  _ExerciseMetric.reps => 'REPS',
  _ExerciseMetric.volume => 'VOLUME',
  _ExerciseMetric.rpe => 'RPE',
};

String _latestLabel(_ExerciseMetric metric, _VolumeMetric volumeMetric) =>
    'LATEST ${_metricTitle(metric, volumeMetric)}';
String _maxLabel(_ExerciseMetric metric, _VolumeMetric volumeMetric) =>
    'MAX ${_metricTitle(metric, volumeMetric)}';

String _summaryValue(
  _ExerciseMetric metric,
  _VolumeMetric volumeMetric,
  double value,
) => switch (metric) {
  _ExerciseMetric.weight => _formatWeight(value),
  _ExerciseMetric.reps => _formatInteger(value),
  _ExerciseMetric.volume => TrainingVolumeFormatter.display(value).value,
  _ExerciseMetric.rpe => value.toStringAsFixed(1),
};

String _summaryUnit(
  _ExerciseMetric metric,
  _VolumeMetric volumeMetric,
  double value,
) => switch (metric) {
  _ExerciseMetric.weight => 'kg',
  _ExerciseMetric.reps => 'reps',
  _ExerciseMetric.volume => TrainingVolumeFormatter.display(value).unit,
  _ExerciseMetric.rpe => '',
};

String _deltaValue(
  _ExerciseMetric metric,
  _VolumeMetric volumeMetric,
  double value,
) {
  final prefix = value > 0 ? '+' : '';
  return '$prefix${_summaryValue(metric, volumeMetric, value)}';
}

String Function(double) _axisFormatter(
  _ExerciseMetric metric,
  _VolumeMetric volumeMetric,
) => switch (metric) {
  _ExerciseMetric.weight => _formatWeight,
  _ExerciseMetric.reps => _formatInteger,
  _ExerciseMetric.volume => TrainingVolumeFormatter.axisLabel,
  _ExerciseMetric.rpe => (value) => value.toStringAsFixed(0),
};

String Function(double) _detailFormatter(
  _ExerciseMetric metric,
  _VolumeMetric volumeMetric,
) => switch (metric) {
  _ExerciseMetric.weight => (value) => '${_formatWeight(value)} kg',
  _ExerciseMetric.reps => (value) => '${_formatInteger(value)} reps',
  _ExerciseMetric.volume => TrainingVolumeFormatter.format,
  _ExerciseMetric.rpe => (value) => value.toStringAsFixed(1),
};
