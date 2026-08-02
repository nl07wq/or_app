import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_gateway.dart';
import '../models/daily_debrief_record.dart';
import '../models/morning_brief_record.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../services/report_sync_exchange_gateway.dart';

typedef ReportSyncClipboardWriter = Future<void> Function(String text);

class ReportSyncExchangePage extends StatelessWidget {
  const ReportSyncExchangePage({
    super.key,
    required this.exchangeType,
    this.gateway,
    this.fileGateway,
    this.clipboardWriter,
  });

  final ReportSyncExchangeType exchangeType;
  final ReportSyncExchangeGateway? gateway;
  final BackupFileGateway? fileGateway;
  final ReportSyncClipboardWriter? clipboardWriter;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title(exchangeType))),
    body: ReportSyncExchangePanel(
      exchangeType: exchangeType,
      gateway: gateway,
      fileGateway: fileGateway,
      clipboardWriter: clipboardWriter,
    ),
  );
}

class ReportSyncExchangePanel extends StatefulWidget {
  const ReportSyncExchangePanel({
    super.key,
    required this.exchangeType,
    this.gateway,
    this.fileGateway,
    this.clipboardWriter,
  });

  final ReportSyncExchangeType exchangeType;
  final ReportSyncExchangeGateway? gateway;
  final BackupFileGateway? fileGateway;
  final ReportSyncClipboardWriter? clipboardWriter;

  @override
  State<ReportSyncExchangePanel> createState() =>
      _ReportSyncExchangePanelState();
}

class _ReportSyncExchangePanelState extends State<ReportSyncExchangePanel> {
  static const _maxInputBytes = 5 * 1024 * 1024;

