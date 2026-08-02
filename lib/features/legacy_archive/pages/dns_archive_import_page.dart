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
  final _sourceController = TextEditingController();
  final _normalizedController = TextEditingController();
  late final AppRepositoryContainer _container;
  late final BackupFileGateway _fileGateway;
  late final DnsClipboardWriter _clipboardWriter;
  late final DateTime Function() _clock;
  DnsSourcePackage? _source;
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
    _clock = widget.clock ?? DateTime.now;
    _loadHistory();
  }

  @override
  void dispose() {
    _sourceController.dispose();
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

  Future<void> _generateSource() => _run(() async {
    final text = _sourceController.text;
    if (text.trim().isEmpty || utf8.encode(text).length > _maxInputBytes) {
      throw const FormatException(
        'DNS source is empty or exceeds the safe limit.',
      );
    }
    final now = _clock().toUtc();
    final packageId = 'dns-${now.microsecondsSinceEpoch}';
    _source = _container.dnsSourceCodec.splitConcatenated(
      sourcePackageId: packageId,
      text: text,
      createdAt: now,
    );
    _preview = null;
    _message = 'DNS SOURCE JSON READY';
  });

  Future<void> _copyInstruction() => _run(() async {
    await _clipboardWriter(const DnsConversionInstructionProvider().build());
    _message = 'DNS CONVERSION INSTRUCTION COPIED';
  });

  Future<void> _copySource() => _run(() async {
    await _clipboardWriter(_container.dnsSourceCodec.encode(_source!));
    _message = 'DNS SOURCE JSON COPIED';
  });

  Future<void> _exportSource() => _run(() async {
    final source = _source!;
    final result = await _fileGateway.shareOrSave(
      fileName: 'dns-source-${source.sourcePackageId}.json',
      content: _container.dnsSourceCodec.encode(source),
    );
    _message = result == BackupFileDelivery.cancelled
        ? 'EXPORT CANCELLED'
        : 'DNS SOURCE FILE EXPORTED';
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
    final source = _source;
    if (source == null) throw StateError('DNS Source must be generated first.');
    final raw = _normalizedController.text;
    if (raw.trim().isEmpty || utf8.encode(raw).length > _maxInputBytes) {
      throw const FormatException(
        'Normalized response is empty or exceeds the safe limit.',
      );
    }
    final normalized = _container.dnsNormalizedCodec.decode(raw);
    final preview = await _container.dnsPreview.build(source, normalized);
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
      _sourceController.clear();
      _normalizedController.clear();
      _source = null;
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
        const SectionHeader(icon: Icons.archive_outlined, title: 'DNS SOURCE'),
        AppSpacing.gapSM,
        OperationCard(
          child: OperationTextField(
            key: const ValueKey('dns-source-input'),
            controller: _sourceController,
            label: 'DNS CONCATENATED PLAIN TEXT',
            hint: 'DNS-YYYY-MM-DD boundary required',
            maxLines: 10,
            onChanged: (_) => setState(() {
              _source = null;
              _preview = null;
            }),
          ),
        ),
        AppSpacing.gapSM,
        _DnsActionButton(
          text: 'GENERATE DNS SOURCE JSON',
          icon: Icons.transform,
          onPressed: _busy ? null : _generateSource,
        ),
        if (_source != null) ...[
          AppSpacing.gapSM,
          OperationCard(
            child: Text(
              'Source Package  ${_source!.sourcePackageId}\n'
              'Source Records  ${_source!.records.length}',
            ),
          ),
          AppSpacing.gapSM,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _copyInstruction,
                icon: const Icon(Icons.content_copy),
                label: const Text('COPY DNS CONVERSION INSTRUCTION'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _copySource,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('COPY DNS SOURCE JSON'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _exportSource,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('EXPORT DNS SOURCE FILE'),
              ),
            ],
          ),
        ],
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
            label: 'PASTE DNS NORMALIZED JSON',
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
              onPressed: _source == null || _busy ? null : _selectNormalized,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('SELECT DNS NORMALIZED FILE'),
            ),
            OutlinedButton.icon(
              onPressed: _source == null || _busy ? null : _validate,
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
