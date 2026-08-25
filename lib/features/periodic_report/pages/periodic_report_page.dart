import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/models/operation_calendar_period.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../report_sync/models/report_sync_history.dart';
import '../models/periodic_report.dart';
import '../services/periodic_report_service.dart';

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
    return _PeriodicReportViewData(
      operationDate: operationDate,
      selected: _period(widget.reportType, _anchor!),
      reports: await container.periodicReports.list(type: widget.reportType),
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
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionHeader(
              icon: Symbols.calendar_month,
              title: '${_label(widget.reportType)} REPORT',
            ),
          ),
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'PREVIOUS PERIOD',
                      onPressed: _busy ? null : () => _move(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        data.selected.id,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'NEXT PERIOD',
                      onPressed:
                          _busy ||
                              !_period(
                                widget.reportType,
                                _moveAnchor(_anchor!, widget.reportType, 1),
                              ).isCompleteAt(data.operationDate)
                          ? null
                          : () => _move(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Text(
                  '${_date(data.selected.start)} — ${_date(data.selected.end)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OperationButton(
                  text: selectedRecord == null
                      ? 'CREATE REPORT'
                      : 'CREATE REVISION',
                  icon: Symbols.auto_awesome,
                  onPressed: _busy ? null : _prepare,
                ),
              ],
            ),
          ),
          if (_preparation != null) ...[
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('CHATGPT PROMPT'),
                  const SizedBox(height: 12),
                  OperationButton(
                    text: 'COPY PROMPT',
                    icon: Symbols.content_copy,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _preparation!.prompt),
                      );
                      if (mounted) setState(() => _message = 'PROMPT COPIED');
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _responseController,
                    minLines: 5,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'CHATGPT RESPONSE JSON',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OperationButton(
                    text: 'PREVIEW RESPONSE',
                    icon: Symbols.preview,
                    onPressed: _busy ? null : _previewResponse,
                  ),
                ],
              ),
            ),
          ],
          if (_preview != null)
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _preview!.analysis.overallSummary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NEXT PERIOD FOCUS\n${_preview!.analysis.nextPeriodFocus}',
                  ),
                  const SizedBox(height: 16),
                  OperationButton(
                    text:
                        _preview!.disposition ==
                            ReportSyncHistoryResult.noChange
                        ? 'NO CHANGES'
                        : 'IMPORT REPORT',
                    icon: Symbols.download,
                    onPressed:
                        _busy ||
                            _preview!.disposition ==
                                ReportSyncHistoryResult.noChange
                        ? null
                        : _apply,
                  ),
                ],
              ),
            ),
          if (selectedRecord != null) _ReportViewer(report: selectedRecord),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      );
    },
  );

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
      _message = error.toString();
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

class _ReportViewer extends StatelessWidget {
  const _ReportViewer({required this.report});

  final PeriodicReportRecord report;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${report.id.toUpperCase()}  REV ${report.revision}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _analysis('OVERALL SUMMARY', report.analysis.overallSummary),
        _analysis('BODY', report.analysis.body),
        _analysis('NUTRITION', report.analysis.nutrition),
        _analysis('CALORIE BALANCE', report.analysis.calorieBalance),
        _analysis('ACTIVITY', report.analysis.activity),
        _analysis('RECOVERY', report.analysis.recovery),
        _analysis('TRAINING', report.analysis.training),
        _analysis('CONDITION', report.analysis.condition),
        _analysis('OPERATION', report.analysis.operation),
        _analysis('NEXT PERIOD FOCUS', report.analysis.nextPeriodFocus),
        const Divider(),
        Text(
          'DAILY FACTS ${report.facts.availableDailyCount}/'
          '${report.facts.expectedDailyCount}',
        ),
        if (report.facts.missingDailyDates.isNotEmpty)
          Text('MISSING ${report.facts.missingDailyDates.join(', ')}'),
        if (report.facts.missingMonthlyFactIds.isNotEmpty)
          Text(
            'MISSING MONTHLY ${report.facts.missingMonthlyFactIds.join(', ')}',
          ),
        Text(
          'THEORETICAL WEIGHT CHANGE  '
          '${_number(report.facts.theoreticalWeightChangeKg)} kg',
        ),
        Text(
          'ACTUAL WEIGHT CHANGE  '
          '${_number(report.facts.actualWeightChangeKg)} kg',
        ),
        if (report.previousRevisions.isNotEmpty) ...[
          const Divider(),
          ExpansionTile(
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
        ],
      ],
    ),
  );

  Widget _analysis(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class _PeriodicReportViewData {
  const _PeriodicReportViewData({
    required this.operationDate,
    required this.selected,
    required this.reports,
  });

  final DateTime operationDate;
  final OperationCalendarPeriod selected;
  final List<PeriodicReportRecord> reports;
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
String _number(double? value) =>
    value == null ? 'NOT AVAILABLE' : value.toStringAsFixed(2);
