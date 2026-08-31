import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/models/food_item.dart';
import '../../../core/models/meal_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_gateway.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/daily_debrief_record.dart';
import '../models/daily_debrief_state.dart';
import '../models/report_sync_issue.dart';
import '../models/morning_brief_state.dart';
import '../models/status_report_sync_source.dart';
import '../services/report_sync_clipboard_gateway.dart';
import '../services/report_sync_exchange_gateway.dart';
import '../services/report_human_presentation.dart';
import '../services/report_sync_persistence_service.dart';
import '../widgets/report_sync_action_bar.dart';

typedef ReportSyncClipboardWriter = Future<void> Function(String text);

class ReportSyncExchangePage extends StatelessWidget {
  const ReportSyncExchangePage({
    super.key,
    required this.exchangeType,
    this.gateway,
    this.fileGateway,
    this.clipboardWriter,
    this.clipboardGateway,
    this.onApplied,
    this.onTargetDateChanged,
    this.initialTargetDate,
  });

  final ReportSyncExchangeType exchangeType;
  final ReportSyncExchangeGateway? gateway;
  final BackupFileGateway? fileGateway;
  final ReportSyncClipboardWriter? clipboardWriter;
  final ReportSyncClipboardGateway? clipboardGateway;
  final VoidCallback? onApplied;
  final ValueChanged<String>? onTargetDateChanged;
  final String? initialTargetDate;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title(exchangeType))),
    body: ReportSyncExchangePanel(
      exchangeType: exchangeType,
      gateway: gateway,
      fileGateway: fileGateway,
      clipboardWriter: clipboardWriter,
      clipboardGateway: clipboardGateway,
      onApplied: onApplied,
      onTargetDateChanged: onTargetDateChanged,
      initialTargetDate: initialTargetDate,
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
    this.clipboardGateway,
    this.onApplied,
    this.onTargetDateChanged,
    this.initialTargetDate,
  });

  final ReportSyncExchangeType exchangeType;
  final ReportSyncExchangeGateway? gateway;
  final BackupFileGateway? fileGateway;
  final ReportSyncClipboardWriter? clipboardWriter;
  final ReportSyncClipboardGateway? clipboardGateway;
  final VoidCallback? onApplied;
  final ValueChanged<String>? onTargetDateChanged;
  final String? initialTargetDate;

  @override
  State<ReportSyncExchangePanel> createState() =>
      _ReportSyncExchangePanelState();
}

class _ReportSyncExchangePanelState extends State<ReportSyncExchangePanel> {
  static const _maxInputBytes = 5 * 1024 * 1024;

  late final ReportSyncExchangeGateway _gateway;
  late final BackupFileGateway _fileGateway;
  late final ReportSyncClipboardWriter _clipboardWriter;
  late final ReportSyncClipboardGateway _clipboardGateway;
  final _responseController = TextEditingController();
  final _targetDateController = TextEditingController();
  ReportSyncRequestPreparation? _request;
  ReportSyncResponsePreview? _preview;
  List<ReportSyncHistory> _history = const [];
  bool _busy = false;
  String? _loadError;
  String? _importMessage;
  String? _importActionError;
  String? _importError;
  String? _generateMessage;
  String? _generateError;
  String? _promptCopyMessage;
  String? _promptCopyError;
  String? _sourceCopyMessage;
  String? _sourceCopyError;
  Set<String> _selectedMealIds = const {};
  bool _statusSourceGenerated = false;

  bool get _isImportOnly =>
      widget.exchangeType == ReportSyncExchangeType.training ||
      widget.exchangeType == ReportSyncExchangeType.food;

  bool get _usesTargetDate =>
      _isImportOnly ||
      widget.exchangeType == ReportSyncExchangeType.morningBrief ||
      widget.exchangeType == ReportSyncExchangeType.dailyDebrief;

  bool get _usesCommonResponseActions =>
      widget.exchangeType == ReportSyncExchangeType.training ||
      widget.exchangeType == ReportSyncExchangeType.food ||
      widget.exchangeType == ReportSyncExchangeType.morningBrief ||
      widget.exchangeType == ReportSyncExchangeType.dailyDebrief;

  bool get _isBriefExchange =>
      widget.exchangeType == ReportSyncExchangeType.morningBrief ||
      widget.exchangeType == ReportSyncExchangeType.dailyDebrief;

  bool get _isCompactHistoryExchange =>
      widget.exchangeType == ReportSyncExchangeType.food ||
      widget.exchangeType == ReportSyncExchangeType.training;

  int get _inlineHistoryLimit => _isCompactHistoryExchange ? 3 : 5;

  bool get _showsArchiveAction =>
      _isCompactHistoryExchange ? _history.length >= 4 : _history.isNotEmpty;

  bool get _hasValidSelectedDate {
    if (!_usesTargetDate) return false;
    try {
      OperationLocalDate.parse(_targetDateController.text);
      return true;
    } on FormatException {
      return false;
    }
  }

  bool get _hasValidTargetDate {
    if (!_isImportOnly) return _request?.isReady ?? false;
    return _hasValidSelectedDate;
  }

  bool get _canApplyCurrent {
    final preview = _preview;
    if (preview == null || !preview.canApply) return false;
    return widget.exchangeType != ReportSyncExchangeType.food ||
        _selectedMealIds.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ProductionReportSyncExchangeGateway();
    _fileGateway = widget.fileGateway ?? BackupFileGateway.platform();
    _clipboardGateway =
        widget.clipboardGateway ?? ReportSyncClipboardGateway.platform();
    _clipboardWriter = widget.clipboardWriter ?? _clipboardGateway.writeText;
    _load();
  }

