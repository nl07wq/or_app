import 'dart:math' as math;

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
                note: '月曜開始・週あたりのストレングスセッション数',
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

class _RecoveryView extends StatefulWidget {
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
  State<_RecoveryView> createState() => _RecoveryViewState();
}

class _RecoveryViewState extends State<_RecoveryView> {
  var _mode = _RecoveryMode.front;
  MuscleGroup? _selectedMuscle;

  List<TrainingRecoveryEvidence> _evidence() => widget.adapter.evidence(
    widget.records,
    period: widget.period,
    referenceDate: widget.referenceDate,
    customRange: widget.customRange,
    now: widget.now,
  );

  List<TrainingSupportInvolvement> _supportInvolvement() =>
      widget.adapter.supportInvolvement(
        widget.records,
        period: widget.period,
        referenceDate: widget.referenceDate,
        customRange: widget.customRange,
      );

  @override
  Widget build(BuildContext context) {
    final evidence = _evidence();
    final supportInvolvement = _supportInvolvement();
    final selectedMuscle =
        _selectedMuscle ??
        (evidence.isEmpty ? null : evidence.first.estimate.muscleGroup);
    final selectedEvidence = selectedMuscle == null
        ? null
        : evidence
              .where((item) => item.estimate.muscleGroup == selectedMuscle)
              .firstOrNull;
    final selectedSupport = selectedMuscle == null
        ? null
        : supportInvolvement
              .where((item) => item.muscle == selectedMuscle)
              .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.health_and_safety_outlined,
          title: '回復',
        ),
        AppSpacing.gapSM,
        _RecoveryModeSelector(
          selected: _mode,
          onSelected: (mode) => setState(() => _mode = mode),
        ),
        AppSpacing.gapSM,
        if (_mode == _RecoveryMode.list)
          if (evidence.isEmpty)
            const OperationCard(child: Text('この期間に回復エビデンスとなるトレーニング記録はありません。'))
          else
            for (final item in evidence) ...[
              _RecoveryEvidenceCard(evidence: item),
              if (item != evidence.last) AppSpacing.gapSM,
            ]
        else ...[
          _RecoveryBodyMap(
            evidence: evidence,
            supportInvolvement: supportInvolvement,
            side: _mode.bodyMapSide,
            selectedMuscle: selectedMuscle,
            onMuscleSelected: (muscle) =>
                setState(() => _selectedMuscle = muscle),
          ),
          AppSpacing.gapSM,
          if (selectedEvidence != null)
            _RecoveryEvidenceCard(evidence: selectedEvidence)
          else if (selectedSupport != null)
            _RecoverySupportDetail(involvement: selectedSupport)
          else if (selectedMuscle != null)
            _RecoveryNoDataDetail(muscle: selectedMuscle)
          else
            const _RecoveryNoDataSelectionPrompt(),
        ],
      ],
    );
  }
}

enum _BodyMapSide { front, back }

enum _RecoveryMode { front, back, list }

extension on _RecoveryMode {
  _BodyMapSide get bodyMapSide => switch (this) {
    _RecoveryMode.front => _BodyMapSide.front,
    _RecoveryMode.back => _BodyMapSide.back,
    _RecoveryMode.list => throw StateError('一覧 mode does not have a body map.'),
  };
}

class _RecoveryModeSelector extends StatelessWidget {
  const _RecoveryModeSelector({
    required this.selected,
    required this.onSelected,
  });

  final _RecoveryMode selected;
  final ValueChanged<_RecoveryMode> onSelected;

  @override
  Widget build(BuildContext context) => _CompactChoiceRow(
    labels: const ['前面', '背面', '一覧'],
    selectedIndex: selected.index,
    onSelected: (index) => onSelected(_RecoveryMode.values[index]),
  );
}

class _RecoveryBodyMap extends StatelessWidget {
  const _RecoveryBodyMap({
    required this.evidence,
    required this.supportInvolvement,
    required this.side,
    required this.selectedMuscle,
    required this.onMuscleSelected,
  });

  final List<TrainingRecoveryEvidence> evidence;
  final List<TrainingSupportInvolvement> supportInvolvement;
  final _BodyMapSide side;
  final MuscleGroup? selectedMuscle;
  final ValueChanged<MuscleGroup> onMuscleSelected;

  @override
  Widget build(BuildContext context) {
    final byMuscle = <MuscleGroup, TrainingRecoveryEvidence>{
      for (final item in evidence) item.estimate.muscleGroup: item,
    };
    final supportByMuscle = <MuscleGroup, TrainingSupportInvolvement>{
      for (final item in supportInvolvement) item.muscle: item,
    };
    return OperationCard(
      key: const ValueKey('recovery-body-map'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('BODY MAP', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('回復状態', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          AppSpacing.gapSM,
          _RecoveryBodyMapCanvas(
            side: side,
            evidenceByMuscle: byMuscle,
            supportByMuscle: supportByMuscle,
            selectedMuscle: selectedMuscle,
            onMuscleSelected: onMuscleSelected,
          ),
          AppSpacing.gapSM,
          _RecoveryBodyMapLegend(
            evidenceByMuscle: byMuscle,
            hasSupportInvolvement: supportByMuscle.isNotEmpty,
          ),
        ],
      ),
    );
  }
}

class _RecoveryBodyMapCanvas extends StatelessWidget {
  const _RecoveryBodyMapCanvas({
    required this.side,
    required this.evidenceByMuscle,
    required this.supportByMuscle,
    required this.selectedMuscle,
    required this.onMuscleSelected,
  });

