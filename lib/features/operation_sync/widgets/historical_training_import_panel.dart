import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../report_sync/services/report_sync_clipboard_gateway.dart';
import '../models/operation_sync_history.dart';
import '../services/historical_training_workflow.dart';

class HistoricalTrainingImportPanel extends StatefulWidget {
  final HistoricalTrainingWorkflow? workflow;
  final VoidCallback? onRecordSaved;

  const HistoricalTrainingImportPanel({
    super.key,
    required this.workflow,
    this.onRecordSaved,
  });

  @override
  State<HistoricalTrainingImportPanel> createState() =>
      _HistoricalTrainingImportPanelState();
}

class _HistoricalTrainingImportPanelState
    extends State<HistoricalTrainingImportPanel> {
  final _controller = TextEditingController();
  final ReportSyncClipboardGateway _clipboard =
      ReportSyncClipboardGateway.platform();
  HistoricalTrainingPreview? _preview;
  Set<int> _selectedIndexes = {};
  String? _inputError;
  String? _validationError;
  String? _applyError;
  String? _message;
  bool _busy = false;
  DateTimeRange? _range;

  String get _startDate => _formatDate(_range!.start);
  String get _endDate => _formatDate(_range!.end);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    final workflow = widget.workflow;
    if (workflow == null) return;
    if (_range == null) {
      setState(() => _inputError = '先に期間を選択してください。');
      return;
    }
    try {
      await _clipboard.writeText(
        workflow.buildPrompt(startDate: _startDate, endDate: _endDate),
      );
      if (mounted) setState(() => _message = 'CHATGPT PROMPT COPIED');
    } catch (error) {
      if (mounted) setState(() => _inputError = 'COPY FAILED: $error');
    }
  }

  Future<void> _paste() async {
    try {
      final value = await _clipboard.readText();
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        setState(() => _inputError = 'クリップボードにテキストがありません。');
        return;
      }
      _controller.text = value;
      setState(() {
        _preview = null;
        _selectedIndexes = {};
        _inputError = null;
        _validationError = null;
        _applyError = null;
        _message = 'RESPONSE JSON PASTED';
      });
    } catch (error) {
      if (mounted) setState(() => _inputError = 'PASTE FAILED: $error');
    }
  }

  Future<void> _validate() async {
    final workflow = widget.workflow;
    if (workflow == null) return;
    if (_range == null) {
      setState(() => _inputError = '先に期間を選択してください。');
      return;
    }
    if (_controller.text.isEmpty) {
      setState(() => _inputError = '検証前に応答JSONを貼り付けてください。');
      return;
    }
    setState(() {
      _busy = true;
      _preview = null;
      _selectedIndexes = {};
      _inputError = null;
      _validationError = null;
      _applyError = null;
      _message = null;
    });
    try {
      final preview = await workflow.preview(
        _controller.text,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _selectedIndexes = {
          for (final item in preview.records)
            if (item.isSelectable) item.index,
        };
        _message = preview.canApply
            ? 'VALIDATION COMPLETE · REVIEW BEFORE IMPORT'
            : 'VALIDATION BLOCKED';
      });
    } catch (error) {
      if (mounted) setState(() => _validationError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'SELECT HISTORICAL TRAINING RANGE',
      saveText: 'USE RANGE',
    );
    if (value == null || !mounted) return;
    setState(() {
      _range = value;
      _controller.clear();
      _preview = null;
      _selectedIndexes = {};
      _inputError = null;
      _validationError = null;
      _applyError = null;
      _message = 'DATE RANGE SELECTED · 新しいプロンプトをコピーしてください';
    });
  }

  Future<void> _apply() async {
    final workflow = widget.workflow;
    final preview = _preview;
    if (workflow == null ||
        preview == null ||
        !preview.canApply ||
        _selectedIndexes.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT HISTORICAL TRAINING?'),
        content: Text(
          'Training v2の新規記録を${_selectedIndexes.length}件作成します。'
          '既存の記録は変更または削除されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('IMPORT'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _applyError = null;
      _message = 'IMPORTING · この画面を閉じないでください';
    });
    try {
      final result = await workflow.apply(
        preview,
        selectedIndexes: Set.unmodifiable(_selectedIndexes),
      );
      if (!mounted) return;
      setState(() {
        _preview = null;
        _selectedIndexes = {};
        _controller.clear();
        _message =
            'COMPLETE · READ-BACK VERIFIED\n'
            'APPLIED ${result.record.appliedCount} · '
            'SKIPPED ${result.record.skippedCount}\n'
            'RANGE ${result.record.startDate ?? 'N/A'} — '
            '${result.record.endDate ?? 'N/A'}\n'
            'RECORD ${result.record.operationId}';
      });
      widget.onRecordSaved?.call();
    } catch (error) {
      if (mounted) setState(() => _applyError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'HISTORICAL TRAINING IMPORT',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.gapMD,
            const _ContractField(label: 'RECORD TYPE', value: 'TRAINING V2'),
            const _ContractField(label: 'SOURCE MODE', value: 'DATE RANGE'),
            const _ContractField(
              label: 'IMPORT MODE',
              value: 'MISSING RECORDS ONLY',
            ),
            AppSpacing.gapSM,
            OutlinedButton.icon(
              onPressed: widget.workflow != null && !_busy
                  ? _selectRange
                  : null,
              icon: const Icon(Icons.date_range),
              label: Text(
                _range == null
                    ? 'SELECT DATE RANGE'
                    : '$_startDate — $_endDate',
              ),
            ),
            AppSpacing.gapSM,
            const Text('保持されている記録が長い場合は、1か月以内の期間を選択してください。'),
            AppSpacing.gapMD,
            OutlinedButton.icon(
              onPressed: widget.workflow != null && !_busy ? _copyPrompt : null,
              icon: const Icon(Icons.content_copy),
              label: const Text('COPY CHATGPT PROMPT'),
            ),
          ],
        ),
      ),
      AppSpacing.gapMD,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'IMPORT RESPONSE',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.gapSM,
            OperationTextField(
              controller: _controller,
              label: 'RESPONSE JSON',
              hint: 'コピーしたJSONオブジェクトをここへ貼り付けてください。',
              maxLines: 10,
              onChanged: (_) => setState(() {
                _preview = null;
                _selectedIndexes = {};
                _inputError = null;
                _validationError = null;
                _applyError = null;
              }),
            ),
            if (_inputError != null) ...[
              AppSpacing.gapSM,
              _ErrorText(_inputError!),
            ],
            AppSpacing.gapMD,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.workflow != null && !_busy ? _paste : null,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('PASTE'),
                ),
                FilledButton.icon(
                  onPressed: widget.workflow != null && !_busy
                      ? _validate
                      : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('VALIDATE'),
                ),
              ],
            ),
            if (_validationError != null) ...[
              AppSpacing.gapSM,
              _ErrorText(_validationError!),
            ],
          ],
        ),
      ),
      if (_busy) ...[
        AppSpacing.gapMD,
        const Center(child: CircularProgressIndicator()),
      ],
      if (_preview != null) ...[
        AppSpacing.gapMD,
        _PreviewCard(
          preview: _preview!,
          selectedIndexes: _selectedIndexes,
          onSelectionChanged: (index, selected) => setState(() {
            if (selected) {
              _selectedIndexes.add(index);
            } else {
              _selectedIndexes.remove(index);
            }
          }),
          onSelectAll: () => setState(() {
            _selectedIndexes = {
              for (final item in _preview!.records)
                if (item.isSelectable) item.index,
            };
          }),
          onClearAll: () => setState(() => _selectedIndexes = {}),
          onApply: _selectedIndexes.isEmpty ? null : _apply,
        ),
      ],
      if (_applyError != null) ...[AppSpacing.gapSM, _ErrorText(_applyError!)],
      if (_message != null) ...[AppSpacing.gapSM, SelectableText(_message!)],
      if (widget.workflow == null) ...[
        AppSpacing.gapSM,
        const Text(
          'Historical Trainingのインポートは、永続ストレージを利用できる'
          'Web/PWAで使用できます。',
        ),
      ],
    ],
  );
}