  @override
  void dispose() {
    _responseController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      final request = await _gateway.prepareRequest(
        widget.exchangeType,
        targetDate: widget.initialTargetDate,
      );
      final history = await _gateway.history(widget.exchangeType);
      if (!mounted) return;
      setState(() {
        _request = request;
        if (_usesTargetDate && _targetDateController.text.isEmpty) {
          _targetDateController.text = request.operationDate ?? '';
        }
        _history = history;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyInstruction() async {
    await _runExport(_ExportAction.prompt, () async {
      final request = _request;
      if (request == null || !_hasValidTargetDate) {
        throw StateError('The exchange target is not ready.');
      }
      final instructionRequest = _isImportOnly
          ? ReportSyncRequestPreparation(
              operationDate: _targetDateController.text,
            )
          : request;
      final instruction = _gateway.instruction(
        widget.exchangeType,
        instructionRequest,
      );
      try {
        await _clipboardWriter(instruction);
      } catch (_) {
        if (widget.exchangeType == ReportSyncExchangeType.morningBrief) {
          throw const _ChatGptPromptCopyException();
        }
        rethrow;
      }
      _promptCopyMessage =
          widget.exchangeType == ReportSyncExchangeType.morningBrief
          ? 'CHATGPT PROMPTをコピーしました'
          : 'CHATGPT PROMPT COPIED';
    });
  }

  Future<void> _copySource() async {
    await _runExport(_ExportAction.source, () async {
      final source = _request?.sourceText;
      if (source == null) {
        throw StateError('コピーできる正式記録がありません。');
      }
      await _clipboardWriter(source);
      _sourceCopyMessage =
          '${_sourceName(widget.exchangeType).toUpperCase()} COPIED';
    });
  }

  Future<void> _generateStatusSource() async {
    await _runExport(_ExportAction.generate, () async {
      final date = _targetDateController.text;
      if (!_hasValidSelectedDate) {
        throw const FormatException('対象日が正しくありません。');
      }
      final request = await _gateway.prepareRequest(
        ReportSyncExchangeType.morningBrief,
        targetDate: date,
      );
      _request = request;
      _statusSourceGenerated = request.statusSourceExport != null;
      _preview = null;
      _selectedMealIds = const {};
      _promptCopyMessage = null;
      _promptCopyError = null;
      _sourceCopyMessage = null;
      _sourceCopyError = null;
      if (!_statusSourceGenerated || request.statusLabel != 'READY') {
        throw StateError(request.blockingReason ?? 'STATUS SOURCE READYが必要です。');
      }
      _generateMessage = 'STATUS SOURCEを生成しました';
    });
  }

  Future<void> _selectTargetDate() async {
    if (widget.exchangeType == ReportSyncExchangeType.dailyDebrief) {
      final dates = _request?.eligibleDates ?? const <String>[];
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('ELIGIBLE DATE'),
          children: [
            for (final date in dates)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, date),
                child: Text(date),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      final request = await _gateway.prepareRequest(
        ReportSyncExchangeType.dailyDebrief,
        targetDate: selected,
      );
      if (!mounted) return;
      setState(() {
        _request = request;
        _targetDateController.text = selected;
        _preview = null;
        _clearExportFeedback();
        _importMessage = null;
        _importActionError = null;
        _importError = null;
      });
      widget.onTargetDateChanged?.call(selected);
      return;
    }
    final current = DateTime.tryParse(_targetDateController.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _targetDateController.text = _formatLocalDate(selected);
      _statusSourceGenerated = false;
      _preview = null;
      _selectedMealIds = const {};
      _clearExportFeedback();
      _importMessage = null;
      _importActionError = null;
      _importError = null;
    });
    if (widget.exchangeType == ReportSyncExchangeType.morningBrief) {
      await _runExport(_ExportAction.generate, () async {
        _request = await _gateway.prepareRequest(
          ReportSyncExchangeType.morningBrief,
          targetDate: _targetDateController.text,
        );
      });
    }
  }

  Future<void> _selectResponseFile() async {
    await _runImport(() async {
      final selected = await _fileGateway.selectJson();
      if (selected == null) {
        _importMessage = 'FILE SELECTION CANCELLED';
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
      _importMessage = 'RESPONSE FILE LOADED';
    });
  }

  Future<void> _pasteResponse() async {
    await _runImport(() async {
      final String? pasted;
      try {
        pasted = await _clipboardGateway.readText();
      } catch (_) {
        throw StateError('クリップボードから貼り付けできませんでした');
      }
      if (pasted == null || pasted.isEmpty) {
        throw StateError('クリップボードに貼り付け可能なテキストがありません');
      }
      _responseController.text = pasted;
      _preview = null;
      _selectedMealIds = const {};
      _importError = null;
      _importMessage = 'クリップボードの内容を貼り付けました';
    });
  }

  void _clearResponse() {
    if (_busy) return;
    setState(() {
      _responseController.clear();
      _preview = null;
      _selectedMealIds = const {};
      _importMessage = null;
      _importActionError = null;
      _importError = null;
    });
  }

  Future<void> _validate() async {
    final raw = _responseController.text;
    await _runImport(() async {
      if (raw.trim().isEmpty || utf8.encode(raw).length > _maxInputBytes) {
        throw const FormatException(
          'Response is empty or exceeds the safe limit.',
        );
      }
      _preview = await _gateway.previewResponse(
        widget.exchangeType,
        raw,
        targetDate: _usesTargetDate ? _targetDateController.text : null,
      );
      _selectedMealIds = {
        for (final item in _preview!.foodMeals)
          if (item.canSelect) item.previewId,
      };
      _history = await _gateway.history(widget.exchangeType);
      _importMessage = 'RESPONSE READY';
    }, errorFormatter: (error) => _validationErrorText(error, raw));
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || !preview.canApply) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_importLabel(widget.exchangeType)),
        content: Text('${preview.operationDate} の内容を保存しますか？'),
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
    setState(() {
      _busy = true;
      _importError = null;
      _importMessage = null;
    });
    try {
      final result = await _gateway.apply(
        preview,
        selectedMealIds: widget.exchangeType == ReportSyncExchangeType.food
            ? _selectedMealIds
            : null,
      );
      if (!result.readBackVerified) {
        throw StateError('Read-back verification failed.');
      }
      if (widget.exchangeType == ReportSyncExchangeType.morningBrief) {
        notifyMorningBriefChanged();
      }
      _responseController.clear();
      _preview = null;
      final importedMealCount = result.mealCounts?.imported;
      _importMessage = result.disposition == ReportSyncDisposition.noChanges
          ? 'NO CHANGES'
          : importedMealCount == null
          ? 'COMPLETE · READ-BACK VERIFIED'
          : '$importedMealCount件のMEALを取り込みました';
      final request = await _gateway.prepareRequest(
        widget.exchangeType,
        targetDate: _usesTargetDate ? _targetDateController.text : null,
      );
      _request = request;
      _history = await _gateway.history(widget.exchangeType);
      if (widget.exchangeType == ReportSyncExchangeType.dailyDebrief) {
        notifyDailyDebriefChanged(preview.operationDate);
      }
      widget.onApplied?.call();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _importError = _importErrorText(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runExport(
    _ExportAction exportAction,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _setExportError(exportAction, null);
      _setExportMessage(exportAction, null);
    });
    try {
      await action();
    } catch (error) {
      _setExportError(exportAction, _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport(
    Future<void> Function() action, {
    String Function(Object error)? errorFormatter,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _importActionError = null;
      _importError = null;
      _importMessage = null;
    });
    try {
      await action();
    } catch (error) {
      _importActionError = (errorFormatter ?? _errorText)(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearExportFeedback() {
    _generateMessage = null;
    _generateError = null;
    _promptCopyMessage = null;
    _promptCopyError = null;
    _sourceCopyMessage = null;
    _sourceCopyError = null;
  }

  void _setExportMessage(_ExportAction action, String? value) {
    switch (action) {
      case _ExportAction.generate:
        _generateMessage = value;
      case _ExportAction.prompt:
        _promptCopyMessage = value;
      case _ExportAction.source:
        _sourceCopyMessage = value;
    }
  }

  void _setExportError(_ExportAction action, String? value) {
    switch (action) {
      case _ExportAction.generate:
        _generateError = value;
      case _ExportAction.prompt:
        _promptCopyError = value;
      case _ExportAction.source:
        _sourceCopyError = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy && _request == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _request == null) {
      return Center(
        child: OperationCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!),
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
    final ready = _hasValidTargetDate;
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
        if (_usesTargetDate)
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('対象日'),
                AppSpacing.gapSM,
                TextField(
                  key: const ValueKey('report-sync-target-date'),
                  controller: _targetDateController,
                  readOnly: true,
                  onTap: _busy ? null : _selectTargetDate,
                  decoration: const InputDecoration(
                    labelText: 'YYYY-MM-DD',
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                ),
                AppSpacing.gapSM,
                if (widget.exchangeType ==
                    ReportSyncExchangeType.morningBrief) ...[
                  Text(
                    'STATUS SOURCE',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('状態  ${request?.statusLabel ?? 'NOT READY'}'),
                  if (request?.statusSourceExport != null)
                    Text(
                      '前日比較  '
                      '${request!.statusSourceExport!.source.previousDayComparison.previousStatusAvailable ? 'AVAILABLE' : 'NOT AVAILABLE'}',
                    ),
                  if (request?.blockingReason != null)
                    Text(request!.blockingReason!),
                ] else
                  Text(ready ? 'IMPORT READY' : '対象日をYYYY-MM-DD形式で入力してください。'),
              ],
            ),
          )
        else
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
        if (!_isImportOnly)
          const SectionHeader(
            icon: Icons.upload_file,
            title: 'EXPORT TO CHATGPT',
          ),
        if (!_isImportOnly) AppSpacing.gapSM,
        if (_isImportOnly) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: ready && !_busy ? _copyInstruction : null,
              icon: const Icon(Icons.content_copy),
              label: const Text('COPY CHATGPT PROMPT'),
            ),
          ),
          _ActionFeedback(
            message: _promptCopyMessage,
            error: _promptCopyError,
            errorKey: const ValueKey('report-sync-export-prompt-error'),
          ),
        ] else ...[
          if (widget.exchangeType == ReportSyncExchangeType.morningBrief) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _hasValidSelectedDate && !_busy
                    ? _generateStatusSource
                    : null,
                icon: const Icon(Icons.description_outlined),
                label: const Text('GENERATE STATUS SOURCE'),
              ),
            ),
            _ActionFeedback(
              message: _generateMessage,
              error: _generateError,
              errorKey: const ValueKey('report-sync-export-generate-error'),
            ),
            AppSpacing.gapSM,
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed:
                  ready &&
                      !_busy &&
                      (widget.exchangeType !=
                              ReportSyncExchangeType.morningBrief ||
                          _statusSourceGenerated)
                  ? _copyInstruction
                  : null,
              icon: const Icon(Icons.content_copy),
              label: const Text('COPY CHATGPT PROMPT'),
            ),
          ),
          _ActionFeedback(
            message: _promptCopyMessage,
            error: _promptCopyError,
            errorKey: const ValueKey('report-sync-export-prompt-error'),
          ),
          AppSpacing.gapSM,
          if (widget.exchangeType != ReportSyncExchangeType.morningBrief &&
              widget.exchangeType != ReportSyncExchangeType.dailyDebrief) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: request?.canCopySource == true && !_busy
                    ? _copySource
                    : null,
                icon: const Icon(Icons.copy_all_outlined),
                label: Text(_copySourceLabel(widget.exchangeType)),
              ),
            ),
            _ActionFeedback(
              message: _sourceCopyMessage,
              error: _sourceCopyError,
              errorKey: const ValueKey('report-sync-export-source-error'),
            ),
          ],
        ],
        if (!_isImportOnly) ...[
          AppSpacing.gapSM,
          OperationCard(
            child: Text(
              widget.exchangeType == ReportSyncExchangeType.morningBrief
                  ? 'コピーした内容には、DAILY BRIEF生成指示と正式なSTATUS SOURCEが含まれています。'
                        'そのままChatGPTへ1回貼り付けてください。'
                  : 'プロンプトを貼り付けた後、コピーした正式な'
                        '${_sourceName(widget.exchangeType)}をChatGPTへ貼り付けてください。',
            ),
          ),
          if (widget.exchangeType == ReportSyncExchangeType.morningBrief &&
              _statusSourceGenerated &&
              request?.statusSourceExport != null) ...[
            AppSpacing.gapSM,
            const SectionHeader(
              icon: Icons.preview_outlined,
              title: 'STATUS SOURCE PREVIEW',
            ),
            AppSpacing.gapSM,
            _StatusSourcePreview(export: request!.statusSourceExport!),
          ],
        ],
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
                onChanged: (_) => setState(() {
                  _preview = null;
                  _selectedMealIds = const {};
                  _importActionError = null;
                  _importError = null;
                }),
              ),
            ],
          ),
        ),
        AppSpacing.gapSM,
        if (_usesCommonResponseActions)
          ReportSyncActionBar(
            enabled: ready && !_busy,
            onPaste: _pasteResponse,
            onClear: _clearResponse,
            onValidate: _validate,
          )
        else
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
                onPressed: ready && !_busy ? _pasteResponse : null,
                icon: const Icon(Icons.content_paste_outlined),
                label: const Text('PASTE'),
              ),
              OutlinedButton.icon(
                onPressed: ready && !_busy ? _validate : null,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('VALIDATE'),
              ),
            ],
          ),
        _ActionFeedback(
          message: _importMessage,
          error: _importActionError,
          errorKey: const ValueKey('report-sync-import-action-error'),
          historicalStyleError: true,
        ),
        if (_busy) ...[
          AppSpacing.gapMD,
          const Center(child: CircularProgressIndicator()),
        ],
        if (_preview != null) ...[
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.preview_outlined, title: 'PREVIEW'),
          AppSpacing.gapSM,
          if (widget.exchangeType == ReportSyncExchangeType.food)
            _FoodPreviewCard(
              preview: _preview!,
              selectedMealIds: _selectedMealIds,
              onSelectionChanged: (value) => setState(() {
                _selectedMealIds = value;
                _importError = null;
              }),
            )
          else if (widget.exchangeType == ReportSyncExchangeType.morningBrief)
            _MorningBriefPreviewCard(preview: _preview!)
          else if (widget.exchangeType == ReportSyncExchangeType.dailyDebrief)
            _DailyDebriefPreviewCard(preview: _preview!)
          else
            _PreviewCard(preview: _preview!),
          if (!_preview!.canApply) ...[
            AppSpacing.gapSM,
            if (_preview!.message != null)
              SelectableText(_localizedValidationDetails(_preview!.message!)),
            if (_preview!.message != null) AppSpacing.gapSM,
            Text(
              'IMPORT BLOCKED',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_preview!.canApply) ...[
            AppSpacing.gapSM,
            OperationButton(
              text: widget.exchangeType == ReportSyncExchangeType.food
                  ? '選択したMEALを取り込む'
                  : _importLabel(widget.exchangeType),
              icon: Icons.save_alt,
              onPressed: _busy || !_canApplyCurrent ? null : _apply,
            ),
            if (_importError != null) ...[
              AppSpacing.gapSM,
              Text(
                _importError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ],
        AppSpacing.gapXL,
        if (!_isBriefExchange) ...[
          const SectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'REPORT SYNC RECORD',
          ),
          AppSpacing.gapSM,
          _HistoryCard(
            history: _history.take(_inlineHistoryLimit).toList(growable: false),
          ),
        ],
        if (_showsArchiveAction) ...[
          AppSpacing.gapSM,
          _RecordArchiveButton(
            key: const ValueKey('view-all-report-sync-records'),
            text: 'VIEW ALL RECORDS',
            icon: Icons.list_alt,
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => _ReportSyncRecordArchivePage(history: _history),
              ),
            ),
          ),
        ],
        AppSpacing.gapLG,
      ],
    );
  }
}