  final _BodyMapSide side;
  final Map<MuscleGroup, TrainingRecoveryEvidence> evidenceByMuscle;
  final Map<MuscleGroup, TrainingSupportInvolvement> supportByMuscle;
  final MuscleGroup? selectedMuscle;
  final ValueChanged<MuscleGroup> onMuscleSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 224.0);
      final height = width * _bodyMapBaseHeight / _bodyMapBaseWidth;
      final size = Size(width, height);
      final regions = _bodyMapRegions(side, size);
      return Center(
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                key: ValueKey('body-map-${side.name}-canvas'),
                painter: _RecoveryBodyMapPainter(
                  side: side,
                  evidenceByMuscle: evidenceByMuscle,
                  supportByMuscle: supportByMuscle,
                  selectedMuscle: selectedMuscle,
                ),
              ),
              for (var index = 0; index < regions.length; index++)
                Positioned.fromRect(
                  rect: regions[index].hitBounds.intersect(Offset.zero & size),
                  child: Semantics(
                    button: true,
                    selected: selectedMuscle == regions[index].muscle,
                    label:
                        '${muscleGroupDisplayName(regions[index].muscle)} ${_bodyMapStatusLabel(evidenceByMuscle[regions[index].muscle], supportByMuscle.containsKey(regions[index].muscle))}',
                    child: GestureDetector(
                      key: ValueKey(
                        'body-map-region-${side.name}-${regions[index].muscle.name}-$index',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onMuscleSelected(regions[index].muscle),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _RecoveryBodyMapLegend extends StatelessWidget {
  const _RecoveryBodyMapLegend({
    required this.evidenceByMuscle,
    required this.hasSupportInvolvement,
  });

  final Map<MuscleGroup, TrainingRecoveryEvidence> evidenceByMuscle;
  final bool hasSupportInvolvement;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      RecoveryStatus.loaded,
      RecoveryStatus.recovering,
      RecoveryStatus.nearReady,
      RecoveryStatus.estimatedReady,
      RecoveryStatus.noData,
    ];
    final hasNoEvidence =
        evidenceByMuscle.length < activeRecoveryMuscleGroups.length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final status in statuses)
          _RecoveryBodyMapLegendItem(
            label: '状態: ${_recoveryStatusLabel(status)}',
            color: _recoveryStatusColor(status),
          ),
        if (hasNoEvidence)
          const _RecoveryBodyMapLegendItem(
            label: '状態: データなし',
            color: AppColors.secondary,
          ),
        if (hasSupportInvolvement)
          const _RecoveryBodyMapLegendItem(
            label: '補助筋として関与',
            color: AppColors.information,
            outlined: true,
          ),
      ],
    );
  }
}

