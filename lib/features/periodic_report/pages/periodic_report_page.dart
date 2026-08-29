import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/models/operation_calendar_period.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../body_history/theme/history_metric_color_registry.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../repositories/app_repository_container.dart';
import '../../report_sync/models/report_sync_history.dart';
import '../../training/services/exercise_name_localization.dart';
import '../models/periodic_report.dart';
import '../services/periodic_report_presentation_formatter.dart';
import '../services/periodic_report_service.dart';
import '../widgets/periodic_report_chart.dart';

class PeriodicReportPage extends StatelessWidget {
  const PeriodicReportPage({
    super.key,
    required this.initialType,
    this.initialAnchor,
  });

  final PeriodicReportType initialType;
  final DateTime? initialAnchor;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${_label(initialType)} REPORT')),
    body: PeriodicReportPanel(
      reportType: initialType,
      initialAnchor: initialAnchor,
    ),
  );
}

class PeriodicReportWorkspace extends StatelessWidget {
  const PeriodicReportWorkspace({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 3,
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SectionHeader(
            icon: Symbols.calendar_month,
            title: 'PERIODIC REPORT',
          ),
        ),
        TabBar(
          tabs: [
            Tab(text: 'WEEKLY'),
            Tab(text: 'MONTHLY'),
            Tab(text: 'YEARLY'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              PeriodicReportPanel(reportType: PeriodicReportType.weekly),
              PeriodicReportPanel(reportType: PeriodicReportType.monthly),
              PeriodicReportPanel(reportType: PeriodicReportType.yearly),
            ],
          ),
        ),
      ],
    ),
  );
}

class PeriodicReportPanel extends StatefulWidget {
  const PeriodicReportPanel({
    super.key,
    required this.reportType,
    this.initialAnchor,
  });

  final PeriodicReportType reportType;
  final DateTime? initialAnchor;

  @override
  State<PeriodicReportPanel> createState() => _PeriodicReportPanelState();
}