enum _ExportAction { generate, prompt, source }

class _RecordArchiveButton extends StatelessWidget {
  const _RecordArchiveButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OperationButton(
      role: OperationActionRole.primary,
      onPressed: onPressed,
      icon: icon,
      text: text,
    ),
  );
}

class _ActionFeedback extends StatelessWidget {
  const _ActionFeedback({
    required this.message,
    required this.error,
    required this.errorKey,
    this.historicalStyleError = false,
  });

  final String? message;
  final String? error;
  final Key errorKey;
  final bool historicalStyleError;

  @override
  Widget build(BuildContext context) {
    if (message == null && error == null) return const SizedBox.shrink();
    if (error != null && historicalStyleError) {
      final lines = error!.split('\n');
      final state = lines.first;
      final details = lines.skip(1).join('\n').trim();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          key: errorKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline),
              title: Text(state),
              subtitle: details.isEmpty ? null : Text(details),
            ),
            Text(
              'IMPORT BLOCKED',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        error ?? message!,
        key: error == null ? null : errorKey,
        style: error == null
            ? null
            : TextStyle(color: Theme.of(context).colorScheme.error),
      ),
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

  static const importOnlySteps = [
    '① 対象日を確認する',
    '② ChatGPT用プロンプトをコピーする',
    '③ ChatGPTへ貼り付ける',
    '④ ChatGPTが保持している対象日の記録からJSONを作成させる',
    '⑤ 返されたJSONだけをコピーする',
    '⑥ JSONを貼り付ける、またはJSONファイルを選択する',
    '⑦ 内容を確認してインポートする',
  ];