class _ContractField extends StatelessWidget {
  final String label;
  final String value;
  const _ContractField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 116, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _PreviewCard extends StatelessWidget {
  final HistoricalTrainingPreview preview;
  final Set<int> selectedIndexes;
  final void Function(int index, bool selected) onSelectionChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final VoidCallback? onApply;
  const _PreviewCard({
    required this.preview,
    required this.selectedIndexes,
    required this.onSelectionChanged,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PREVIEW', style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        Text('RECEIVED ${preview.receivedCount}'),
        Text('NEW ${preview.newCount}'),
        Text('IDENTICAL ${preview.identicalCount}'),
        Text('CONFLICT ${preview.conflictCount}'),
        Text('INVALID ${preview.invalidCount}'),
        Text('EXCLUDED ${preview.excludedCount}'),
        Text('BLOCKED ${preview.blockedCount}'),
        Text(
          'RANGE ${preview.startDate ?? 'N/A'} — ${preview.endDate ?? 'N/A'}',
        ),
        Text(
          'REQUESTED ${preview.requestedStartDate} — '
          '${preview.requestedEndDate}',
        ),
        Text('SELECTED ${selectedIndexes.length} / ${preview.selectableCount}'),
        AppSpacing.gapSM,
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton(onPressed: onSelectAll, child: const Text('SELECT ALL')),
            TextButton(onPressed: onClearAll, child: const Text('CLEAR ALL')),
          ],
        ),
        AppSpacing.gapMD,
        for (final item in preview.records) ...[
          _PreviewRow(
            item: item,
            selected: selectedIndexes.contains(item.index),
            onChanged: item.isSelectable
                ? (value) => onSelectionChanged(item.index, value)
                : null,
          ),
          if (item.index != preview.records.last.index) const Divider(),
        ],
        AppSpacing.gapMD,
        if (preview.canApply)
          _HistoricalActionButton(
            text: '選択したTRAININGをIMPORT',
            icon: Icons.upload_outlined,
            onPressed: onApply,
          )
        else
          Text(
            'IMPORT BLOCKED',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  final HistoricalTrainingPreviewItem item;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  const _PreviewRow({
    required this.item,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final session = item.persistedRecord?.dataV2;
    final sessionName = session?.sessionName;
    final visibleSessionName = sessionName == null || sessionName.trim().isEmpty
        ? 'NOT RECORDED'
        : sessionName;
    final recordDetails = session == null
        ? ''
        : '\nSession $visibleSessionName'
              '\nGrade ${session.sessionGrade?.stableId ?? 'NOT RECORDED'}'
              '\nExercises ${session.exercises.length}'
              '\nCardio ${session.cardioEntries.length}';
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Icon(_icon(item.disposition)),
      value: item.isSelectable && selected,
      onChanged: onChanged == null
          ? null
          : (value) => onChanged!(value ?? false),
      title: Text(
        '${item.operationDate ?? 'INVALID DATE'} · '
        '${item.disposition.stableId.toUpperCase()}',
      ),
      subtitle: Text(
        '${item.sourceRecordId ?? 'SOURCE ID NOT AVAILABLE'}'
        '$recordDetails'
        '${item.issues.isEmpty ? '' : '\n${item.issues.map((issue) => '${issue.path ?? r'$'}: ${issue.message}').join('\n')}'}',
      ),
    );
  }

  static IconData _icon(OperationSyncRecordDisposition disposition) =>
      switch (disposition) {
        OperationSyncRecordDisposition.newRecord => Icons.add_circle_outline,
        OperationSyncRecordDisposition.identical => Icons.check_circle_outline,
        OperationSyncRecordDisposition.replaced => Icons.sync_alt,
        OperationSyncRecordDisposition.conflict => Icons.warning_amber,
        OperationSyncRecordDisposition.invalid => Icons.error_outline,
        OperationSyncRecordDisposition.excluded => Icons.remove_circle_outline,
        OperationSyncRecordDisposition.blocked => Icons.block,
      };
}

class _ErrorText extends StatelessWidget {
  final String value;
  const _ErrorText(this.value);

  @override
  Widget build(BuildContext context) => SelectableText(
    value,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

class _HistoricalActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  const _HistoricalActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text, style: AppTextStyles.label),
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