class _PeriodicReportPanelState extends State<PeriodicReportPanel> {
  final _responseController = TextEditingController();
  late Future<_PeriodicReportViewData> _data = _load();
  DateTime? _anchor;
  PeriodicReportPreparation? _preparation;
  PeriodicReportPreview? _preview;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<_PeriodicReportViewData> _load() async {
    final container = AppRepositoryRegistry.container;
    final state = await container.operationState.requireCurrent();
    final operationDate = DateTime.parse(state.operationDate.value);
    _anchor ??=
        widget.initialAnchor ??
        _latestCompletedAnchor(widget.reportType, operationDate);
    final selected = _period(widget.reportType, _anchor!);
    final reports = await container.periodicReports.list(
      type: widget.reportType,
    );
    final dailyFacts = widget.reportType == PeriodicReportType.yearly
        ? const <DailyAggregateV1>[]
        : await container.dailyAggregates.getRange(
            _date(selected.start),
            _date(selected.end),
          );
    final monthlyFacts = widget.reportType != PeriodicReportType.yearly
        ? const <PeriodicReportRecord>[]
        : (await container.periodicReports.list(
                type: PeriodicReportType.monthly,
              ))
              .where(
                (report) =>
                    report.periodStart.startsWith('${selected.start.year}-'),
              )
              .toList();
    return _PeriodicReportViewData(
      operationDate: operationDate,
      selected: selected,
      reports: reports,
      dailyFacts: dailyFacts,
      monthlyFacts: monthlyFacts,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_PeriodicReportViewData>(
    future: _data,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return Center(
            child: Text('PERIODIC REPORT UNAVAILABLE\n${snapshot.error}'),
          );
        }
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.requireData;
      final selectedRecord = data.reports
          .where((value) => value.id == data.selected.id)
          .firstOrNull;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _ReportHeaderCard(
                reportType: widget.reportType,
                period: data.selected,
                report: selectedRecord,
                busy: _busy,
                canMoveNext: _period(
                  widget.reportType,
                  _moveAnchor(_anchor!, widget.reportType, 1),
                ).isCompleteAt(data.operationDate),
                onPrevious: () => _move(-1),
                onNext: () => _move(1),
                onCreate: _prepare,
              ),
              if (_preparation != null) ...[
                AppSpacing.gapMD,
                OperationCard(
                  key: const ValueKey('periodic-report-import-card'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        icon: Symbols.auto_awesome,
                        title: 'REPORT IMPORT',
                      ),
                      AppSpacing.gapMD,
                      OperationButton(
                        text: 'COPY PROMPT',
                        icon: Symbols.content_copy,
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _preparation!.prompt),
                          );
                          if (mounted) {
                            setState(() => _message = 'PROMPT COPIED');
                          }
                        },
                      ),
                      AppSpacing.gapLG,
                      TextField(
                        key: const ValueKey('periodic-report-response-input'),
                        controller: _responseController,
                        minLines: 5,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'CHATGPT RESPONSE JSON',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      AppSpacing.gapMD,
                      _PeriodicResponseActionBar(
                        enabled: !_busy,
                        onPaste: _pasteResponse,
                        onClear: _clearResponse,
                        onValidate: _previewResponse,
                      ),
                    ],
                  ),
                ),
              ],
              if (_preview != null) ...[
                AppSpacing.gapMD,
                _PreviewCard(preview: _preview!, busy: _busy, onApply: _apply),
              ],
              if (selectedRecord != null) ...[
                AppSpacing.gapMD,
                _ReportViewer(
                  report: selectedRecord,
                  dailyFacts: data.dailyFacts,
                  monthlyFacts: data.monthlyFacts,
                ),
              ],
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _pasteResponse() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    setState(() {
      _responseController.text = data!.text!;
      _preview = null;
      _message = null;
    });
  }

  void _clearResponse() {
    setState(() {
      _responseController.clear();
      _preview = null;
      _message = null;
    });
  }

  Future<void> _prepare() => _run(() async {
    _preparation = await PeriodicReportService().prepare(
      type: widget.reportType,
      anchor: _anchor!,
    );
    _preview = null;
    _message = 'FORMAL FACT PACKAGE READY';
  });

  Future<void> _previewResponse() => _run(() async {
    _preview = await PeriodicReportService().preview(
      type: widget.reportType,
      anchor: _anchor!,
      rawResponse: _responseController.text,
    );
    _message = 'RESPONSE VALIDATED';
  });

  Future<void> _apply() => _run(() async {
    await PeriodicReportService().apply(_preview!);
    _preview = null;
    _preparation = null;
    _responseController.clear();
    _message = 'REPORT IMPORTED';
    _data = _load();
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      debugPrint('PERIODIC REPORT IMPORT: $error');
      _message = periodicReportErrorMessage(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _move(int direction) {
    setState(() {
      _anchor = _moveAnchor(_anchor!, widget.reportType, direction);
      _preparation = null;
      _preview = null;
      _message = null;
      _data = _load();
    });
  }
}

@visibleForTesting
String periodicReportErrorMessage(Object error) {
  if (error is FormatException &&
      error.message.toString().contains('completedAt precedes startedAt')) {
    return 'REPORT TIME INVALID';
  }
  return error.toString();
}

class _ReportHeaderCard extends StatelessWidget {
  const _ReportHeaderCard({
    required this.reportType,
    required this.period,
    required this.report,
    required this.busy,
    required this.canMoveNext,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
  });

  final PeriodicReportType reportType;
  final OperationCalendarPeriod period;
  final PeriodicReportRecord? report;
  final bool busy;
  final bool canMoveNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: const ValueKey('periodic-report-header-card'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Symbols.calendar_month,
          title: '${_label(reportType)} REPORT',
        ),
        if (report != null) ...[
          AppSpacing.gapSM,
          Text(
            periodicReportPresentationIdentity(
              reportType,
              report!.periodStart,
              report!.revision,
            ),
            key: const ValueKey('periodic-report-presentation-id'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        AppSpacing.gapMD,
        Row(
          children: [
            IconButton(
              tooltip: 'PREVIOUS PERIOD',
              onPressed: busy ? null : onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    _targetPeriodLabel(reportType, period),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'NEXT PERIOD',
              onPressed: busy || !canMoveNext ? null : onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        AppSpacing.gapLG,
        OperationButton(
          text: report == null ? 'CREATE REPORT' : 'CREATE REVISION',
          icon: Symbols.auto_awesome,
          onPressed: busy ? null : onCreate,
        ),
      ],
    ),
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.preview,
    required this.busy,
    required this.onApply,
  });

  final PeriodicReportPreview preview;
  final bool busy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => OperationCard(
    key: const ValueKey('periodic-report-preview-card'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CardTitle(icon: Symbols.preview, title: 'IMPORT PREVIEW'),
        AppSpacing.gapMD,
        _ReadableText(preview.analysis.overallSummary),
        AppSpacing.gapLG,
        Text(
          'NEXT PERIOD FOCUS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        AppSpacing.gapSM,
        _ReadableText(preview.analysis.nextPeriodFocus),
        AppSpacing.gapLG,
        OperationButton(
          text: preview.disposition == ReportSyncHistoryResult.noChange
              ? 'NO CHANGES'
              : 'IMPORT REPORT',
          icon: Symbols.download,
          onPressed:
              busy || preview.disposition == ReportSyncHistoryResult.noChange
              ? null
              : onApply,
        ),
      ],
    ),
  );
}

class _PeriodicResponseActionBar extends StatelessWidget {
  const _PeriodicResponseActionBar({
    required this.enabled,
    required this.onPaste,
    required this.onClear,
    required this.onValidate,
  });

  final bool enabled;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('periodic-report-response-action-bar'),
    children: [
      Expanded(
        child: _ResponseActionButton(
          icon: Symbols.content_paste,
          label: 'PASTE',
          onPressed: enabled ? onPaste : null,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _ResponseActionButton(
          icon: Symbols.backspace,
          label: 'CLEAR',
          onPressed: enabled ? onClear : null,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: _ResponseActionButton(
          icon: Symbols.fact_check,
          label: 'VALIDATE',
          onPressed: enabled ? onValidate : null,
        ),
      ),
    ],
  );
}

class _ResponseActionButton extends StatelessWidget {
  const _ResponseActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _ReportViewer extends StatelessWidget {
  const _ReportViewer({
    required this.report,
    required this.dailyFacts,
    required this.monthlyFacts,
  });

  final PeriodicReportRecord report;
  final List<DailyAggregateV1> dailyFacts;
  final List<PeriodicReportRecord> monthlyFacts;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget?>[
      _section(
        key: 'overall-summary',
        icon: Symbols.summarize,
        title: 'OVERALL SUMMARY',
        text: report.analysis.overallSummary,
      ),
      _section(
        key: 'body',
        icon: Symbols.monitor_weight,
        title: 'BODY',
        text: report.analysis.body,
        children: [
          _metricSummary('weightKg', 'WEIGHT', 'kg'),
          _metricSummary('bodyFatPercent', 'BODY FAT', '%'),
          _metricChart(
            metricKey: 'weightKg',
            title: 'WEIGHT TREND',
            unit: 'kg',
            dailyValue: (fact) => fact.weightKg,
            metricColorKey: HistoryMetricColorKey.weight,
          ),
          _metricChart(
            metricKey: 'bodyFatPercent',
            title: 'BODY FAT TREND',
            unit: '%',
            dailyValue: (fact) => fact.bodyFatPercent,
            metricColorKey: HistoryMetricColorKey.bodyFat,
          ),
        ],
      ),
      _section(
        key: 'nutrition',
        icon: Symbols.restaurant,
        title: 'NUTRITION',
        text: report.analysis.nutrition,
        children: [
          _metricSummary('intakeCaloriesKcal', 'CALORIES', 'kcal'),
          _metricSummary('proteinG', 'PROTEIN', 'g'),
          _metricSummary('fatG', 'FAT', 'g'),
          _metricSummary('carbsG', 'CARBOHYDRATE', 'g'),
          _metricChart(
            metricKey: 'intakeCaloriesKcal',
            title: 'CALORIES',
            unit: 'kcal',
            dailyValue: (fact) => fact.intakeCaloriesKcal,
            metricColorKey: HistoryMetricColorKey.intakeCalories,
          ),
        ],
      ),
      _section(
        key: 'calorie-balance',
        icon: Symbols.balance,
        title: 'CALORIE BALANCE',
        text: report.analysis.calorieBalance,
        children: [
          _weightChangeComparison(),
          _metricSummary('calorieBalanceKcal', 'BALANCE', 'kcal'),
          _metricChart(
            metricKey: 'calorieBalanceKcal',
            title: 'DEFICIT / SURPLUS',
            unit: 'kcal',
            dailyValue: (fact) => fact.estimatedCalorieBalanceKcal,
            yearlyTotal: true,
            metricColorKey: HistoryMetricColorKey.calorieBalance,
          ),
        ],
      ),
      _section(
        key: 'activity',
        icon: Symbols.directions_walk,
        title: 'ACTIVITY',
        text: report.analysis.activity,
        children: [
          _metricSummary('officialSteps', 'STEPS', '', integer: true),
          _metricChart(
            metricKey: 'officialSteps',
            title: 'STEPS',
            unit: 'steps',
            dailyValue: (fact) => fact.officialSteps?.toDouble(),
          ),
        ],
      ),
      _section(
        key: 'recovery',
        icon: Symbols.bedtime,
        title: 'RECOVERY',
        text: report.analysis.recovery,
        children: [
          _durationMetricSummary('sleepDurationMinutes', 'SLEEP DURATION'),
          _metricSummary('sleepScore', 'SLEEP SCORE', ''),
          _metricChart(
            metricKey: 'sleepDurationMinutes',
            title: 'SLEEP DURATION',
            unit: 'H:MM',
            dailyValue: (fact) => fact.sleepDurationMinutes?.toDouble(),
            valueFormatter: periodicReportDurationMinutes,
          ),
          _metricChart(
            metricKey: 'sleepScore',
            title: 'SLEEP SCORE',
            unit: '',
            dailyValue: (fact) => fact.sleepScore?.toDouble(),
          ),
        ],
      ),
      _section(
        key: 'training',
        icon: Symbols.fitness_center,
        title: 'TRAINING',
        text: report.analysis.training,
        children: [
          _integerFacts([
            ('SESSIONS', report.facts.trainingSessionCount),
            ('TRAINING DAYS', report.facts.trainingDays),
          ]),
          if (report.facts.exercisesPerformed.isNotEmpty)
            _FactLine(
              label: 'EXERCISES',
              value: report.facts.exercisesPerformed
                  .map(exerciseDisplayName)
                  .join(' / '),
            ),
          _monthlyCountChart(),
        ],
      ),
      _section(
        key: 'condition',
        icon: Symbols.barefoot,
        title: 'CONDITION',
        text: report.analysis.condition,
        children: [_metricSummary('conditionLevel', 'CONDITION LEVEL', '')],
      ),
      _section(
        key: 'operation',
        icon: Symbols.monitor_heart,
        title: 'OPERATION',
        text: report.analysis.operation,
        children: [
          _integerFacts([
            ('AVAILABLE DAYS', report.facts.availableDailyCount),
            ('EXPECTED DAYS', report.facts.expectedDailyCount),
          ]),
          if (report.facts.operationStatusCounts.isNotEmpty)
            _FactLine(
              label: 'STATUS DISTRIBUTION',
              value: report.facts.operationStatusCounts.entries
                  .map((entry) => '${entry.key} ${entry.value}')
                  .join(' / '),
            ),
          if (report.facts.missingDailyDates.isNotEmpty)
            _FactLine(
              label: 'MISSING DAYS',
              value: report.facts.missingDailyDates.join(', '),
            ),
          if (report.facts.missingMonthlyFactIds.isNotEmpty)
            _FactLine(
              label: 'MISSING MONTHS',
              value: report.facts.missingMonthlyFactIds
                  .map((id) => id.substring(id.length - 7))
                  .join(', '),
            ),
        ],
      ),
      _section(
        key: 'next-period-focus',
        icon: Symbols.flag,
        title: 'NEXT PERIOD FOCUS',
        text: report.analysis.nextPeriodFocus,
      ),
    ].whereType<Widget>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, card) in cards.indexed) ...[
          if (index > 0) AppSpacing.gapMD,
          card,
        ],
        if (report.previousRevisions.isNotEmpty) ...[
          AppSpacing.gapMD,
          OperationCard(
            key: const ValueKey('periodic-report-previous-revisions'),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('PREVIOUS REVISIONS'),
              children: [
                for (final revision in report.previousRevisions.reversed)
                  ListTile(
                    title: Text('REV ${revision.revision}'),
                    subtitle: Text(revision.analysis.overallSummary),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _section({
    required String key,
    required IconData icon,
    required String title,
    required String text,
    List<Widget> children = const [],
  }) {
    final visibleChildren = children.where(_hasContent).toList();
    if (text.trim().isEmpty && visibleChildren.isEmpty) return null;
    return OperationCard(
      key: ValueKey('periodic-report-section-$key'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(icon: icon, title: title),
          if (text.trim().isNotEmpty) ...[
            AppSpacing.gapMD,
            _ReadableText(text),
          ],
          ...visibleChildren,
        ],
      ),
    );
  }

  bool _hasContent(Widget child) =>
      child is! SizedBox ||
      child.width != 0 ||
      child.height != 0 ||
      child.child != null;

  Widget _metricSummary(
    String key,
    String label,
    String unit, {
    bool integer = false,
  }) {
    final metric = report.facts.metrics[key];
    if (metric == null) return const SizedBox.shrink();
    final values = <String>[];
    if (metric.total != null) {
      values.add(
        'TOTAL ${integer ? periodicReportInteger(metric.total!) : periodicReportDecimal(metric.total!)}',
      );
    }
    if (metric.average != null) {
      values.add(
        'AVERAGE ${integer ? periodicReportInteger(metric.average!) : periodicReportDecimal(metric.average!)}',
      );
    }
    if (metric.change != null) {
      values.add('CHANGE ${periodicReportSignedDecimal(metric.change!)}');
    }
    if (values.isEmpty) return const SizedBox.shrink();
    return _FactLine(
      label: label,
      value: '${values.join(' / ')}${unit.isEmpty ? '' : ' $unit'}',
    );
  }

  Widget _durationMetricSummary(String key, String label) {
    final metric = report.facts.metrics[key];
    if (metric == null) return const SizedBox.shrink();
    final values = <String>[];
    if (metric.average != null) {
      values.add('AVERAGE ${periodicReportDurationMinutes(metric.average!)}');
    }
    if (metric.minimum != null) {
      values.add('MIN ${periodicReportDurationMinutes(metric.minimum!)}');
    }
    if (metric.maximum != null) {
      values.add('MAX ${periodicReportDurationMinutes(metric.maximum!)}');
    }
    if (values.isEmpty) return const SizedBox.shrink();
    return _FactLine(label: label, value: values.join(' / '));
  }

  Widget _weightChangeComparison() {
    final theoretical = report.facts.theoreticalWeightChangeKg;
    final actual = report.facts.actualWeightChangeKg;
    if (theoretical == null && actual == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          if (theoretical != null)
            _ComparisonValue(
              label: 'THEORETICAL',
              value: '${periodicReportDecimal(theoretical)} kg',
            ),
          if (actual != null)
            _ComparisonValue(
              label: 'ACTUAL',
              value: '${periodicReportDecimal(actual)} kg',
            ),
        ],
      ),
    );
  }

  Widget _integerFacts(List<(String, int)> values) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          Text('${value.$1}  ${value.$2}', key: ValueKey(value.$1)),
      ],
    ),
  );

  Widget _metricChart({
    required String metricKey,
    required String title,
    required String unit,
    required double? Function(DailyAggregateV1) dailyValue,
    bool yearlyTotal = false,
    String Function(double value)? valueFormatter,
    HistoryMetricColorKey? metricColorKey,
  }) {
    final points = <PeriodicReportChartPoint>[];
    if (report.reportType == PeriodicReportType.yearly) {
      for (final monthly in monthlyFacts) {
        final metric = monthly.facts.metrics[metricKey];
        final value = yearlyTotal ? metric?.total : metric?.average;
        if (value == null) continue;
        final month = DateTime.parse(monthly.periodStart).month;
        points.add(
          PeriodicReportChartPoint(
            x: month - 1,
            label: _months[month - 1],
            value: value,
          ),
        );
      }
    } else {
      final start = DateTime.parse(report.periodStart);
      for (final fact in dailyFacts) {
        final value = dailyValue(fact);
        if (value == null) continue;
        final date = DateTime.parse(fact.operationDate);
        final x = date.difference(start).inDays;
        points.add(
          PeriodicReportChartPoint(
            x: x,
            label: report.reportType == PeriodicReportType.weekly
                ? _weekdays[date.weekday - 1]
                : '${date.day}',
            value: value,
          ),
        );
      }
    }
    if (points.isEmpty) return const SizedBox.shrink();
    points.sort((a, b) => a.x.compareTo(b.x));
    return PeriodicReportChart(
      key: ValueKey('periodic-report-chart-$metricKey'),
      title: title,
      unit: unit,
      points: points,
      maximumIndex: report.reportType == PeriodicReportType.yearly
          ? 11
          : report.facts.expectedDailyCount - 1,
      valueFormatter: valueFormatter,
      metricColorKey: metricColorKey,
    );
  }

  Widget _monthlyCountChart() {
    if (report.reportType != PeriodicReportType.yearly) {
      return const SizedBox.shrink();
    }
    final points = <PeriodicReportChartPoint>[];
    for (final monthly in monthlyFacts) {
      final month = DateTime.parse(monthly.periodStart).month;
      points.add(
        PeriodicReportChartPoint(
          x: month - 1,
          label: _months[month - 1],
          value: monthly.facts.trainingSessionCount.toDouble(),
        ),
      );
    }
    if (points.isEmpty) return const SizedBox.shrink();
    points.sort((a, b) => a.x.compareTo(b.x));
    return PeriodicReportChart(
      key: const ValueKey('periodic-report-chart-trainingSessionCount'),
      title: 'SESSION COUNT',
      unit: 'sessions',
      points: points,
      maximumIndex: 11,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    ],
  );
}

class _ReadableText extends StatelessWidget {
  const _ReadableText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
  );
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        AppSpacing.gapXS,
        Text(value),
      ],
    ),
  );
}