  static const morningBriefSteps = [
    '① 対象日を選択する',
    '② STATUS SOURCEを生成してPreviewを確認する',
    '③ COPY CHATGPT PROMPTを押す',
    '④ コピーした内容をChatGPTへ1回だけ貼り付ける',
    '⑤ ChatGPTの単一textコードブロック内のJSONだけをコピーする',
    '⑥ PASTEでJSONを貼り付ける',
    '⑦ VALIDATEを押す',
    '⑧ PREVIEWでSource Digestと内容を確認する',
    '⑨ IMPORT DAILY BRIEFを押す',
    '⑩ COMPLETE · READ-BACK VERIFIEDを確認する',
  ];

  @override
  Widget build(BuildContext context) {
    final importOnly =
        exchangeType == ReportSyncExchangeType.training ||
        exchangeType == ReportSyncExchangeType.food;
    final morningBrief = exchangeType == ReportSyncExchangeType.morningBrief;
    final visibleSteps = morningBrief
        ? morningBriefSteps
        : importOnly
        ? importOnlySteps
        : steps;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('使い方', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSM,
          for (final step in visibleSteps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(step),
            ),
          AppSpacing.gapSM,
          Text(
            morningBrief
                ? 'プロンプトには正式なDAILY BRIEF SchemaとSTATUS SOURCEが1つに統合されています。'
                : 'プロンプトには変換ルールとResponse JSON Schemaが含まれます。',
          ),
          if (!morningBrief && !importOnly) ...[
            AppSpacing.gapSM,
            Text('対象データ: ${_sourceName(exchangeType)}'),
          ],
        ],
      ),
    );
  }
}

class _MorningBriefPreviewCard extends StatelessWidget {
  const _MorningBriefPreviewCard({required this.preview});

  final ReportSyncResponsePreview preview;

  @override
  Widget build(BuildContext context) {
    final payload = preview.envelope!.payload;
    final content = Map<String, Object?>.from(payload['content'] as Map);
    final analysis = Map<String, Object?>.from(
      content['situationAnalysis'] as Map,
    );
    final decision = Map<String, Object?>.from(
      content['strategicResourceDecision'] as Map,
    );
    final actions = (content['actions'] as List).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportPreviewPanel(
          icon: Icons.calendar_today_outlined,
          title: 'DAILY BRIEF',
          lines: [
            'OPERATION DATE  ${preview.operationDate}',
            'OPERATION STATUS  ${content['operationStatus']}',
          ],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.analytics_outlined,
          title: 'SITUATION ANALYSIS',
          lines: [
            for (final key in const [
              'body',
              'recovery',
              'condition',
              'work',
              'carryover',
              'overall',
            ])
              '${key.toUpperCase()}  ${key == 'work' ? ReportHumanPresentation.workText('${analysis[key]}') : analysis[key]}',
          ],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.route_outlined,
          title: 'OPERATING POLICY',
          lines: ['${content['operatingPolicy']}'],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.inventory_2_outlined,
          title: 'STRATEGIC RESOURCE DECISION',
          lines: [
            'DECISION  ${decision['decision']}',
            if (decision['targetResource'] != null)
              'TARGET RESOURCE  ${decision['targetResource']}',
            'RATIONALE  ${decision['rationale']}',
            if (decision['execution'] != null)
              'EXECUTION  ${decision['execution']}',
          ],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.flag_outlined,
          title: 'COMMANDER INTENT',
          lines: ['${content['commanderIntent']}'],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.checklist_outlined,
          title: 'ACTIONS',
          lines: [
            for (var index = 0; index < actions.length; index++)
              '${index + 1}. ${actions[index]['text']}  '
                  '[${actions[index]['priority']}]',
          ],
        ),
      ],
    );
  }
}

class _DailyDebriefPreviewCard extends StatelessWidget {
  const _DailyDebriefPreviewCard({required this.preview});

  final ReportSyncResponsePreview preview;

