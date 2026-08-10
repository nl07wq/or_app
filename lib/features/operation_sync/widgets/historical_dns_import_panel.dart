import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../report_sync/services/report_sync_clipboard_gateway.dart';
import '../models/operation_sync_history.dart';
import '../services/historical_dns_workflow.dart';

class HistoricalDnsImportPanel extends StatefulWidget {
  final HistoricalDnsWorkflow? workflow;
  final VoidCallback? onRecordSaved;

  const HistoricalDnsImportPanel({
    super.key,
    required this.workflow,
    this.onRecordSaved,
  });

  @override
  State<HistoricalDnsImportPanel> createState() =>
      _HistoricalDnsImportPanelState();
}

class _HistoricalDnsImportPanelState extends State<HistoricalDnsImportPanel> {
  final _controller = TextEditingController();
  final ReportSyncClipboardGateway _clipboard =
      ReportSyncClipboardGateway.platform();
  HistoricalDnsPreview? _preview;
  Set<int> _selectedIndexes = {};
  DateTimeRange? _range;
  String? _error;
  String? _message;
  bool _busy = false;

  String get _startDate => _formatDate(_range!.start);
  String get _endDate => _formatDate(_range!.end);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectRange() async {
    final today = DateTime.now();
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: _range,
      helpText: 'SELECT LEGACY DNS RANGE',
      saveText: 'USE RANGE',
    );
    if (value == null || !mounted) return;
    setState(() {
      _range = value;
      _controller.clear();
      _preview = null;
      _selectedIndexes = {};
      _error = null;
      _message = 'DATE RANGE SELECTED';
    });
  }

  Future<void> _copyPrompt() async {
    final workflow = widget.workflow;
    if (workflow == null) return;
    if (_range == null) {
      setState(() => _error = '先に期間を選択してください。');
      return;
    }
    try {
      await _clipboard.writeText(
        workflow.buildPrompt(startDate: _startDate, endDate: _endDate),
      );
      if (mounted) setState(() => _message = 'CHATGPT PROMPT COPIED');
    } catch (error) {
      if (mounted) setState(() => _error = 'COPY FAILED: $error');
    }
  }

  Future<void> _paste() async {
    try {
      final value = await _clipboard.readText();
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        setState(() => _error = 'クリップボードにテキストがありません。');
        return;
      }
      _controller.text = value;
      setState(() {
        _preview = null;
        _selectedIndexes = {};
        _error = null;
        _message = 'RESPONSE JSON PASTED';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'PASTE FAILED: $error');
    }
  }

  Future<void> _validate() async {
    final workflow = widget.workflow;
    if (workflow == null) return;
    if (_range == null) {
      setState(() => _error = '先に期間を選択してください。');
      return;
    }
    if (_controller.text.isEmpty) {
      setState(() => _error = '検証前にResponse JSONを貼り付けてください。');
      return;
    }
    setState(() {
      _busy = true;
      _preview = null;
      _selectedIndexes = {};
      _error = null;
      _message = null;
    });
    try {
      final value = await workflow.preview(
        _controller.text,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _preview = value;
        _selectedIndexes = {
          for (final item in value.records)
            if (item.isSelectable) item.index,
        };
        _message = value.canApply
            ? 'VALIDATION COMPLETE · REVIEW BEFORE IMPORT'
            : 'VALIDATION BLOCKED';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final selectedNew = preview.records
        .where(
          (item) =>
              _selectedIndexes.contains(item.index) &&
              item.disposition == OperationSyncRecordDisposition.newRecord,
        )
        .length;
    final selectedDifferent = preview.records
        .where(
          (item) =>
              _selectedIndexes.contains(item.index) &&
              item.disposition == OperationSyncRecordDisposition.conflict,
        )
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT LEGACY DNS?'),
        content: Text(
          'Daily Aggregateを$selectedNew件作成し、'
          '$selectedDifferent件を安全に置換します。',
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
      _error = null;
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
            'RANGE ${result.record.startDate ?? 'N/A'} – '
            '${result.record.endDate ?? 'N/A'}\n'
            'RECORD ${result.record.operationId}';
      });
      widget.onRecordSaved?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
              'HISTORICAL DNS IMPORT',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.gapMD,
            const _ContractField(
              label: 'RECORD TYPE',
              value: 'DAILY AGGREGATE V1',
            ),
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
                    : '$_startDate – $_endDate',
              ),
            ),
            AppSpacing.gapSM,
            const Text('ChatGPTが保持する旧DNSを、選択期間のDaily Aggregateへ変換します。'),
            AppSpacing.gapMD,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.workflow != null && !_busy
                    ? _copyPrompt
                    : null,
                icon: const Icon(Icons.content_copy),
                label: const Text('COPY CHATGPT PROMPT'),
              ),
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
                _error = null;
              }),
            ),
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
      if (_error != null) ...[
        AppSpacing.gapSM,
        SelectableText(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (_message != null) ...[AppSpacing.gapSM, SelectableText(_message!)],
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
  final HistoricalDnsPreview preview;
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
        Text('DIFFERENT ${preview.differentCount}'),
        Text('INVALID ${preview.invalidCount}'),
        Text('EXCLUDED ${preview.excludedCount}'),
        Text('BLOCKED ${preview.blockedCount}'),
        Text(
          'RANGE ${preview.startDate ?? 'N/A'} – ${preview.endDate ?? 'N/A'}',
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Icon(_icon(item.disposition)),
            value: item.isSelectable && selectedIndexes.contains(item.index),
            onChanged: item.isSelectable
                ? (value) => onSelectionChanged(item.index, value ?? false)
                : null,
            title: Text(
              '${item.operationDate ?? 'INVALID DATE'} · '
              '${_status(item.disposition)}',
            ),
            subtitle: Text(
              'SOURCE TYPE ${item.aggregate?.sourceType.name ?? 'NOT AVAILABLE'}'
              '${item.issues.isEmpty ? '' : '\n${item.issues.map((issue) => '${issue.path ?? r'$'}: ${issue.code}: ${issue.message}').join('\n')}'}',
            ),
          ),
          if (item.differences.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('DIFFERENCE PREVIEW'),
              children: [
                for (final difference in item.differences)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(difference.field),
                    subtitle: Text(
                      'CURRENT: ${_value(difference.current)}\n'
                      'INCOMING: ${_value(difference.incoming)}',
                    ),
                  ),
              ],
            ),
          if (item.index != preview.records.last.index) const Divider(),
        ],
        AppSpacing.gapMD,
        if (preview.canApply)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
              ),
              icon: const Icon(Icons.upload_outlined, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('選択したDNSをIMPORT', style: AppTextStyles.label),
              ),
            ),
          )
        else
          Text(
            'IMPORT BLOCKED',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );

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

  static String _status(OperationSyncRecordDisposition disposition) =>
      switch (disposition) {
        OperationSyncRecordDisposition.newRecord => 'NEW',
        OperationSyncRecordDisposition.identical => 'IDENTICAL',
        OperationSyncRecordDisposition.conflict => 'DIFFERENT',
        OperationSyncRecordDisposition.blocked => 'BLOCKED',
        OperationSyncRecordDisposition.invalid => 'INVALID',
        OperationSyncRecordDisposition.excluded => 'EXCLUDED',
        OperationSyncRecordDisposition.replaced => 'REPLACED',
      };

  static String _value(Object? value) => value == null ? 'null' : '$value';
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