class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 132),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        AppSpacing.gapXS,
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _PeriodicReportViewData {
  const _PeriodicReportViewData({
    required this.operationDate,
    required this.selected,
    required this.reports,
    required this.dailyFacts,
    required this.monthlyFacts,
  });

  final DateTime operationDate;
  final OperationCalendarPeriod selected;
  final List<PeriodicReportRecord> reports;
  final List<DailyAggregateV1> dailyFacts;
  final List<PeriodicReportRecord> monthlyFacts;
}

DateTime _latestCompletedAnchor(PeriodicReportType type, DateTime date) {
  final current = _period(type, date);
  return current.isCompleteAt(date) ? date : current.previous().start;
}

DateTime _moveAnchor(DateTime anchor, PeriodicReportType type, int direction) =>
    switch (type) {
      PeriodicReportType.weekly => anchor.add(Duration(days: 7 * direction)),
      PeriodicReportType.monthly => DateTime(
        anchor.year,
        anchor.month + direction,
        1,
      ),
      PeriodicReportType.yearly => DateTime(anchor.year + direction, 1, 1),
    };

OperationCalendarPeriod _period(PeriodicReportType type, DateTime anchor) =>
    switch (type) {
      PeriodicReportType.weekly => OperationCalendarPeriod.week(anchor),
      PeriodicReportType.monthly => OperationCalendarPeriod.month(anchor),
      PeriodicReportType.yearly => OperationCalendarPeriod.year(anchor),
    };

String _label(PeriodicReportType type) => type.stableId.toUpperCase();
String _date(DateTime value) => value.toIso8601String().substring(0, 10);

@visibleForTesting
String periodicReportPresentationIdentity(
  PeriodicReportType type,
  String periodStart,
  int revision,
) => switch (type) {
  PeriodicReportType.weekly => 'WR-$periodStart-Rev$revision',
  PeriodicReportType.monthly =>
    'MR-${periodStart.substring(0, 7)}-Rev$revision',
  PeriodicReportType.yearly => 'YR-${periodStart.substring(0, 4)}-Rev$revision',
};

String _targetPeriodLabel(
  PeriodicReportType type,
  OperationCalendarPeriod period,
) => switch (type) {
  PeriodicReportType.weekly => '${_date(period.start)} — ${_date(period.end)}',
  PeriodicReportType.monthly => _date(period.start).substring(0, 7),
  PeriodicReportType.yearly => '${period.start.year}',
};

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];
