import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_gateway.dart';
import '../../repositories/app_repository_container.dart';
import '../models/dns_archive_models.dart';
import '../services/dns_conversion_instruction_provider.dart';

typedef DnsClipboardWriter = Future<void> Function(String text);

class DnsArchiveImportPage extends StatefulWidget {
  const DnsArchiveImportPage({
    super.key,
    this.container,
    this.fileGateway,
    this.clipboardWriter,
    this.clock,
  });

  final AppRepositoryContainer? container;
  final BackupFileGateway? fileGateway;
  final DnsClipboardWriter? clipboardWriter;
  final DateTime Function()? clock;

  @override
  State<DnsArchiveImportPage> createState() => _DnsArchiveImportPageState();
}

class _DnsArchiveImportPageState extends State<DnsArchiveImportPage> {
  static const _maxInputBytes = 5 * 1024 * 1024;
  final _normalizedController = TextEditingController();
  late final AppRepositoryContainer _container;
  late final BackupFileGateway _fileGateway;
  late final DnsClipboardWriter _clipboardWriter;
  DnsConversionPreview? _preview;
  List<LegacyDailySummaryRecord> _history = const [];
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _container = widget.container ?? AppRepositoryRegistry.container;
    _fileGateway = widget.fileGateway ?? BackupFileGateway.platform();
    _clipboardWriter =
        widget.clipboardWriter ??
        ((text) => Clipboard.setData(ClipboardData(text: text)));
    _loadHistory();
  }

  @override
  void dispose() {
    _normalizedController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _container.legacyDailySummaries.list();
      if (mounted) setState(() => _history = history.take(10).toList());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _copyInstruction() => _run(() async {
    await _clipboardWriter(const DnsConversionInstructionProvider().build());
    _message = 'CHATGPT PROMPT COPIED';
  });

  Future<void> _selectNormalized() => _run(() async {
    final selected = await _fileGateway.selectJson();
    if (selected == null) {
      _message = 'FILE SELECTION CANCELLED';
      return;
    }
    if (!selected.name.toLowerCase().endsWith('.json') ||
        selected.bytes.isEmpty ||
        selected.bytes.length > _maxInputBytes) {
      throw const FormatException(
        'A non-empty JSON file within the safe limit is required.',
      );
    }
    _normalizedController.text = utf8.decode(
      selected.bytes,
      allowMalformed: false,
    );
    _preview = null;
    _message = 'DNS NORMALIZED FILE LOADED';
  });

  Future<void> _validate() => _run(() async {
    final raw = _normalizedController.text;
    if (raw.trim().isEmpty || utf8.encode(raw).length > _maxInputBytes) {
      throw const FormatException(
        'Normalized response is empty or exceeds the safe limit.',
      );
    }
    final normalized = _container.dnsNormalizedCodec.decodeStandalone(raw);
    final preview = await _container.dnsArchiveConverter.previewNormalized(
      normalized,
    );
    _preview = preview;
    _message = 'DNS NORMALIZED RESPONSE VALIDATED';
  });

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || !preview.canApply) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT ARCHIVE'),
        content: Text('${preview.parsedCount}件のLegacy Daily Summaryを保存しますか？'),
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
      await _container.dnsArchiveConverter.apply(preview);
      _normalizedController.clear();
      _preview = null;
      _history = (await _container.legacyDailySummaries.list())
          .take(10)
          .toList();
      _message = 'COMPLETE · READ-BACK VERIFIED';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _error = error.toString().replaceFirst('FormatException: ', '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DNS ARCHIVE IMPORT')),
    body: ListView(
      key: const ValueKey('dns-archive-import-content'),
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(icon: Icons.help_outline, title: 'HOW TO USE'),
        AppSpacing.gapSM,
        OperationCard(
          child: const Text(
            '1. COPY CHATGPT PROMPT\n'
            '2. Paste the prompt into ChatGPT\n'
            '3. Paste the DNS Archive into ChatGPT\n'
            '4. Copy the returned JSON only\n'
            '5. Paste or select the response\n'
            '6. Validate and review\n'
            '7. Import\n\n'
            'Required source record: DNS Archive',
          ),
        ),
        AppSpacing.gapSM,
        _DnsActionButton(
          text: 'COPY CHATGPT PROMPT',
          icon: Icons.content_copy,
          onPressed: _busy ? null : _copyInstruction,
        ),
        AppSpacing.gapSM,
        const OperationCard(
          child: Text(
            'After the prompt, paste the formal DNS Archive into ChatGPT.',
          ),
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.fact_check_outlined,
          title: 'DNS NORMALIZED RESPONSE',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: OperationTextField(
            key: const ValueKey('dns-normalized-input'),
            controller: _normalizedController,
            label: 'PASTE RESPONSE JSON',
            hint: 'Strict normalized JSON only',
            maxLines: 8,
            onChanged: (_) => setState(() {
              _preview = null;
            }),
          ),
        ),
        AppSpacing.gapSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _selectNormalized,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('SELECT RESPONSE FILE'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _validate,
              icon: const Icon(Icons.verified_outlined),
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
          _DnsPreviewCard(preview: _preview!),
          if (_preview!.canApply) ...[
            AppSpacing.gapSM,
            OperationButton(
              text: 'IMPORT ARCHIVE',
              icon: Icons.save_alt,
              onPressed: _busy ? null : _apply,
            ),
          ],
        ],
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.history, title: 'ARCHIVE HISTORY'),
        AppSpacing.gapSM,
        OperationCard(
          child: _history.isEmpty
              ? const Text('NO ARCHIVE HISTORY')
              : Column(
                  children: [
                    for (final record in _history)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(record.localDate),
                        subtitle: Text(
                          '${record.sourcePackageId}\n${record.importedAt.toLocal()}',
                        ),
                      ),
                  ],
                ),
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _DnsPreviewCard extends StatelessWidget {
  const _DnsPreviewCard({required this.preview});
  final DnsConversionPreview preview;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Source Records  ${preview.sourceRecordCount}'),
        Text('Parsed  ${preview.parsedCount}'),
        Text('Warnings  ${preview.warningCount}'),
        Text('Blocking  ${preview.blockingCount}'),
        Text('CREATE  ${preview.createCount}'),
        Text('NO CHANGES  ${preview.noChangeCount}'),
        Text('CONFLICT  ${preview.conflictCount}'),
        Text('Date Range  ${preview.operationDateRange ?? '—'}'),
        if (preview.missingFieldSummary.isNotEmpty)
          Text(
            'Missing  ${preview.missingFieldSummary.entries.map((entry) => '${entry.key}:${entry.value}').join(', ')}',
          ),
        for (final warning in preview.warnings)
          Text('WARNING · ${warning.code.name} · ${warning.message}'),
        for (final issue in preview.blockingIssues)
          Text(
            'BLOCKED · $issue',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}

class _DnsActionButton extends StatelessWidget {
  const _DnsActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
    ),
  );
}
