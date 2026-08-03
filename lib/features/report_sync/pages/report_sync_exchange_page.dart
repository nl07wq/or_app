import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/models/food_item.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_gateway.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../models/report_sync_envelope.dart';
import '../models/report_sync_history.dart';
import '../models/report_sync_issue.dart';
import '../services/report_sync_clipboard_gateway.dart';
import '../services/report_sync_exchange_gateway.dart';

typedef ReportSyncClipboardWriter = Future<void> Function(String text);

class ReportSyncExchangePage extends StatelessWidget {
  const ReportSyncExchangePage({
    super.key,
    required this.exchangeType,
    this.gateway,
    this.fileGateway,
    this.clipboardWriter,
    this.clipboardGateway,
  });

  final ReportSyncExchangeType exchangeType;
  final ReportSyncExchangeGateway? gateway;
  final BackupFileGateway? fileGateway;
  final ReportSyncClipboardWriter? clipboardWriter;
  final ReportSyncClipboardGateway? clipboardGateway;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title(exchangeType))),
    body: ReportSyncExchangePanel(
      exchangeType: exchangeType,
      gateway: gateway,
      fileGateway: fileGateway,
      clipboardWriter: clipboardWriter,
      clipboardGateway: clipboardGateway,
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
  });

  final ReportSyncExchangeType exchangeType;
  final ReportSyncExchangeGateway? gateway;
  final BackupFileGateway? fileGateway;
  final ReportSyncClipboardWriter? clipboardWriter;
  final ReportSyncClipboardGateway? clipboardGateway;

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
  String? _message;
  String? _error;
  String? _importError;
  Set<String> _selectedMealIds = const {};

  bool get _isImportOnly =>
      widget.exchangeType == ReportSyncExchangeType.training ||
      widget.exchangeType == ReportSyncExchangeType.food;

  bool get _hasValidTargetDate {
    if (!_isImportOnly) return _request?.isReady ?? false;
    try {
      OperationLocalDate.parse(_targetDateController.text);
      return true;
    } on FormatException {
      return false;
    }
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
      _error = null;
    });
    try {
      final request = await _gateway.prepareRequest(widget.exchangeType);
      final history = await _gateway.history(widget.exchangeType);
      if (!mounted) return;
      setState(() {
        _request = request;
        if (_isImportOnly && _targetDateController.text.isEmpty) {
          _targetDateController.text = request.operationDate ?? '';
        }
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
      if (request == null || !_hasValidTargetDate) {
        throw StateError('The exchange target is not ready.');
      }
      final instructionRequest = _isImportOnly
          ? ReportSyncRequestPreparation(
              operationDate: _targetDateController.text,
            )
          : request;
      await _clipboardWriter(
        _gateway.instruction(widget.exchangeType, instructionRequest),
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

  Future<void> _selectTargetDate() async {
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
      _preview = null;
      _selectedMealIds = const {};
      _message = null;
      _error = null;
      _importError = null;
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

  Future<void> _pasteResponse() async {
    await _run(() async {
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
      _message = 'クリップボードの内容を貼り付けました';
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
      _preview = await _gateway.previewResponse(
        widget.exchangeType,
        raw,
        targetDate: _isImportOnly ? _targetDateController.text : null,
      );
      _selectedMealIds = {
        for (final item in _preview!.foodMeals)
          if (item.canSelect) item.previewId,
      };
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
    setState(() {
      _busy = true;
      _importError = null;
      _message = null;
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
      _responseController.clear();
      _preview = null;
      final importedMealCount = result.mealCounts?.imported;
      _message = result.disposition == ReportSyncDisposition.noChanges
          ? 'NO CHANGES'
          : importedMealCount == null
          ? 'COMPLETE · READ-BACK VERIFIED'
          : '$importedMealCount件のMEALを取り込みました';
      final request = await _gateway.prepareRequest(
        widget.exchangeType,
        targetDate: _isImportOnly ? _targetDateController.text : null,
      );
      _request = request;
      _history = await _gateway.history(widget.exchangeType);
    } catch (error) {
      _importError = _importErrorText(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _importError = null;
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
        if (_isImportOnly)
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: ready && !_busy ? _copyInstruction : null,
              icon: const Icon(Icons.content_copy),
              label: const Text('COPY CHATGPT PROMPT'),
            ),
            if (!_isImportOnly)
              OutlinedButton.icon(
                onPressed: request?.canCopySource == true && !_busy
                    ? _copySource
                    : null,
                icon: const Icon(Icons.copy_all_outlined),
                label: Text(_copySourceLabel(widget.exchangeType)),
              ),
          ],
        ),
        if (!_isImportOnly) ...[
          AppSpacing.gapSM,
          OperationCard(
            child: Text(
              'プロンプトを貼り付けた後、コピーした正式な'
              '${_sourceName(widget.exchangeType)}をChatGPTへ貼り付けてください。',
            ),
          ),
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
                  _importError = null;
                }),
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
          if (widget.exchangeType == ReportSyncExchangeType.food)
            _FoodPreviewCard(
              preview: _preview!,
              selectedMealIds: _selectedMealIds,
              onSelectionChanged: (value) => setState(() {
                _selectedMealIds = value;
                _importError = null;
              }),
            )
          else
            _PreviewCard(preview: _preview!),
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

  static const importOnlySteps = [
    '① 対象日を確認する',
    '② ChatGPT用プロンプトをコピーする',
    '③ ChatGPTへ貼り付ける',
    '④ ChatGPTが保持している対象日の記録からJSONを作成させる',
    '⑤ 返されたJSONだけをコピーする',
    '⑥ JSONを貼り付ける、またはJSONファイルを選択する',
    '⑦ 内容を確認してインポートする',
  ];

  @override
  Widget build(BuildContext context) {
    final importOnly =
        exchangeType == ReportSyncExchangeType.training ||
        exchangeType == ReportSyncExchangeType.food;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('使い方', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSM,
          for (final step in importOnly ? importOnlySteps : steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(step),
            ),
          AppSpacing.gapSM,
          const Text('プロンプトには変換ルールとResponse JSON Schemaが含まれます。'),
          if (!importOnly) ...[
            AppSpacing.gapSM,
            Text('対象データ: ${_sourceName(exchangeType)}'),
          ],
        ],
      ),
    );
  }
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
        if (preview.envelope.exchangeType == ReportSyncExchangeType.training)
          ..._trainingPreviewLines(preview.envelope.payload),
        if (preview.message != null) Text(preview.message!),
      ],
    ),
  );
}

List<Widget> _trainingPreviewLines(Map<String, Object?> payload) {
  final session = Map<String, Object?>.from(payload['session'] as Map);
  final header = Map<String, Object?>.from(session['session'] as Map);
  final exercises = session['exercises'] as List;
  final cardio = session['cardio'] as List;
  return [
    AppSpacing.gapSM,
    Text('Record ID  ${payload['recordId']}'),
    Text('Session  ${header['name']}  Grade ${header['grade']}'),
    Text('Exercises  ${exercises.length}  Cardio  ${cardio.length}'),
    for (final raw in exercises)
      Builder(
        builder: (_) {
          final exercise = Map<String, Object?>.from(raw as Map);
          return Text(
            '${exercise['exerciseName']}  '
            '${exercise['equipment'] == null ? 'No equipment' : (exercise['equipment'] as Map)['name']}  '
            'Sets ${(exercise['sets'] as List).length}',
          );
        },
      ),
    for (final raw in cardio)
      Builder(
        builder: (_) {
          final entry = Map<String, Object?>.from(raw as Map);
          return Text(
            '${entry['type']}  ${entry['durationSeconds']} sec  '
            '${entry['distanceKm'] ?? '-'} km',
          );
        },
      ),
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
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(preview.disposition.name.toUpperCase()),
          Text('Operation Date  ${preview.envelope.operationDate}'),
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
          AppSpacing.gapSM,
          for (final item in preview.foodMeals) ...[
            CheckboxListTile(
              key: ValueKey('food-meal-${item.previewId}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: selectedMealIds.contains(item.previewId),
              onChanged: item.canSelect
                  ? (selected) {
                      final next = {...selectedMealIds};
                      selected == true
                          ? next.add(item.previewId)
                          : next.remove(item.previewId);
                      onSelectionChanged(next);
                    }
                  : null,
              title: Text('${item.meal.mealType}  ${item.meal.id}'),
              subtitle: Text(
                '${_foodMealStatus(item.disposition)}\n'
                'Items ${item.meal.items.length}  '
                'Calories ${item.meal.calories}  '
                'P ${item.meal.protein} / F ${item.meal.fat} / '
                'C ${item.meal.carbohydrate}'
                '${item.meal.waterMl == null ? '' : '  Water ${item.meal.waterMl} ml'}'
                '${item.meal.memo.isEmpty ? '' : '\nMemo ${item.meal.memo}'}'
                '${_foodItemDetails(item.meal.items)}',
              ),
              isThreeLine: true,
            ),
            if (item != preview.foodMeals.last) const Divider(),
          ],
          if (preview.message != null) Text(preview.message!),
        ],
      ),
    );
  }
}