  late final ReportSyncExchangeGateway _gateway;
  late final BackupFileGateway _fileGateway;
  late final ReportSyncClipboardWriter _clipboardWriter;
  final _responseController = TextEditingController();
  ReportSyncRequestPreparation? _request;
  ReportSyncResponsePreview? _preview;
  List<ReportSyncHistory> _history = const [];
  Object? _importedRecord;
  bool _requestRecorded = false;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ProductionReportSyncExchangeGateway();
    _fileGateway = widget.fileGateway ?? BackupFileGateway.platform();
    _clipboardWriter =
        widget.clipboardWriter ??
        ((text) => Clipboard.setData(ClipboardData(text: text)));
    _load();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await _gateway.prepareRequest(widget.exchangeType);
      final history = await _gateway.history(widget.exchangeType);
      final imported = request.envelope == null
          ? null
          : await _gateway.importedRecord(
              widget.exchangeType,
              request.envelope!.operationDate,
            );
      if (!mounted) return;
      setState(() {
        _request = request;
        _history = history;
        _importedRecord = imported;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordRequest() async {
    final envelope = _request?.envelope;
    if (envelope == null || _requestRecorded) return;
    await _gateway.recordRequest(envelope);
    _requestRecorded = true;
    _history = await _gateway.history(widget.exchangeType);
  }

  Future<void> _copyInstruction() async {
    await _run(() async {
      await _clipboardWriter(_gateway.instruction(widget.exchangeType));
      _message = 'CHATGPT PROMPT COPIED';
    });
  }

  Future<void> _copyRequest() async {
    await _run(() async {
      final envelope = _request!.envelope!;
      await _recordRequest();
      await _clipboardWriter(_gateway.encode(envelope));
      _message = 'REQUEST DATA COPIED';
    });
  }

  Future<void> _exportRequest() async {
    await _run(() async {
      final envelope = _request!.envelope!;
      await _recordRequest();
      final result = await _fileGateway.shareOrSave(
        fileName: _requestFileName(widget.exchangeType, envelope.operationDate),
        content: _gateway.encode(envelope),
      );
      _message = result == BackupFileDelivery.cancelled
          ? 'EXPORT CANCELLED'
          : 'REQUEST FILE EXPORTED';
    });
  }

  Future<void> _selectResponseFile() async {
    await _run(() async {
      final selected = await _fileGateway.selectJson();
      if (selected == null) {
        _message = 'FILE SELECTION CANCELLED';
        return;
      }
      if (!selected.name.toLowerCase().endsWith('.json')) {
        throw const FormatException('JSON file is required.');
      }
      if (selected.bytes.isEmpty || selected.bytes.length > _maxInputBytes) {
        throw const FormatException('File is empty or exceeds the safe limit.');
      }
      _responseController.text = utf8.decode(
        selected.bytes,
        allowMalformed: false,
      );
      _preview = null;
      _message = 'RESPONSE FILE LOADED';
    });
  }

  Future<void> _validate() async {
    await _run(() async {
      final raw = _responseController.text;
      if (raw.trim().isEmpty || utf8.encode(raw).length > _maxInputBytes) {
        throw const FormatException(
          'Response is empty or exceeds the safe limit.',
        );
      }
      _preview = await _gateway.previewResponse(widget.exchangeType, raw);
      _history = await _gateway.history(widget.exchangeType);
      _message = 'RESPONSE READY';
    });
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || !preview.canApply) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_importLabel(widget.exchangeType)),
        content: Text('${preview.envelope.operationDate} の内容を保存しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM IMPORT'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final result = await _gateway.apply(preview);
      if (!result.readBackVerified) {
        throw StateError('Read-back verification failed.');
      }
      _responseController.clear();
      _preview = null;
      _message = result.disposition == ReportSyncDisposition.noChanges
          ? 'NO CHANGES'
          : 'COMPLETE · READ-BACK VERIFIED';
      _requestRecorded = false;
      final request = await _gateway.prepareRequest(widget.exchangeType);
      _request = request;
      _history = await _gateway.history(widget.exchangeType);
      if (request.envelope != null) {
        _importedRecord = await _gateway.importedRecord(
          widget.exchangeType,
          request.envelope!.operationDate,
        );
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      _error = _errorText(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy && _request == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _request == null) {
      return Center(
        child: OperationCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              AppSpacing.gapMD,
              OperationButton(
                text: 'RETRY',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }
    final request = _request;
    final ready = request?.isReady ?? false;
    return ListView(
      key: ValueKey('report-sync-${widget.exchangeType.stableId}'),
      padding: AppSpacing.cardPadding,
      children: [
        SectionHeader(
          icon: _icon(widget.exchangeType),
          title: _title(widget.exchangeType),
        ),
        AppSpacing.gapSM,
        const _HowToUseCard(),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_stateLabel(request, _importedRecord)),
              if (request?.envelope != null)
                Text('Operation Date  ${request!.envelope!.operationDate}'),
              if (request?.blockingReason != null)
                Text(request!.blockingReason!),
            ],
          ),
        ),
        if (_importedRecord != null) ...[
          AppSpacing.gapSM,
          _ImportedRecordCard(record: _importedRecord!),
        ],
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.upload_file, title: 'REQUEST'),
        AppSpacing.gapSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: !_busy && request != null ? _copyInstruction : null,
              icon: const Icon(Icons.content_copy),
              label: const Text('COPY CHATGPT PROMPT'),
            ),
            OutlinedButton.icon(
              onPressed: ready && !_busy ? _copyRequest : null,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('COPY REQUEST DATA'),
            ),
            OutlinedButton.icon(
              onPressed: ready && !_busy ? _exportRequest : null,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('EXPORT REQUEST FILE'),
            ),
          ],
        ),
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.download_outlined, title: 'RESPONSE'),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste only the JSON returned by ChatGPT. Explanatory text, '
                'Markdown code fences, multiple JSON values, and malformed '
                'JSON are rejected.',
              ),
              AppSpacing.gapSM,
              OperationTextField(
                key: const ValueKey('report-sync-response-input'),
                controller: _responseController,
                label: 'PASTE RESPONSE JSON',
                hint: 'Strict JSON response only',
                maxLines: 8,
                onChanged: (_) => setState(() => _preview = null),
              ),
            ],
          ),
        ),
        AppSpacing.gapSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: ready && !_busy ? _selectResponseFile : null,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('SELECT RESPONSE FILE'),
            ),
            OutlinedButton.icon(
              onPressed: ready && !_busy ? _validate : null,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('VALIDATE'),
            ),
          ],
        ),
        if (_busy) ...[
          AppSpacing.gapMD,
          const Center(child: CircularProgressIndicator()),
        ],
        if (_message != null) ...[AppSpacing.gapSM, Text(_message!)],
        if (_error != null) ...[
          AppSpacing.gapSM,
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_preview != null) ...[
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.preview_outlined, title: 'PREVIEW'),
          AppSpacing.gapSM,
          _PreviewCard(preview: _preview!),
          if (_preview!.canApply) ...[
            AppSpacing.gapSM,
            OperationButton(
              text: _importLabel(widget.exchangeType),
              icon: Icons.save_alt,
              onPressed: _busy ? null : _apply,
            ),
          ],
        ],
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.history, title: 'REPORT SYNC HISTORY'),
        AppSpacing.gapSM,
        _HistoryCard(history: _history),
        AppSpacing.gapLG,
      ],
    );
  }
}

class _HowToUseCard extends StatelessWidget {
  const _HowToUseCard();