  @override
  Widget build(BuildContext context) {
    final payload = preview.envelope!.payload;
    final analysis = DailyDebriefAnalysis.fromJson(
      Map<String, Object?>.from(payload['analysis'] as Map),
    );
    final evaluations = analysis.domainEvaluations
        .toJson()
        .entries
        .where((entry) => entry.value != null)
        .toList(growable: false);
    final intent = analysis.commanderIntentEvaluation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportPreviewPanel(
          icon: Icons.calendar_today_outlined,
          title: 'DAILY DEBRIEF',
          lines: ['OPERATION DATE  ${preview.operationDate}'],
        ),
        if (intent != null) ...[
          AppSpacing.gapSM,
          _ReportPreviewPanel(
            icon: Icons.flag_outlined,
            title: 'COMMANDER INTENT EVALUATION',
            lines: [
              'RESULT  ${intent.outcome.name.toUpperCase()}',
              intent.rationale,
              ...intent.evidence.map((value) => '• $value'),
            ],
          ),
        ],
        if (evaluations.isNotEmpty) ...[
          AppSpacing.gapSM,
          _ReportPreviewPanel(
            icon: Icons.analytics_outlined,
            title: 'DOMAIN EVALUATIONS',
            lines: [
              for (final entry in evaluations)
                '${entry.key.toUpperCase()}  ${entry.key == 'work' ? ReportHumanPresentation.workText('${entry.value}') : entry.value}',
            ],
          ),
        ],
        ..._analysisPreviewPanels(analysis),
      ],
    );
  }
}

List<Widget> _analysisPreviewPanels(DailyDebriefAnalysis analysis) {
  final sections = <(IconData, String, List<String>)>[
    (Icons.insights_outlined, 'KEY FACTORS', analysis.crossAnalysis.keyFactors),
    (Icons.hub_outlined, 'INTERACTIONS', analysis.crossAnalysis.interactions),
    (
      Icons.warning_amber_outlined,
      'CONSTRAINTS',
      analysis.crossAnalysis.constraints,
    ),
    (Icons.inventory_2_outlined, 'RESOURCES', analysis.crossAnalysis.resources),
    (
      Icons.check_circle_outline,
      'SUCCESSES',
      analysis.executionEvaluation.successes,
    ),
    (
      Icons.tune_outlined,
      'ADJUSTMENTS',
      analysis.executionEvaluation.adjustments,
    ),
    (
      Icons.visibility_outlined,
      'WATCH POINTS',
      analysis.nextDayHandoff.watchPoints,
    ),
  ];
  return [
    for (final section in sections)
      if (section.$3.isNotEmpty) ...[
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: section.$1,
          title: section.$2,
          lines: section.$3.map((value) => '• $value').toList(),
        ),
      ],
  ];
}

class _ReportPreviewPanel extends StatelessWidget {
  const _ReportPreviewPanel({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        AppSpacing.gapSM,
        for (var index = 0; index < lines.length; index++) ...[
          SelectableText(lines[index]),
          if (index != lines.length - 1) const SizedBox(height: 6),
        ],
      ],
    ),
  );
}

class _StatusSourcePreview extends StatelessWidget {
  const _StatusSourcePreview({required this.export});

  final StatusReportSyncSourceExport export;

  @override
  Widget build(BuildContext context) {
    final source = export.source;
    final work = source.work;
    final isHoliday = work.workType == 'holiday';
    return Column(
      key: const ValueKey('status-source-preview-text'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportPreviewPanel(
          icon: Icons.calendar_today_outlined,
          title: 'STATUS',
          lines: ['OPERATION DATE  ${source.operationDate}'],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.monitor_weight_outlined,
          title: 'BODY',
          lines: [
            'WEIGHT  ${_value(source.body.weightKg, 'kg')}',
            'BODY FAT  ${_value(source.body.bodyFatPercent, '%')}',
          ],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.bedtime_outlined,
          title: 'RECOVERY',
          lines: [
            'SLEEP  ${_duration(source.recovery.sleepDurationMinutes)}',
            'SLEEP SCORE  ${source.recovery.sleepScore ?? 'NOT RECORDED'}',
          ],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.health_and_safety_outlined,
          title: 'CONDITION',
          lines: [
            'FOOT CONDITION  ${source.condition.footPainLevel}',
            if (source.condition.condition != null)
              'CONDITION  ${source.condition.condition}',
            if (source.condition.notes != null)
              'NOTES  ${source.condition.notes}',
          ],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.work_outline,
          title: 'WORK',
          lines: isHoliday
              ? const ['公休日']
              : [
                  'WORK TYPE  ${work.workType}',
                  if (work.startTime != null && work.endTime != null)
                    'TIME  ${work.startTime} - ${work.endTime}',
                  if (work.breakDurationMinutes != null)
                    'BREAK  ${_duration(work.breakDurationMinutes)}',
                  'WORK HOURS  ${_value(work.workHours, 'h')}',
                ],
        ),
        AppSpacing.gapSM,
        _ReportPreviewPanel(
          icon: Icons.history_outlined,
          title: 'CARRYOVER',
          lines: [
            source.previousCarryoverConfirmed == null
                ? 'NOT RECORDED'
                : source.previousCarryoverConfirmed!
                ? 'CONFIRMED'
                : 'NONE',
          ],
        ),
      ],
    );
  }

  static String _value(num? value, String unit) =>
      value == null ? 'NOT RECORDED' : '${value.toString()} $unit';

  static String _duration(int? minutes) {
    if (minutes == null) return 'NOT RECORDED';
    return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});
  final ReportSyncResponsePreview preview;

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(preview.disposition.name.toUpperCase()),
          Text('Operation Date  ${preview.operationDate}'),
          Text('CREATE  ${preview.createCount}'),
          Text('NO CHANGES  ${preview.noChangeCount}'),
          Text('CONFLICT  ${preview.conflictCount}'),
          if (preview.trainingPreview != null) ...[
            Text('INVALID  ${preview.trainingPreview!.invalidCount}'),
            Text('BLOCKED  ${preview.trainingPreview!.blockedCount}'),
          ],
          if (preview.exchangeType == ReportSyncExchangeType.training)
            ..._trainingPreviewLines(preview),
        ],
      ),
    );
  }
}

List<Widget> _trainingPreviewLines(ReportSyncResponsePreview preview) {
  final historicalPayload = Map<String, Object?>.from(
    preview.trainingPreview!.envelope['payload']! as Map,
  );
  final records = List<Object?>.from(historicalPayload['records']! as List);
  return [
    AppSpacing.gapSM,
    Text('Records  ${records.length}'),
    for (var index = 0; index < records.length; index++) ...[
      Builder(
        builder: (_) {
          final record = Map<String, Object?>.from(records[index] as Map);
          final session = Map<String, Object?>.from(record['session'] as Map);
          final header = Map<String, Object?>.from(session['session'] as Map);
          final rawSessionName = header['name'];
          final sessionName =
              rawSessionName is String && rawSessionName.trim().isNotEmpty
              ? rawSessionName
              : 'NOT RECORDED';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record ${index + 1}  ${record['operationDate']}  '
                '${record['sourceRecordId'] ?? '-'}',
              ),
              Text(
                'Session  $sessionName  '
                'Grade ${header['grade']}',
              ),
              Text(
                'Exercises  ${(session['exercises'] as List).length}  '
                'Cardio  ${(session['cardio'] as List).length}',
              ),
            ],
          );
        },
      ),
    ],
  ];
}

class _FoodPreviewCard extends StatelessWidget {
  const _FoodPreviewCard({
    required this.preview,
    required this.selectedMealIds,
    required this.onSelectionChanged,
  });