String _foodMealStatus(FoodReportSyncMealDisposition disposition) =>
    switch (disposition) {
      FoodReportSyncMealDisposition.create => '取り込み可能',
      FoodReportSyncMealDisposition.noChanges => '取り込み済み（同一内容）',
      FoodReportSyncMealDisposition.conflict => '競合のため選択できません',
      FoodReportSyncMealDisposition.blocked => '確定済みのため選択できません',
    };

String _foodItemDetails(List<FoodItem> items) => items.isEmpty
    ? ''
    : '\n${items.map((item) => '${item.name} ×${item.quantity}  Calories ${item.totalCalories}  P ${item.totalProtein} / F ${item.totalFat} / C ${item.totalCarbohydrate}').join('\n')}';

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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${history[index].operationDate} · '
                        '${history[index].result.stableId} · '
                        '${history[index].completedAt.toLocal()}'
                        '${history[index].failureCode == null ? '' : ' · ${history[index].failureCode!.stableId}'}',
                      ),
                      if (history[index].exchangeType ==
                          ReportSyncExchangeType.food)
                        Text(_historyMealCounts(history[index])),
                    ],
                  ),
                ),
                if (index != history.length - 1) const Divider(),
              ],
            ],
          ),
  );
}

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

String _formatLocalDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _errorText(Object error) => switch (error) {
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
    ReportSyncIssueCode.confirmationDigestMismatch => '確定情報が一致しないため取り込めません。',
    ReportSyncIssueCode.requestNotFound ||
    ReportSyncIssueCode.duplicateNoChange => value.message,
  },
  FormatException _ => '入力内容が正しくありません。JSONと各項目の型・値を確認してください。',
  StateError value => value.message,
  _ => '処理に失敗しました。入力内容を確認してください。',
};

String _importErrorText(Object error) => switch (error) {
  ReportSyncApplyException value =>
    'Error Code：${value.code}\n'
        '失敗段階：${value.stage}\n'
        '${value.userMessage}',
  _ =>
    'Error Code：unexpected_import_failure\n'
        '失敗段階：IMPORT\n'
        'MEALを取り込めませんでした。保存内容は変更されていません。',
};