  static const steps = [
    '1. COPY CHATGPT PROMPT',
    '2. COPY REQUEST DATA',
    '3. Paste both into ChatGPT',
    '4. Copy the JSON response',
    '5. Paste or select the response',
    '6. Validate and review',
    '7. Import',
  ];

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW TO USE', style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        for (final step in steps)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(step)),
        AppSpacing.gapSM,
        const Text(
          'The prompt defines the response rules and JSON schema. '
          'The request data contains formal data for the operation date.',
        ),
      ],
    ),
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});
  final ReportSyncResponsePreview preview;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(preview.disposition.name.toUpperCase()),
        Text('Operation Date  ${preview.envelope.operationDate}'),
        Text('CREATE  ${preview.createCount}'),
        Text('NO CHANGES  ${preview.noChangeCount}'),
        Text('CONFLICT  ${preview.conflictCount}'),
        if (preview.message != null) Text(preview.message!),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});
  final List<ReportSyncHistory> history;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: history.isEmpty
        ? const Text('NO REPORT SYNC HISTORY')
        : Column(
            children: [
              for (var index = 0; index < history.length; index++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(
                    '${history[index].exchangeType.stableId} · '
                    '${history[index].direction.stableId}',
                  ),
                  subtitle: Text(
                    '${history[index].operationDate} · '
                    '${history[index].result.stableId} · '
                    '${history[index].completedAt.toLocal()}'
                    '${history[index].failureCode == null ? '' : ' · ${history[index].failureCode!.stableId}'}',
                  ),
                ),
                if (index != history.length - 1) const Divider(),
              ],
            ],
          ),
  );
}

class _ImportedRecordCard extends StatelessWidget {
  const _ImportedRecordCard({required this.record});
  final Object record;

  @override
  Widget build(BuildContext context) {
    if (record is MorningBriefRecord) {
      final value = record as MorningBriefRecord;
      return OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Situation Analysis\n${value.situationAnalysis}'),
            AppSpacing.gapSM,
            Text(
              'Operation Status\n${value.operationStatus.stableId.toUpperCase()}',
            ),
            AppSpacing.gapSM,
            Text('Commander Intent\n${value.commanderIntent}'),
            AppSpacing.gapSM,
            Text('Argo Comment\n${value.argoComment}'),
            AppSpacing.gapSM,
            Text(
              'Strategic Resource Decision\n${value.strategicResourceDecision}',
            ),
            AppSpacing.gapSM,
            const Text('Actions'),
            for (final action in value.actions)
              Text('• ${action.text} [${action.priority}]'),
          ],
        ),
      );
    }
    final value = record as DailyDebriefRecord;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Summary\n${value.dailySummary}'),
          AppSpacing.gapSM,
          Text(
            'Commander Intent Evaluation\n${value.commanderIntentEvaluation}',
          ),
          AppSpacing.gapSM,
          Text('Successes\n${value.successes.join('\n')}'),
          AppSpacing.gapSM,
          Text('Issues\n${value.issues.join('\n')}'),
          AppSpacing.gapSM,
          Text('Nutrition Evaluation\n${value.nutritionEvaluation}'),
          AppSpacing.gapSM,
          Text('Activity Evaluation\n${value.activityEvaluation}'),
          AppSpacing.gapSM,
          Text('Training Evaluation\n${value.trainingEvaluation}'),
          AppSpacing.gapSM,
          Text('Recovery Evaluation\n${value.recoveryEvaluation}'),
          AppSpacing.gapSM,
          Text('Carryover\n${value.carryover.join('\n')}'),
          AppSpacing.gapSM,
          Text(
            'Tomorrow Considerations\n${value.tomorrowConsiderations.join('\n')}',
          ),
        ],
      ),
    );
  }
}

String _stateLabel(ReportSyncRequestPreparation? request, Object? imported) {
  if (imported != null) return 'IMPORTED';
  if (request == null) return 'LOADING';
  if (!request.isReady) return request.statusLabel;
  return 'REQUEST READY';
}

String _title(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'TRAINING REPORT SYNC',
  ReportSyncExchangeType.food => 'FOOD REPORT SYNC',
  ReportSyncExchangeType.morningBrief => 'MORNING BRIEF',
  ReportSyncExchangeType.dailyDebrief => 'DAILY DEBRIEF',
};

IconData _icon(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => Icons.fitness_center,
  ReportSyncExchangeType.food => Icons.restaurant_outlined,
  ReportSyncExchangeType.morningBrief => Icons.wb_sunny_outlined,
  ReportSyncExchangeType.dailyDebrief => Icons.nightlight_outlined,
};

String _importLabel(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'IMPORT TRAINING',
  ReportSyncExchangeType.food => 'IMPORT FOOD',
  ReportSyncExchangeType.morningBrief => 'IMPORT MORNING BRIEF',
  ReportSyncExchangeType.dailyDebrief => 'IMPORT DAILY DEBRIEF',
};

String _requestFileName(ReportSyncExchangeType type, String date) =>
    switch (type) {
      ReportSyncExchangeType.training => 'training-report-request-$date.json',
      ReportSyncExchangeType.food => 'food-report-request-$date.json',
      ReportSyncExchangeType.morningBrief => 'morning-brief-request-$date.json',
      ReportSyncExchangeType.dailyDebrief => 'daily-debrief-request-$date.json',
    };

String _errorText(Object error) => switch (error) {
  ReportSyncException value => '${value.code.stableId}: ${value.message}',
  FormatException value => value.message,
  _ => error.toString(),
};