  final ReportSyncResponsePreview preview;
  final Set<String> selectedMealIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final selectableIds = {
      for (final item in preview.foodMeals)
        if (item.canSelect) item.previewId,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preview.disposition.name.toUpperCase()),
              Text('Operation Date  ${preview.envelope!.operationDate}'),
              Text('受信：${preview.foodMeals.length}件'),
              Text('選択：${selectedMealIds.length}件'),
              Text('競合：${preview.conflictCount}件'),
              Text('除外：${preview.foodMeals.length - selectedMealIds.length}件'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: selectableIds.isEmpty
                        ? null
                        : () => onSelectionChanged(selectableIds),
                    child: const Text('すべて選択'),
                  ),
                  OutlinedButton(
                    onPressed: selectedMealIds.isEmpty
                        ? null
                        : () => onSelectionChanged(const {}),
                    child: const Text('すべて解除'),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppSpacing.gapSM,
        for (final item in preview.foodMeals) ...[
          _FoodMealCard(
            key: ValueKey('food-meal-${item.previewId}'),
            meal: item.meal,
            status: _foodMealStatus(item.disposition),
            statusColor: _foodMealStatusColor(context, item.disposition),
            selected: selectedMealIds.contains(item.previewId),
            onSelected: item.canSelect
                ? (selected) {
                    final next = {...selectedMealIds};
                    selected == true
                        ? next.add(item.previewId)
                        : next.remove(item.previewId);
                    onSelectionChanged(next);
                  }
                : null,
          ),
          if (item != preview.foodMeals.last) AppSpacing.gapSM,
        ],
      ],
    );
  }
}

String _foodMealStatus(FoodReportSyncMealDisposition disposition) =>
    switch (disposition) {
      FoodReportSyncMealDisposition.create => 'AVAILABLE',
      FoodReportSyncMealDisposition.noChanges => 'IDENTICAL',
      FoodReportSyncMealDisposition.conflict => 'INVALID',
      FoodReportSyncMealDisposition.blocked => 'BLOCKED',
    };

Color _foodMealStatusColor(
  BuildContext context,
  FoodReportSyncMealDisposition disposition,
) => switch (disposition) {
  FoodReportSyncMealDisposition.create => Theme.of(context).colorScheme.primary,
  FoodReportSyncMealDisposition.noChanges => Theme.of(
    context,
  ).colorScheme.outline,
  FoodReportSyncMealDisposition.conflict ||
  FoodReportSyncMealDisposition.blocked => Theme.of(context).colorScheme.error,
};

class _FoodMealCard extends StatelessWidget {
  const _FoodMealCard({
    super.key,
    required this.meal,
    required this.status,
    required this.statusColor,
    this.selected,
    this.onSelected,
  });

  final MealData meal;
  final String status;
  final Color statusColor;
  final bool? selected;
  final ValueChanged<bool?>? onSelected;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onSelected == null ? null : () => onSelected!(!(selected ?? false)),
    borderRadius: BorderRadius.circular(12),
    child: OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selected != null)
                Checkbox(value: selected, onChanged: onSelected),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('MEAL TYPE  ${_mealTypeLabel(meal.mealType)}'),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          for (var index = 0; index < meal.items.length; index++) ...[
            _FoodItemPresentation(item: meal.items[index]),
            if (index != meal.items.length - 1) const Divider(),
          ],
          if (meal.waterMl != null) ...[
            const Divider(),
            Text('WATER  ${_formatNumber(meal.waterMl!)} ml'),
          ],
          if (meal.memo.trim().isNotEmpty) ...[
            const Divider(),
            Text(meal.memo.trim()),
          ],
        ],
      ),
    ),
  );
}

class _FoodItemPresentation extends StatelessWidget {
  const _FoodItemPresentation({required this.item});
  final FoodItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _foodItemLabel(item),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _NutritionValue(
              icon: Icons.local_fire_department_outlined,
              label: 'CAL',
              value: _formatNumber(item.totalCalories),
            ),
            _NutritionValue(
              icon: Icons.fitness_center,
              label: 'P',
              value: _formatNumber(item.totalProtein),
            ),
            _NutritionValue(
              icon: Icons.opacity,
              label: 'F',
              value: _formatNumber(item.totalFat),
            ),
            _NutritionValue(
              icon: Icons.rice_bowl_outlined,
              label: 'C',
              value: _formatNumber(item.totalCarbohydrate),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NutritionValue extends StatelessWidget {
  const _NutritionValue({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 4),
      Text('$label $value'),
    ],
  );
}

String _foodItemLabel(FoodItem item) {
  final name = item.name.trim();
  final amount = item.physicalAmount;
  final amountLabel = amount == null || item.baseUnit == null
      ? null
      : '${_formatNumber(amount)}${item.baseUnit!.label}';
  final normalizedName = name.replaceAll(RegExp(r'\s+'), '');
  final baseLabel = amountLabel == null || normalizedName.endsWith(amountLabel)
      ? name
      : '$name$amountLabel';
  return item.quantity == 1 ? baseLabel : '$baseLabel×${item.quantity}';
}

String _mealTypeLabel(String value) => switch (value.toLowerCase()) {
  'breakfast' => '朝食',
  'lunch' => '昼食',
  'dinner' => '夕食',
  'snack' => '間食',
  'water' => '水分',
  _ => value,
};

String _formatNumber(num value) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(1);
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});
  final List<ReportSyncHistory> history;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: history.isEmpty
        ? const Row(
            children: [
              Icon(Icons.receipt_long_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('RECORDはありません')),
            ],
          )
        : Column(
            children: [
              for (var index = 0; index < history.length; index++) ...[
                ListTile(
                  key: ValueKey(
                    'report-sync-record-${history[index].exchangeId}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    '${_reportSyncExchangeLabel(history[index].exchangeType)} · '
                    '${history[index].result.stableId.toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(history[index].operationDate),
                      if (history[index].exchangeType ==
                          ReportSyncExchangeType.food)
                        Text(_historyMealCounts(history[index])),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openReportSyncRecord(context, history[index]),
                ),
                if (index != history.length - 1) const Divider(),
              ],
            ],
          ),
  );
}

void _openReportSyncRecord(BuildContext context, ReportSyncHistory record) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => _ReportSyncRecordPage(record: record)),
  );
}

class _ReportSyncRecordArchivePage extends StatelessWidget {
  const _ReportSyncRecordArchivePage({required this.history});

  final List<ReportSyncHistory> history;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('REPORT SYNC RECORD')),
    body: ListView.separated(
      padding: AppSpacing.cardPadding,
      itemCount: history.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) => ListTile(
        key: ValueKey('all-report-sync-record-${history[index].exchangeId}'),
        leading: Icon(_reportSyncResultIcon(history[index].result)),
        title: Text(
          '${_reportSyncExchangeLabel(history[index].exchangeType)} · '
          '${history[index].result.stableId.toUpperCase()}',
        ),
        subtitle: Text(
          '${history[index].operationDate} · '
          '${history[index].result.stableId.toUpperCase()}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openReportSyncRecord(context, history[index]),
      ),
    ),
  );
}

