import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_gateway.dart';
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
      if (!mounted) return;
      setState(() {
        _request = request;
        _history = history;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyInstruction() async {
    await _run(() async {
      final request = _request;
      if (request == null || !request.isReady) {
        throw StateError('The exchange target is not ready.');
      }
      await _clipboardWriter(
        _gateway.instruction(widget.exchangeType, request),
      );
      _message = 'CHATGPT PROMPT COPIED';
    });
  }

  Future<void> _copySource() async {
    await _run(() async {
      final source = _request?.sourceText;
      if (source == null) {
        throw StateError('コピーできる正式記録がありません。');
      }
      await _clipboardWriter(source);
      _message = '${_sourceName(widget.exchangeType).toUpperCase()} COPIED';
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
      final request = await _gateway.prepareRequest(widget.exchangeType);
      _request = request;
      _history = await _gateway.history(widget.exchangeType);
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
        _HowToUseCard(exchangeType: widget.exchangeType),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_stateLabel(request)),
              if (request?.operationDate != null)
                Text('Operation Date  ${request!.operationDate}'),
              if (request?.blockingReason != null)
                Text(request!.blockingReason!),
            ],
          ),
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.upload_file,
          title: 'EXPORT TO CHATGPT',
        ),
        AppSpacing.gapSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: ready && !_busy ? _copyInstruction : null,
              icon: const Icon(Icons.content_copy),
              label: const Text('COPY CHATGPT PROMPT'),
            ),
            OutlinedButton.icon(
              onPressed: request?.canCopySource == true && !_busy
                  ? _copySource
                  : null,
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(_copySourceLabel(widget.exchangeType)),
            ),
          ],
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: Text(
            'プロンプトを貼り付けた後、コピーした正式な'
            '${_sourceName(widget.exchangeType)}をChatGPTへ貼り付けてください。',
          ),
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.download_outlined,
          title: 'IMPORT FROM CHATGPT',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ChatGPTが返したJSONだけを貼り付けてください。説明文、'
                'Markdown、複数JSON、不正なJSONは受け付けません。',
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
  const _HowToUseCard({required this.exchangeType});

  final ReportSyncExchangeType exchangeType;

  static const steps = [
    '① ChatGPT用プロンプトをコピー',
    '② ChatGPTへ貼り付ける',
    '③ 指定されたデータを貼り付ける',
    '④ ChatGPTが返したJSONだけをコピー',
    '⑤ JSONを貼り付ける、またはJSONファイルを選択する',
    '⑥ 内容を確認する',
    '⑦ インポートする',
  ];

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('使い方', style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        for (final step in steps)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(step)),
        AppSpacing.gapSM,
        const Text('プロンプトには変換ルールとResponse JSON Schemaが含まれます。'),
        AppSpacing.gapSM,
        Text('対象データ: ${_sourceName(exchangeType)}'),
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

String _stateLabel(ReportSyncRequestPreparation? request) {
  if (request == null) return 'LOADING';
  if (!request.isReady) return request.statusLabel;
  return 'EXPORT READY';
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

String _sourceName(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'Training Record',
  ReportSyncExchangeType.food => 'Meal Data',
  ReportSyncExchangeType.morningBrief => 'Morning Fact',
  ReportSyncExchangeType.dailyDebrief => 'Finalized Daily Data',
};

String _copySourceLabel(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'COPY TRAINING RECORD',
  ReportSyncExchangeType.food => 'COPY MEAL DATA',
  ReportSyncExchangeType.morningBrief => 'COPY MORNING FACT',
  ReportSyncExchangeType.dailyDebrief => 'COPY FINALIZED DAILY DATA',
};

String _errorText(Object error) => switch (error) {
  ReportSyncException value => '${value.code.stableId}: ${value.message}',
  FormatException value => value.message,
  _ => error.toString(),
};