class _RecoveryBodyMapLegendItem extends StatelessWidget {
  const _RecoveryBodyMapLegendItem({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: outlined ? Border.all(color: color, width: 1.5) : null,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _RecoveryBodyMapPainter extends CustomPainter {
  const _RecoveryBodyMapPainter({
    required this.side,
    required this.evidenceByMuscle,
    required this.supportByMuscle,
    required this.selectedMuscle,
  });

  final _BodyMapSide side;
  final Map<MuscleGroup, TrainingRecoveryEvidence> evidenceByMuscle;
  final Map<MuscleGroup, TrainingSupportInvolvement> supportByMuscle;
  final MuscleGroup? selectedMuscle;

  @override
  void paint(Canvas canvas, Size size) {
    final neutral = Paint()
      ..color = AppColors.secondary.withValues(alpha: .22)
      ..style = PaintingStyle.fill;
    for (final shape in _bodyMapSilhouettePaths(side, size)) {
      canvas.drawPath(shape, neutral);
    }
    for (final region in _bodyMapRegions(side, size)) {
      final evidence = evidenceByMuscle[region.muscle];
      final color = evidence == null
          ? AppColors.secondary
          : _recoveryStatusColor(evidence.estimate.status);
      final fill = Paint()
        ..color = color.withValues(alpha: evidence == null ? .36 : .78)
        ..style = PaintingStyle.fill;
      final shape = _bodyMapRegionPath(side, region, size);
      canvas.drawPath(shape, fill);
      if (supportByMuscle.containsKey(region.muscle)) {
        canvas.drawPath(
          shape,
          Paint()
            ..color = AppColors.information.withValues(alpha: .95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.75,
        );
      }
      if (selectedMuscle == region.muscle) {
        _drawBodyMapSelectionHighlight(canvas, shape, region.bounds);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RecoveryBodyMapPainter oldDelegate) =>
      side != oldDelegate.side ||
      selectedMuscle != oldDelegate.selectedMuscle ||
      evidenceByMuscle != oldDelegate.evidenceByMuscle ||
      supportByMuscle != oldDelegate.supportByMuscle;
}

void _drawBodyMapSelectionHighlight(Canvas canvas, Path shape, Rect bounds) {
  final center = bounds.center;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(1.07);
  canvas.translate(-center.dx, -center.dy);
  canvas.drawPath(
    shape,
    Paint()
      ..color = AppColors.textPrimary.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2,
  );
  canvas.restore();
}

class _BodyMapRegion {
  _BodyMapRegion(this.muscle, this.bounds, {Rect? hitBounds})
    : hitBounds =
          hitBounds ??
          Rect.fromLTRB(
            bounds.left - math.min(bounds.width * .18, 5),
            bounds.top - math.min(bounds.height * .08, 3),
            bounds.right + math.min(bounds.width * .18, 5),
            bounds.bottom + math.min(bounds.height * .08, 3),
          );

  final MuscleGroup muscle;
  final Rect bounds;
  final Rect hitBounds;
}

const _bodyMapBaseWidth = 200.0;
const _bodyMapBaseHeight = 340.0;

List<_BodyMapRegion> _bodyMapRegions(_BodyMapSide side, Size size) {
  final x = size.width / _bodyMapBaseWidth;
  final y = size.height / _bodyMapBaseHeight;
  Rect region(double left, double top, double width, double height) =>
      Rect.fromLTWH(left * x, top * y, width * x, height * y);
  List<_BodyMapRegion> paired(MuscleGroup muscle, Rect left, Rect right) => [
    _BodyMapRegion(muscle, left),
    _BodyMapRegion(muscle, right),
  ];
  if (side == _BodyMapSide.front) {
    return [
      _BodyMapRegion(
        MuscleGroup.shoulders,
        region(54, 58, 33, 30),
        hitBounds: region(56, 60, 28, 26),
      ),
      _BodyMapRegion(
        MuscleGroup.shoulders,
        region(113, 58, 33, 30),
        hitBounds: region(116, 60, 28, 26),
      ),
      ...paired(
        MuscleGroup.chest,
        region(58, 83, 40, 42),
        region(102, 83, 40, 42),
      ),
      ...paired(
        MuscleGroup.biceps,
        region(34, 86, 27, 51),
        region(139, 86, 27, 51),
      ),
      ...paired(
        MuscleGroup.forearms,
        region(29, 136, 24, 52),
        region(147, 136, 24, 52),
      ),
      _BodyMapRegion(MuscleGroup.core, region(70, 126, 60, 52)),
      ...paired(
        MuscleGroup.quadriceps,
        region(61, 180, 34, 66),
        region(105, 180, 34, 66),
      ),
    ];
  }
  return [
    _BodyMapRegion(
      MuscleGroup.shoulders,
      region(54, 58, 33, 30),
      hitBounds: region(56, 60, 28, 26),
    ),
    _BodyMapRegion(
      MuscleGroup.shoulders,
      region(113, 58, 33, 30),
      hitBounds: region(116, 60, 28, 26),
    ),
    ...paired(
      MuscleGroup.lats,
      region(55, 105, 41, 57),
      region(104, 105, 41, 57),
    ),
    _BodyMapRegion(
      MuscleGroup.trapezius,
      region(53, 50, 94, 64),
      hitBounds: region(82, 50, 36, 64),
    ),
    ...paired(
      MuscleGroup.triceps,
      region(34, 86, 27, 51),
      region(139, 86, 27, 51),
    ),
    ...paired(
      MuscleGroup.forearms,
      region(29, 136, 24, 52),
      region(147, 136, 24, 52),
    ),
    ...paired(
      MuscleGroup.glutes,
      region(62, 164, 36, 34),
      region(102, 164, 36, 34),
    ),
    ...paired(
      MuscleGroup.hamstrings,
      region(61, 198, 34, 49),
      region(105, 198, 34, 49),
    ),
    ...paired(
      MuscleGroup.calves,
      region(61, 249, 31, 78),
      region(108, 249, 31, 78),
    ),
  ];
}

List<Path> _bodyMapSilhouettePaths(_BodyMapSide side, Size size) =>
    side == _BodyMapSide.front
    ? _frontBodySilhouettePaths(size)
    : _backBodySilhouettePaths(size);

List<Path> _frontBodySilhouettePaths(Size size) {
  Offset point(double x, double y) => Offset(
    x * size.width / _bodyMapBaseWidth,
    y * size.height / _bodyMapBaseHeight,
  );
  Path path(
    void Function(Path path, Offset Function(double, double) point) build,
  ) {
    final result = Path();
    build(result, point);
    return result;
  }

  return [
    Path()..addOval(
      Rect.fromCenter(
        center: point(100, 30),
        width: 32 * size.width / _bodyMapBaseWidth,
        height: 40 * size.height / _bodyMapBaseHeight,
      ),
    ),
    path((body, p) {
      body
        ..moveTo(p(88, 49).dx, p(88, 49).dy)
        ..cubicTo(
          p(86, 56).dx,
          p(86, 56).dy,
          p(68, 57).dx,
          p(68, 57).dy,
          p(57, 66).dx,
          p(57, 66).dy,
        )
        ..cubicTo(
          p(53, 84).dx,
          p(53, 84).dy,
          p(61, 110).dx,
          p(61, 110).dy,
          p(69, 129).dx,
          p(69, 129).dy,
        )
        ..cubicTo(
          p(72, 145).dx,
          p(72, 145).dy,
          p(74, 161).dx,
          p(74, 161).dy,
          p(68, 177).dx,
          p(68, 177).dy,
        )
        ..cubicTo(
          p(76, 186).dx,
          p(76, 186).dy,
          p(87, 190).dx,
          p(87, 190).dy,
          p(100, 190).dx,
          p(100, 190).dy,
        )
        ..cubicTo(
          p(113, 190).dx,
          p(113, 190).dy,
          p(124, 186).dx,
          p(124, 186).dy,
          p(132, 177).dx,
          p(132, 177).dy,
        )
        ..cubicTo(
          p(126, 161).dx,
          p(126, 161).dy,
          p(128, 145).dx,
          p(128, 145).dy,
          p(131, 129).dx,
          p(131, 129).dy,
        )
        ..cubicTo(
          p(139, 110).dx,
          p(139, 110).dy,
          p(147, 84).dx,
          p(147, 84).dy,
          p(143, 66).dx,
          p(143, 66).dy,
        )
        ..cubicTo(
          p(132, 57).dx,
          p(132, 57).dy,
          p(114, 56).dx,
          p(114, 56).dy,
          p(112, 49).dx,
          p(112, 49).dy,
        )
        ..close();
    }),
    path((arm, p) {
      arm
        ..moveTo(p(59, 67).dx, p(59, 67).dy)
        ..cubicTo(
          p(48, 74).dx,
          p(48, 74).dy,
          p(42, 93).dx,
          p(42, 93).dy,
          p(38, 112).dx,
          p(38, 112).dy,
        )
        ..cubicTo(
          p(34, 133).dx,
          p(34, 133).dy,
          p(31, 157).dx,
          p(31, 157).dy,
          p(33, 178).dx,
          p(33, 178).dy,
        )
        ..cubicTo(
          p(34, 189).dx,
          p(34, 189).dy,
          p(41, 193).dx,
          p(41, 193).dy,
          p(47, 185).dx,
          p(47, 185).dy,
        )
        ..cubicTo(
          p(50, 164).dx,
          p(50, 164).dy,
          p(55, 143).dx,
          p(55, 143).dy,
          p(59, 124).dx,
          p(59, 124).dy,
        )
        ..cubicTo(
          p(66, 98).dx,
          p(66, 98).dy,
          p(69, 80).dx,
          p(69, 80).dy,
          p(59, 67).dx,
          p(59, 67).dy,
        )
        ..close();
    }),
    path((arm, p) {
      arm
        ..moveTo(p(141, 67).dx, p(141, 67).dy)
        ..cubicTo(
          p(152, 74).dx,
          p(152, 74).dy,
          p(158, 93).dx,
          p(158, 93).dy,
          p(162, 112).dx,
          p(162, 112).dy,
        )
        ..cubicTo(
          p(166, 133).dx,
          p(166, 133).dy,
          p(169, 157).dx,
          p(169, 157).dy,
          p(167, 178).dx,
          p(167, 178).dy,
        )
        ..cubicTo(
          p(166, 189).dx,
          p(166, 189).dy,
          p(159, 193).dx,
          p(159, 193).dy,
          p(153, 185).dx,
          p(153, 185).dy,
        )
        ..cubicTo(
          p(150, 164).dx,
          p(150, 164).dy,
          p(145, 143).dx,
          p(145, 143).dy,
          p(141, 124).dx,
          p(141, 124).dy,
        )
        ..cubicTo(
          p(134, 98).dx,
          p(134, 98).dy,
          p(131, 80).dx,
          p(131, 80).dy,
          p(141, 67).dx,
          p(141, 67).dy,
        )
        ..close();
    }),
    path((leg, p) {
      leg
        ..moveTo(p(70, 174).dx, p(70, 174).dy)
        ..cubicTo(
          p(62, 193).dx,
          p(62, 193).dy,
          p(62, 221).dx,
          p(62, 221).dy,
          p(65, 244).dx,
          p(65, 244).dy,
        )
        ..cubicTo(
          p(63, 266).dx,
          p(63, 266).dy,
          p(60, 292).dx,
          p(60, 292).dy,
          p(62, 326).dx,
          p(62, 326).dy,
        )
        ..cubicTo(
          p(67, 334).dx,
          p(67, 334).dy,
          p(80, 334).dx,
          p(80, 334).dy,
          p(86, 326).dx,
          p(86, 326).dy,
        )
        ..cubicTo(
          p(90, 298).dx,
          p(90, 298).dy,
          p(95, 268).dx,
          p(95, 268).dy,
          p(94, 244).dx,
          p(94, 244).dy,
        )
        ..cubicTo(
          p(93, 215).dx,
          p(93, 215).dy,
          p(92, 190).dx,
          p(92, 190).dy,
          p(84, 176).dx,
          p(84, 176).dy,
        )
        ..close();
    }),
    path((leg, p) {
      leg
        ..moveTo(p(130, 174).dx, p(130, 174).dy)
        ..cubicTo(
          p(138, 193).dx,
          p(138, 193).dy,
          p(138, 221).dx,
          p(138, 221).dy,
          p(135, 244).dx,
          p(135, 244).dy,
        )
        ..cubicTo(
          p(137, 266).dx,
          p(137, 266).dy,
          p(140, 292).dx,
          p(140, 292).dy,
          p(138, 326).dx,
          p(138, 326).dy,
        )
        ..cubicTo(
          p(133, 334).dx,
          p(133, 334).dy,
          p(120, 334).dx,
          p(120, 334).dy,
          p(114, 326).dx,
          p(114, 326).dy,
        )
        ..cubicTo(
          p(110, 298).dx,
          p(110, 298).dy,
          p(105, 268).dx,
          p(105, 268).dy,
          p(106, 244).dx,
          p(106, 244).dy,
        )
        ..cubicTo(
          p(107, 215).dx,
          p(107, 215).dy,
          p(108, 190).dx,
          p(108, 190).dy,
          p(116, 176).dx,
          p(116, 176).dy,
        )
        ..close();
    }),
  ];
}

List<Path> _backBodySilhouettePaths(Size size) {
  Offset point(double x, double y) => Offset(
    x * size.width / _bodyMapBaseWidth,
    y * size.height / _bodyMapBaseHeight,
  );
  Path build(
    void Function(Path path, Offset Function(double, double) point) draw,
  ) {
    final path = Path();
    draw(path, point);
    return path;
  }

  return [
    Path()..addOval(
      Rect.fromCenter(
        center: point(100, 30),
        width: 30 * size.width / _bodyMapBaseWidth,
        height: 39 * size.height / _bodyMapBaseHeight,
      ),
    ),
    build((body, p) {
      body
        ..moveTo(p(87, 49).dx, p(87, 49).dy)
        ..quadraticBezierTo(
          p(86, 58).dx,
          p(78, 60).dy,
          p(67, 62).dx,
          p(67, 62).dy,
        )
        ..quadraticBezierTo(
          p(56, 68).dx,
          p(55, 90).dy,
          p(61, 112).dx,
          p(61, 112).dy,
        )
        ..quadraticBezierTo(
          p(66, 130).dx,
          p(70, 145).dy,
          p(69, 158).dx,
          p(69, 158).dy,
        )
        ..quadraticBezierTo(
          p(67, 170).dx,
          p(63, 179).dy,
          p(66, 187).dx,
          p(66, 187).dy,
        )
        ..quadraticBezierTo(
          p(75, 197).dx,
          p(87, 200).dy,
          p(100, 200).dx,
          p(100, 200).dy,
        )
        ..quadraticBezierTo(
          p(113, 200).dx,
          p(125, 197).dy,
          p(134, 187).dx,
          p(134, 187).dy,
        )
        ..quadraticBezierTo(
          p(137, 179).dx,
          p(133, 170).dy,
          p(131, 158).dx,
          p(131, 158).dy,
        )
        ..quadraticBezierTo(
          p(130, 145).dx,
          p(134, 130).dy,
          p(139, 112).dx,
          p(139, 112).dy,
        )
        ..quadraticBezierTo(
          p(145, 90).dx,
          p(144, 68).dy,
          p(133, 62).dx,
          p(133, 62).dy,
        )
        ..quadraticBezierTo(
          p(122, 60).dx,
          p(114, 58).dy,
          p(113, 49).dx,
          p(113, 49).dy,
        )
        ..close();
    }),
    build((arm, p) {
      arm
        ..moveTo(p(61, 66).dx, p(61, 66).dy)
        ..quadraticBezierTo(
          p(49, 72).dx,
          p(43, 93).dy,
          p(40, 113).dx,
          p(40, 113).dy,
        )
        ..quadraticBezierTo(
          p(36, 135).dx,
          p(32, 160).dy,
          p(34, 181).dx,
          p(34, 181).dy,
        )
        ..quadraticBezierTo(
          p(35, 191).dx,
          p(41, 195).dy,
          p(46, 188).dx,
          p(46, 188).dy,
        )
        ..quadraticBezierTo(
          p(49, 166).dx,
          p(54, 145).dy,
          p(58, 125).dx,
          p(58, 125).dy,
        )
        ..quadraticBezierTo(
          p(65, 100).dx,
          p(68, 80).dy,
          p(61, 66).dx,
          p(61, 66).dy,
        )
        ..close();
    }),
    build((arm, p) {
      arm
        ..moveTo(p(139, 66).dx, p(139, 66).dy)
        ..quadraticBezierTo(
          p(151, 72).dx,
          p(157, 93).dy,
          p(160, 113).dx,
          p(160, 113).dy,
        )
        ..quadraticBezierTo(
          p(164, 135).dx,
          p(168, 160).dy,
          p(166, 181).dx,
          p(166, 181).dy,
        )
        ..quadraticBezierTo(
          p(165, 191).dx,
          p(159, 195).dy,
          p(154, 188).dx,
          p(154, 188).dy,
        )
        ..quadraticBezierTo(
          p(151, 166).dx,
          p(146, 145).dy,
          p(142, 125).dx,
          p(142, 125).dy,
        )
        ..quadraticBezierTo(
          p(135, 100).dx,
          p(132, 80).dy,
          p(139, 66).dx,
          p(139, 66).dy,
        )
        ..close();
    }),
    build((leg, p) {
      leg
        ..moveTo(p(68, 184).dx, p(68, 184).dy)
        ..quadraticBezierTo(
          p(61, 205).dx,
          p(61, 226).dy,
          p(65, 246).dx,
          p(65, 246).dy,
        )
        ..quadraticBezierTo(
          p(60, 266).dx,
          p(59, 294).dy,
          p(62, 326).dx,
          p(62, 326).dy,
        )
        ..quadraticBezierTo(
          p(67, 334).dx,
          p(80, 334).dy,
          p(86, 326).dx,
          p(86, 326).dy,
        )
        ..quadraticBezierTo(
          p(91, 299).dx,
          p(95, 270).dy,
          p(93, 246).dx,
          p(93, 246).dy,
        )
        ..quadraticBezierTo(
          p(94, 220).dx,
          p(92, 198).dy,
          p(84, 185).dx,
          p(84, 185).dy,
        )
        ..close();
    }),
    build((leg, p) {
      leg
        ..moveTo(p(132, 184).dx, p(132, 184).dy)
        ..quadraticBezierTo(
          p(139, 205).dx,
          p(139, 226).dy,
          p(135, 246).dx,
          p(135, 246).dy,
        )
        ..quadraticBezierTo(
          p(140, 266).dx,
          p(141, 294).dy,
          p(138, 326).dx,
          p(138, 326).dy,
        )
        ..quadraticBezierTo(
          p(133, 334).dx,
          p(120, 334).dy,
          p(114, 326).dx,
          p(114, 326).dy,
        )
        ..quadraticBezierTo(
          p(109, 299).dx,
          p(105, 270).dy,
          p(107, 246).dx,
          p(107, 246).dy,
        )
        ..quadraticBezierTo(
          p(106, 220).dx,
          p(108, 198).dy,
          p(116, 185).dx,
          p(116, 185).dy,
        )
        ..close();
    }),
  ];
}

Path _bodyMapRegionPath(_BodyMapSide side, _BodyMapRegion region, Size size) {
  final bounds = region.bounds;
  final left = bounds.center.dx < size.width / 2;
  switch (region.muscle) {
    case MuscleGroup.shoulders:
      return _bodyMapShoulderPath(
        bounds,
        left: left,
        rear: side == _BodyMapSide.back,
      );
    case MuscleGroup.chest:
      return _bodyMapChestPath(bounds, left: left);
    case MuscleGroup.trapezius:
      return _bodyMapTrapeziusPath(bounds);
    case MuscleGroup.lats:
      return _bodyMapLatPath(bounds, left: left);
    case MuscleGroup.core:
      return _bodyMapCorePath(bounds);
    case MuscleGroup.glutes:
      return _bodyMapGlutePath(bounds, left: left);
    case MuscleGroup.calves:
      return _bodyMapCalfPath(bounds, left: left);
    case MuscleGroup.biceps:
      return _bodyMapBicepsPath(bounds, left: left);
    case MuscleGroup.triceps:
      return _bodyMapTricepsPath(bounds, left: left);
    case MuscleGroup.forearms:
      return _bodyMapForearmPath(bounds, left: left);
    case MuscleGroup.quadriceps:
      return _bodyMapQuadricepsPath(bounds, left: left);
    case MuscleGroup.hamstrings:
      return _bodyMapHamstringPath(bounds, left: left);
    case MuscleGroup.back:
      throw StateError('Legacy BACK has no active Body Map region.');
  }
}

Path _bodyMapShoulderPath(Rect rect, {required bool left, required bool rear}) {
  final inner = left ? rect.right : rect.left;
  final outer = left ? rect.left : rect.right;
  final path = Path()..moveTo(inner, rect.top + rect.height * .22);
  path
    ..cubicTo(
      rect.center.dx,
      rear ? rect.top : rect.top + rect.height * .06,
      outer,
      rear ? rect.top + rect.height * .2 : rect.top + rect.height * .25,
      outer,
      rect.top + rect.height * .62,
    )
    ..cubicTo(
      outer,
      rect.bottom - rect.height * .16,
      rect.center.dx + (left ? -rect.width * .05 : rect.width * .05),
      rect.bottom,
      rect.center.dx,
      rect.bottom,
    )
    ..quadraticBezierTo(
      inner,
      rect.bottom - rect.height * .1,
      inner,
      rect.top + rect.height * .22,
    )
    ..close();
  return path;
}

Path _bodyMapBicepsPath(Rect rect, {required bool left}) {
  final outer = left ? rect.left : rect.right;
  final inner = left ? rect.right : rect.left;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..cubicTo(
      outer,
      rect.top + rect.height * .08,
      outer,
      rect.bottom - rect.height * .12,
      outer + (left ? rect.width * .08 : -rect.width * .08),
      rect.bottom,
    )
    ..cubicTo(
      rect.center.dx,
      rect.bottom + rect.height * .02,
      inner,
      rect.bottom - rect.height * .12,
      inner,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapTricepsPath(Rect rect, {required bool left}) {
  final outer = left ? rect.left : rect.right;
  final inner = left ? rect.right : rect.left;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..cubicTo(
      outer,
      rect.top + rect.height * .04,
      outer,
      rect.bottom - rect.height * .1,
      outer + (left ? rect.width * .06 : -rect.width * .06),
      rect.bottom,
    )
    ..cubicTo(
      inner,
      rect.bottom - rect.height * .14,
      inner,
      rect.top + rect.height * .12,
      inner,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapForearmPath(Rect rect, {required bool left}) {
  final outer = left ? rect.left : rect.right;
  final inner = left ? rect.right : rect.left;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..cubicTo(
      outer,
      rect.top + rect.height * .1,
      outer,
      rect.bottom - rect.height * .22,
      outer + (left ? rect.width * .1 : -rect.width * .1),
      rect.bottom,
    )
    ..cubicTo(
      rect.center.dx,
      rect.bottom + rect.height * .02,
      inner,
      rect.bottom - rect.height * .14,
      inner,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapQuadricepsPath(Rect rect, {required bool left}) {
  final outer = left ? rect.left : rect.right;
  final inner = left ? rect.right : rect.left;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..cubicTo(
      outer,
      rect.top + rect.height * .08,
      outer,
      rect.bottom - rect.height * .16,
      outer,
      rect.bottom,
    )
    ..quadraticBezierTo(
      rect.center.dx,
      rect.bottom + rect.height * .02,
      inner,
      rect.bottom,
    )
    ..cubicTo(
      inner,
      rect.top + rect.height * .14,
      inner,
      rect.top + rect.height * .04,
      inner,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapHamstringPath(Rect rect, {required bool left}) {
  final outer = left ? rect.left : rect.right;
  final inner = left ? rect.right : rect.left;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..cubicTo(
      outer,
      rect.top + rect.height * .06,
      outer,
      rect.bottom - rect.height * .12,
      outer,
      rect.bottom,
    )
    ..quadraticBezierTo(
      rect.center.dx,
      rect.bottom + rect.height * .02,
      inner,
      rect.bottom,
    )
    ..cubicTo(
      inner,
      rect.top + rect.height * .18,
      inner,
      rect.top + rect.height * .05,
      inner,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapChestPath(Rect rect, {required bool left}) {
  final inner = left ? rect.right : rect.left;
  final outer = left ? rect.left : rect.right;
  final path = Path()..moveTo(inner, rect.top + rect.height * .12);
  path
    ..cubicTo(
      rect.center.dx,
      rect.top,
      outer,
      rect.top + rect.height * .14,
      outer,
      rect.top + rect.height * .4,
    )
    ..cubicTo(
      outer,
      rect.bottom - rect.height * .12,
      rect.center.dx,
      rect.bottom,
      inner,
      rect.bottom - rect.height * .16,
    )
    ..cubicTo(
      inner,
      rect.center.dy,
      inner,
      rect.top + rect.height * .18,
      inner,
      rect.top + rect.height * .12,
    )
    ..close();
  return path;
}

Path _bodyMapTrapeziusPath(Rect rect) {
  final path = Path()..moveTo(rect.center.dx - rect.width * .1, rect.top);
  path
    ..cubicTo(
      rect.left + rect.width * .3,
      rect.top + rect.height * .14,
      rect.left + rect.width * .08,
      rect.top + rect.height * .28,
      rect.left,
      rect.top + rect.height * .48,
    )
    ..cubicTo(
      rect.left + rect.width * .2,
      rect.bottom - rect.height * .02,
      rect.center.dx - rect.width * .14,
      rect.bottom,
      rect.center.dx,
      rect.bottom - rect.height * .16,
    )
    ..cubicTo(
      rect.center.dx + rect.width * .14,
      rect.bottom,
      rect.right - rect.width * .2,
      rect.bottom - rect.height * .02,
      rect.right,
      rect.top + rect.height * .48,
    )
    ..cubicTo(
      rect.right - rect.width * .08,
      rect.top + rect.height * .28,
      rect.center.dx + rect.width * .3,
      rect.top + rect.height * .14,
      rect.center.dx + rect.width * .1,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapLatPath(Rect rect, {required bool left}) {
  final inner = left ? rect.right : rect.left;
  final outer = left ? rect.left : rect.right;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..cubicTo(
      rect.center.dx,
      rect.top + rect.height * .04,
      outer,
      rect.top + rect.height * .2,
      outer,
      rect.top + rect.height * .44,
    )
    ..cubicTo(
      outer,
      rect.bottom - rect.height * .16,
      rect.center.dx,
      rect.bottom,
      inner,
      rect.bottom,
    )
    ..cubicTo(
      inner,
      rect.bottom - rect.height * .24,
      inner,
      rect.top + rect.height * .14,
      inner,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapCorePath(Rect rect) {
  final path = Path()..moveTo(rect.left + rect.width * .18, rect.top);
  path
    ..quadraticBezierTo(
      rect.center.dx,
      rect.top,
      rect.right - rect.width * .18,
      rect.top,
    )
    ..cubicTo(
      rect.right - rect.width * .06,
      rect.top + rect.height * .42,
      rect.right - rect.width * .18,
      rect.bottom,
      rect.center.dx,
      rect.bottom,
    )
    ..cubicTo(
      rect.left + rect.width * .18,
      rect.bottom,
      rect.left + rect.width * .06,
      rect.top + rect.height * .42,
      rect.left + rect.width * .18,
      rect.top,
    )
    ..close();
  return path;
}

Path _bodyMapGlutePath(Rect rect, {required bool left}) {
  final inner = left ? rect.right : rect.left;
  final outer = left ? rect.left : rect.right;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..quadraticBezierTo(
      rect.center.dx,
      rect.top + rect.height * .04,
      outer,
      rect.top + rect.height * .16,
    )
    ..cubicTo(
      outer,
      rect.bottom - rect.height * .08,
      rect.center.dx,
      rect.bottom,
      inner,
      rect.bottom,
    )
    ..quadraticBezierTo(inner, rect.center.dy, inner, rect.top)
    ..close();
  return path;
}

Path _bodyMapCalfPath(Rect rect, {required bool left}) {
  final inner = left ? rect.right : rect.left;
  final outer = left ? rect.left : rect.right;
  final path = Path()..moveTo(inner, rect.top);
  path
    ..cubicTo(
      outer,
      rect.top + rect.height * .08,
      outer,
      rect.top + rect.height * .5,
      outer + (left ? rect.width * .1 : -rect.width * .1),
      rect.bottom - rect.height * .12,
    )
    ..quadraticBezierTo(
      rect.center.dx,
      rect.bottom,
      inner,
      rect.bottom - rect.height * .1,
    )
    ..cubicTo(
      inner,
      rect.top + rect.height * .5,
      inner,
      rect.top + rect.height * .08,
      inner,
      rect.top,
    )
    ..close();
  return path;
}

String _bodyMapStatusLabel(
  TrainingRecoveryEvidence? evidence,
  bool hasSupportInvolvement,
) {
  final status = evidence == null
      ? 'データなし'
      : _recoveryStatusLabel(evidence.estimate.status);
  return hasSupportInvolvement ? '$status・補助筋として関与' : status;
}

class _RecoveryNoDataSelectionPrompt extends StatelessWidget {
  const _RecoveryNoDataSelectionPrompt();

  @override
  Widget build(BuildContext context) =>
      const OperationCard(child: Text('Body Mapから部位を選択してください。'));
}

class _RecoveryNoDataDetail extends StatelessWidget {
  const _RecoveryNoDataDetail({required this.muscle});

  final MuscleGroup muscle;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: ValueKey('recovery-no-data-detail-${muscle.name}'),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          muscleGroupDisplayName(muscle),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        AppSpacing.gapXS,
        const Text('データなし'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'この期間にRecovery Evidenceはありません。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _RecoverySupportDetail extends StatelessWidget {
  const _RecoverySupportDetail({required this.involvement});

  final TrainingSupportInvolvement involvement;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: ValueKey('recovery-support-detail-${involvement.muscle.name}'),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          muscleGroupDisplayName(involvement.muscle),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        AppSpacing.gapXS,
        const Text('補助筋として関与'),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '最終関与: ${involvement.startTime == null ? involvement.operationDate : _formatRecoveryDateTime(involvement.startTime!)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          '種目: ${involvement.source.exerciseLabel}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (involvement.source.equipmentLabel != null)
          Text(
            'EQUIPMENT: ${involvement.source.equipmentLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    ),
  );
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
      key: ValueKey('recovery-card-${estimate.muscleGroup.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
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
              _RecoveryStatusBadge(
                muscleGroup: estimate.muscleGroup,
                status: estimate.status,
              ),
            ],
          ),
          AppSpacing.gapSM,
          if (hasProgress) ...[
            _RecoveryReferenceRow(
              duration: estimate.referenceRecoveryDuration!,
              estimatedReadyAt: estimate.estimatedReadyAt!,
            ),
            AppSpacing.gapSM,
            _RecoveryGauge(
              muscleGroup: estimate.muscleGroup,
              progress: progress,
              status: estimate.status,
            ),
            AppSpacing.gapMD,
            _RecoveryEvidenceGrid(
              lastTrained: exactTime == null
                  ? estimate.lastExposureOperationDate!
                  : _formatRecoveryDateTime(exactTime),
              isDateOnly: exactTime == null,
              exercise: evidence.source.exerciseLabel,
              equipment:
                  evidence.source.equipmentLabel ?? 'EQUIPMENT NOT RECORDED',
            ),
          ] else ...[
            _RecoveryEvidenceGrid(
              lastTrained: exactTime == null
                  ? estimate.lastExposureOperationDate!
                  : _formatRecoveryDateTime(exactTime),
              isDateOnly: exactTime == null,
              exercise: evidence.source.exerciseLabel,
              equipment:
                  evidence.source.equipmentLabel ?? 'EQUIPMENT NOT RECORDED',
            ),
            AppSpacing.gapSM,
            _RecoveryEvidenceField(
              label: '回復基準',
              value: estimate.referenceRecoveryDuration == null
                  ? '未設定'
                  : _formatRecoveryDuration(
                      estimate.referenceRecoveryDuration!,
                    ),
            ),
            if (estimate.referenceRecoveryDuration != null &&
                estimate.precision == RecoveryPrecision.dateOnly) ...[
              AppSpacing.gapXS,
              const _RecoveryEvidenceField(
                label: '基準回復進行',
                value: '算出不可（時刻精度: 日付のみ）',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RecoveryStatusBadge extends StatelessWidget {
  const _RecoveryStatusBadge({required this.muscleGroup, required this.status});

  final MuscleGroup muscleGroup;
  final RecoveryStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _recoveryStatusColor(status);
    return Semantics(
      label: '回復状態 ${_recoveryStatusLabel(status)}',
      child: Container(
        key: ValueKey('recovery-status-badge-${muscleGroup.name}'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .65)),
        ),
        child: Text(
          _recoveryStatusLabel(status),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RecoveryReferenceRow extends StatelessWidget {
  const _RecoveryReferenceRow({
    required this.duration,
    required this.estimatedReadyAt,
  });

  final Duration duration;
  final DateTime estimatedReadyAt;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('recovery-reference-ready-row'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _RecoveryEvidenceField(
          key: const ValueKey('recovery-reference-field'),
          label: '回復基準',
          value: _formatRecoveryDuration(duration),
        ),
      ),
      Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        color: AppColors.divider,
      ),
      Expanded(
        child: _RecoveryEvidenceField(
          key: const ValueKey('recovery-ready-field'),
          label: '回復目安',
          value: _formatRecoveryReadyAt(estimatedReadyAt),
        ),
      ),
    ],
  );
}

class _RecoveryGauge extends StatelessWidget {
  const _RecoveryGauge({
    required this.muscleGroup,
    required this.progress,
    required this.status,
  });

  final MuscleGroup muscleGroup;
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
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                key: ValueKey('recovery-gauge-track-${muscleGroup.name}'),
                height: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .14),
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  key: ValueKey('recovery-gauge-fill-${muscleGroup.name}'),
                  width: constraints.maxWidth * progress,
                  height: double.infinity,
                  child: ColoredBox(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryEvidenceGrid extends StatelessWidget {
  const _RecoveryEvidenceGrid({
    required this.lastTrained,
    required this.isDateOnly,
    required this.exercise,
    required this.equipment,
  });

  final String lastTrained;
  final bool isDateOnly;
  final String exercise;
  final String equipment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final lastTrainedField = _RecoveryEvidenceField(
        key: const ValueKey('recovery-evidence-last-trained'),
        label: '最終実施',
        value: lastTrained,
        secondaryLabel: isDateOnly ? '時刻精度' : null,
        secondaryValue: isDateOnly ? '日付のみ' : null,
      );
      final exerciseField = _RecoveryEvidenceField(
        key: const ValueKey('recovery-evidence-exercise'),
        label: '種目',
        value: exercise,
      );
      final equipmentField = _RecoveryEvidenceField(
        key: const ValueKey('recovery-evidence-equipment'),
        label: 'EQUIPMENT',
        value: equipment,
      );
      final twoColumnDetails = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: exerciseField),
          const SizedBox(width: AppSpacing.sm),
          Expanded(flex: 6, child: equipmentField),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          lastTrainedField,
          AppSpacing.gapSM,
          if (constraints.maxWidth >= 300)
            twoColumnDetails
          else ...[
            exerciseField,
            AppSpacing.gapXS,
            equipmentField,
          ],
        ],
      );
    },
  );
}

class _RecoveryEvidenceField extends StatelessWidget {
  const _RecoveryEvidenceField({
    super.key,
    required this.label,
    required this.value,
    this.secondaryLabel,
    this.secondaryValue,
  });

  final String label;
  final String value;
  final String? secondaryLabel;
  final String? secondaryValue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (secondaryLabel != null && secondaryValue != null) ...[
        AppSpacing.gapXS,
        Text(secondaryLabel!, style: Theme.of(context).textTheme.labelSmall),
        Text(secondaryValue!),
      ],
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
        AppSpacing.gapXS,
        _HistoryConditionSelectorCard(
          key: const Key('exercise-category-selector-card'),
          child: DropdownButton<String>(
            key: const Key('exercise-category-selector'),
            isExpanded: true,
            isDense: true,
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
        AppSpacing.gapMD,
        const _SelectorCaption('EQUIPMENT'),
        AppSpacing.gapXS,
        _HistoryConditionSelectorCard(
          key: const Key('exercise-equipment-selector-card'),
          child: DropdownButton<_EquipmentSelection>(
            key: const Key('exercise-equipment-selector'),
            isExpanded: true,
            isDense: true,
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

class _HistoryConditionSelectorCard extends StatelessWidget {
  const _HistoryConditionSelectorCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => OperationCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );
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
      labels: const ['総ボリューム', 'メインセット'],
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
        compactId: 'last-trained',
      ),
      _SummaryMetric(
        _exerciseSummaryLabel(_latestLabel(metric, volumeMetric), metric),
        latest == null
            ? '—'
            : _summaryValue(metric, volumeMetric, latest!.value),
        latest == null ? '' : _summaryUnit(metric, volumeMetric, latest!.value),
        compact: true,
        compactId: 'latest-summary',
      ),
      if (metric != _ExerciseMetric.rpe)
        _SummaryMetric(
          _exerciseSummaryLabel(_maxLabel(metric, volumeMetric), metric),
          maximum == null ? '—' : _summaryValue(metric, volumeMetric, maximum!),
          maximum == null ? '' : _summaryUnit(metric, volumeMetric, maximum!),
          compact: true,
          compactId: 'max-summary',
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
          compactId: 'latest-comparison',
        ),
        if (previous != null) ...[
          _SummaryMetric(
            'PREVIOUS',
            _summaryValue(metric, volumeMetric, previous.value),
            _summaryUnit(metric, volumeMetric, previous.value),
            compact: true,
            compactId: 'previous-comparison',
          ),
          _SummaryMetric(
            'CHANGE',
            _deltaValue(metric, volumeMetric, latest.value - previous.value),
            _summaryUnit(metric, volumeMetric, latest.value - previous.value),
            compact: true,
            compactId: 'change-comparison',
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
    this.compactId,
  });

  final String label;
  final String value;
  final String unit;
  final bool compact;
  final String? compactId;

  @override
  Widget build(BuildContext context) {
    final compactLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 8,
      height: 1.15,
      letterSpacing: -.25,
    );
    return OperationCard(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 2, vertical: AppSpacing.sm)
          : const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact && label.contains('\n'))
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  key: compactId == null
                      ? null
                      : ValueKey('metric-label-$compactId'),
                  maxLines: 2,
                  style: compactLabelStyle,
                ),
              ),
            )
          else
            Text(
              label,
              key: compactId == null
                  ? null
                  : ValueKey('metric-label-$compactId'),
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: compact
                  ? compactLabelStyle
                  : Theme.of(context).textTheme.labelSmall,
            ),
          AppSpacing.gapXS,
          Center(
            child: _MetricValueUnit(
              value: value,
              unit: unit,
              valueKey: compactId == null
                  ? null
                  : ValueKey('metric-value-$compactId'),
              unitKey: compactId == null
                  ? null
                  : ValueKey('metric-unit-$compactId'),
              valueStyle: compact
                  ? Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 20)
                  : Theme.of(context).textTheme.headlineSmall,
              unitStyle: compact
                  ? Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(fontSize: 10)
                  : Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricValueUnit extends StatelessWidget {
  const _MetricValueUnit({
    required this.value,
    required this.unit,
    required this.valueStyle,
    required this.unitStyle,
    this.valueKey,
    this.unitKey,
  });

  final String value;
  final String unit;
  final TextStyle? valueStyle;
  final TextStyle? unitStyle;
  final Key? valueKey;
  final Key? unitKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: constraints.maxWidth,
      child: FittedBox(
        alignment: Alignment.center,
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(key: valueKey, value, style: valueStyle),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(key: unitKey, unit, style: unitStyle),
            ],
          ],
        ),
      ),
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

String _exerciseSummaryLabel(String label, _ExerciseMetric metric) =>
    metric == _ExerciseMetric.volume
    ? label.replaceFirst(' VOLUME', '\nVOLUME')
    : label;

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