class _ReportSyncRecordPage extends StatelessWidget {
  const _ReportSyncRecordPage({required this.record});

  final ReportSyncHistory record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('REPORT SYNC RECORD')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_reportSyncResultIcon(record.result)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.result.stableId.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMD,
              _RecordField(
                label: 'OPERATION DATE',
                value: record.operationDate,
              ),
              if (record.exchangeType != ReportSyncExchangeType.food) ...[
                _RecordField(
                  label: 'EXCHANGE TYPE',
                  value: _reportSyncExchangeLabel(record.exchangeType),
                ),
                _RecordField(
                  label: 'DIRECTION',
                  value: record.direction.stableId,
                ),
                _RecordField(label: 'EXCHANGE ID', value: record.exchangeId),
                _RecordField(label: 'REQUEST ID', value: record.requestId),
                _RecordField(
                  label: 'COMPLETED AT',
                  value: record.completedAt.toLocal().toString(),
                ),
              ],
              if (record.failureCode != null)
                _RecordField(
                  label: 'FAILURE CODE',
                  value: record.failureCode!.stableId,
                ),
              if (record.exchangeType == ReportSyncExchangeType.food)
                _RecordField(
                  label: 'MEAL COUNTS',
                  value: _historyMealCounts(record),
                ),
            ],
          ),
        ),
        if (record.exchangeType == ReportSyncExchangeType.food &&
            record.importedMealSnapshots.isNotEmpty) ...[
          AppSpacing.gapSM,
          for (
            var index = 0;
            index < record.importedMealSnapshots.length;
            index++
          ) ...[
            _FoodMealCard(
              key: ValueKey('history-food-meal-$index'),
              meal: record.importedMealSnapshots[index],
              status: 'IMPORTED',
              statusColor: Theme.of(context).colorScheme.primary,
            ),
            if (index != record.importedMealSnapshots.length - 1)
              AppSpacing.gapSM,
          ],
        ] else if (record.exchangeType == ReportSyncExchangeType.food &&
            record.detailsArchived) ...[
          AppSpacing.gapSM,
          const Text('DETAIL ARCHIVED / NOT AVAILABLE'),
        ],
      ],
    ),
  );
}

class _RecordField extends StatelessWidget {
  const _RecordField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    ),
  );
}

IconData _reportSyncResultIcon(ReportSyncHistoryResult result) =>
    switch (result) {
      ReportSyncHistoryResult.success => Icons.check_circle_outline,
      ReportSyncHistoryResult.failed => Icons.error_outline,
      ReportSyncHistoryResult.noChange => Icons.check_circle_outline,
      ReportSyncHistoryResult.conflict => Icons.warning_amber,
    };

String _historyMealCounts(ReportSyncHistory history) {
  if (history.recordVersion == 1) return 'Meal件数の記録はありません';
  String value(int? count) => count == null ? '記録なし' : '$count件';
  return '受信Meal：${value(history.receivedMealCount)}  '
      '選択Meal：${value(history.selectedMealCount)}\n'
      '取り込み成功：${value(history.importedMealCount)}  '
      '競合Meal：${value(history.conflictMealCount)}  '
      '除外Meal：${value(history.excludedMealCount)}';
}

String _stateLabel(ReportSyncRequestPreparation? request) {
  if (request == null) return 'LOADING';
  if (!request.isReady) return request.statusLabel;
  return 'EXPORT READY';
}

String _title(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'TRAINING REPORT SYNC',
  ReportSyncExchangeType.trainingAnalysis => 'TRAINING ANALYSIS REPORT',
  ReportSyncExchangeType.trainingPlan => 'TRAINING PLAN',
  ReportSyncExchangeType.food => 'FOOD REPORT SYNC',
  ReportSyncExchangeType.morningBrief => 'DAILY BRIEF REPORT SYNC',
  ReportSyncExchangeType.dailyDebrief => 'DAILY DEBRIEF',
  ReportSyncExchangeType.periodicReport => 'PERIODIC REPORT',
};

String _reportSyncExchangeLabel(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'TRAINING SYNC',
  ReportSyncExchangeType.trainingAnalysis => 'TRAINING ANALYSIS',
  ReportSyncExchangeType.trainingPlan => 'TRAINING PLAN',
  ReportSyncExchangeType.food => 'FOOD SYNC',
  ReportSyncExchangeType.morningBrief => 'DAILY BRIEF',
  ReportSyncExchangeType.dailyDebrief => 'DAILY DEBRIEF',
  ReportSyncExchangeType.periodicReport => 'PERIODIC REPORT',
};

IconData _icon(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => Icons.fitness_center,
  ReportSyncExchangeType.trainingAnalysis => Icons.analytics_outlined,
  ReportSyncExchangeType.trainingPlan => Icons.event_note_outlined,
  ReportSyncExchangeType.food => Icons.restaurant_outlined,
  ReportSyncExchangeType.morningBrief => Icons.wb_sunny_outlined,
  ReportSyncExchangeType.dailyDebrief => Icons.nightlight_outlined,
  ReportSyncExchangeType.periodicReport => Icons.calendar_view_month_outlined,
};

String _importLabel(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'IMPORT TRAINING',
  ReportSyncExchangeType.trainingAnalysis => 'IMPORT TRAINING ANALYSIS',
  ReportSyncExchangeType.trainingPlan => 'IMPORT TRAINING PLAN',
  ReportSyncExchangeType.food => 'IMPORT FOOD',
  ReportSyncExchangeType.morningBrief => 'IMPORT DAILY BRIEF',
  ReportSyncExchangeType.dailyDebrief => 'IMPORT DAILY DEBRIEF',
  ReportSyncExchangeType.periodicReport => 'IMPORT PERIODIC REPORT',
};

String _sourceName(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'Training Record',
  ReportSyncExchangeType.trainingAnalysis => 'Formal Training Fact Package',
  ReportSyncExchangeType.trainingPlan => 'Formal Training Plan Fact Package',
  ReportSyncExchangeType.food => 'Meal Data',
  ReportSyncExchangeType.morningBrief => 'STATUS Source',
  ReportSyncExchangeType.dailyDebrief => 'DAILY AGGREGATE Source',
  ReportSyncExchangeType.periodicReport => 'Periodic Formal Fact Package',
};

String _copySourceLabel(ReportSyncExchangeType type) => switch (type) {
  ReportSyncExchangeType.training => 'COPY TRAINING RECORD',
  ReportSyncExchangeType.trainingAnalysis => 'COPY TRAINING ANALYSIS PROMPT',
  ReportSyncExchangeType.trainingPlan => 'COPY TRAINING PLAN PROMPT',
  ReportSyncExchangeType.food => 'COPY MEAL DATA',
  ReportSyncExchangeType.morningBrief => 'STATUS SOURCE',
  ReportSyncExchangeType.dailyDebrief => 'DAILY DEBRIEF SOURCE',
  ReportSyncExchangeType.periodicReport => 'COPY PERIODIC REPORT PROMPT',
};

String _formatLocalDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _validationErrorText(Object error, String rawInput) {
  Object? decoded;
  try {
    decoded = jsonDecode(rawInput);
  } on FormatException {
    return 'INVALID JSON\n'
        'JSONを読み取れませんでした。'
        'Markdown、説明文、スマートクォート、末尾カンマ等が含まれていないか確認してください。';
  }

  final identity = _validationIdentity(decoded);
  final state = identity.operationDate == null
      ? 'INVALID'
      : '${identity.operationDate}・INVALID';
  final sourceId = identity.sourceRecordId ?? 'SOURCE ID NOT AVAILABLE';

  if (error is ReportSyncException) {
    final validation = error.validationError;
    if (validation != null) {
      return '$state\n'
          '$sourceId\n'
          '${validation.jsonPath}: ${error.code.stableId}：'
          '${_reportSyncIssueCodeLabel(error.code)} '
          '${_localizedValidationReason(validation.message)}';
    }
    if (error.code == ReportSyncIssueCode.schemaMismatch) {
      return '$state\n$sourceId\n\$: ${error.code.stableId}：'
          '${_reportSyncIssueCodeLabel(error.code)} '
          '${_localizedValidationReason(error.message)}';
    }
    return 'ERROR\n$sourceId\n${error.code.stableId}：'
        '${_reportSyncIssueCodeLabel(error.code)} ${_errorText(error)}';
  }
  if (error is FormatException) {
    return '$state\n$sourceId\n\$: schemaMismatch：'
        'スキーマ不一致 ${_localizedValidationReason(error.message)}';
  }
  return 'ERROR\n$sourceId\n${_errorText(error)}';
}

String _reportSyncIssueCodeLabel(ReportSyncIssueCode code) => switch (code) {
  ReportSyncIssueCode.operationDateMismatch => '対象日不一致',
  ReportSyncIssueCode.exchangeTypeMismatch => '交換種別不一致',
  ReportSyncIssueCode.schemaMismatch => 'スキーマ不一致',
  ReportSyncIssueCode.integrityFailure => '整合性検証失敗',
  ReportSyncIssueCode.requestDigestMismatch => 'リクエストダイジェスト不一致',
  ReportSyncIssueCode.responseDigestMismatch => 'レスポンスダイジェスト不一致',
  ReportSyncIssueCode.recordConflict => 'レコード競合',
  ReportSyncIssueCode.requestNotFound => 'リクエスト未検出',
  ReportSyncIssueCode.duplicateNoChange => '重複・変更なし',
};

String? _reportSyncIssueCodeLabelByStableId(String stableId) {
  for (final code in ReportSyncIssueCode.values) {
    if (code.stableId == stableId) return _reportSyncIssueCodeLabel(code);
  }
  return null;
}

String _localizedValidationDetails(String details) => details
    .split('\n')
    .map((line) {
      final match = RegExp(
        r'^(.*): ([A-Za-z][A-Za-z0-9]*): (.*)$',
      ).firstMatch(line);
      if (match == null) return line;
      final code = match.group(2)!;
      final label = _reportSyncIssueCodeLabelByStableId(code);
      if (label == null) return line;
      return '${match.group(1)}: $code：$label '
          '${_localizedValidationReason(match.group(3)!)}';
    })
    .join('\n');

String _localizedValidationReason(String reason) => switch (reason) {
  r'$ contains unknown or missing fields.' => '不明な項目または必須項目の不足があります。',
  _ => reason,
};

({String? operationDate, String? sourceRecordId}) _validationIdentity(
  Object? decoded,
) {
  if (decoded is! Map) return (operationDate: null, sourceRecordId: null);
  final root = Map<String, Object?>.from(decoded);
  final payloadValue = root['payload'];
  final payload = payloadValue is Map
      ? Map<String, Object?>.from(payloadValue)
      : const <String, Object?>{};
  final recordsValue = payload['records'];
  final firstRecord = recordsValue is List && recordsValue.isNotEmpty
      ? recordsValue.first
      : null;
  final record = firstRecord is Map
      ? Map<String, Object?>.from(firstRecord)
      : const <String, Object?>{};

  String? nonEmptyString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  return (
    operationDate:
        nonEmptyString(record['operationDate']) ??
        nonEmptyString(payload['operationDate']) ??
        nonEmptyString(root['operationDate']),
    sourceRecordId:
        nonEmptyString(record['sourceRecordId']) ??
        nonEmptyString(payload['sourceRecordId']) ??
        nonEmptyString(root['sourceRecordId']),
  );
}

String _errorText(Object error) => switch (error) {
  _ChatGptPromptCopyException() => 'CHATGPT PROMPTをコピーできませんでした',
  ReportSyncException value when value.validationError != null =>
    '取り込めない項目：${value.validationError!.jsonPath}\n'
        '理由：${value.validationError!.message}\n'
        '期待される形式：${value.validationError!.expected}',
  ReportSyncException value => switch (value.code) {
    ReportSyncIssueCode.operationDateMismatch =>
      '対象日が一致しません。選択した日付のJSONを使用してください。',
    ReportSyncIssueCode.exchangeTypeMismatch =>
      '対象モジュールが一致しません。正しいREPORT SYNC画面を使用してください。',
    ReportSyncIssueCode.schemaMismatch =>
      'JSON形式が正しくありません。Markdown、説明文、スマートクォート、末尾カンマ、未知の項目は使用できません。',
    ReportSyncIssueCode.integrityFailure ||
    ReportSyncIssueCode.requestDigestMismatch ||
    ReportSyncIssueCode.responseDigestMismatch =>
      'JSONの整合性を確認できません。ChatGPTの返答を変更せずに貼り付けてください。',
    ReportSyncIssueCode.recordConflict => '同じIDの異なる記録が存在するため取り込めません。',
    ReportSyncIssueCode.requestNotFound ||
    ReportSyncIssueCode.duplicateNoChange => value.message,
  },
  FormatException _ => '入力内容が正しくありません。JSONと各項目の型・値を確認してください。',
  StateError value => value.message,
  _ => '処理に失敗しました。入力内容を確認してください。',
};

class _ChatGptPromptCopyException implements Exception {
  const _ChatGptPromptCopyException();
}

String _importErrorText(Object error) => switch (error) {
  ReportSyncImportFailure value =>
    'Error Code: ${value.code}\n'
        'Failure Stage: ${value.stage}\n'
        '${value.message}',
  ReportSyncApplyException value =>
    'Error Code：${value.code}\n'
        '失敗段階：${value.stage}\n'
        '${value.userMessage}',
  ReportSyncException value => _errorText(value),
  _ =>
    'Error Code：unexpected_import_failure\n'
        '失敗段階：IMPORT\n'
        'データを取り込めませんでした。保存内容は変更されていません。',
};
