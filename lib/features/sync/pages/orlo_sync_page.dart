import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_gateway.dart';
import '../models/orlo_sync_models.dart';
import '../services/orlo_sync_gateway.dart';
import '../services/orlo_sync_instruction_provider.dart';
import '../services/orlo_sync_parser.dart';

typedef SyncFileSelector = Future<BackupSelectedFile?> Function();
typedef SyncClipboardWriter = Future<void> Function(String text);

class OrloSyncPage extends StatefulWidget {
  OrloSyncPage({
    super.key,
    OrloSyncGateway? gateway,
    SyncFileSelector? fileSelector,
    SyncClipboardWriter? clipboardWriter,
  }) : gateway = gateway ?? OrloSyncGateway(),
       fileSelector = fileSelector ?? BackupFileGateway.platform().selectJson,
       clipboardWriter =
           clipboardWriter ??
           ((text) => Clipboard.setData(ClipboardData(text: text)));

  final OrloSyncGateway gateway;
  final SyncFileSelector fileSelector;
  final SyncClipboardWriter clipboardWriter;

  @override
  State<OrloSyncPage> createState() => _OrloSyncPageState();
}

class _OrloSyncPageState extends State<OrloSyncPage> {
  final _controller = TextEditingController();
  SyncPreview? _preview;
  List<SyncIssue> _issues = const [];
  bool _busy = false;
  String? _stateMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    setState(() {
      _busy = true;
      _preview = null;
      _issues = const [];
      _stateMessage = null;
    });
    try {
      final preview = await widget.gateway.prepare(_controller.text);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _issues = preview.validation.issues;
      });
    } on OrloSyncValidationException catch (error) {
      if (mounted) setState(() => _issues = error.issues);
    } on OrloSyncParseException catch (error) {
      if (mounted) {
        setState(() {
          _issues = [
            SyncIssue(
              code: error.code,
              path: r'$',
              message: error.message,
              severity: SyncIssueSeverity.blockingError,
            ),
          ];
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectFile() async {
    try {
      final selected = await widget.fileSelector();
      if (selected == null || !mounted) return;
      _controller.text = utf8.decode(selected.bytes, allowMalformed: false);
      setState(() {
        _preview = null;
        _issues = const [];
        _stateMessage = 'File loaded. PARSEを実行してください。';
      });
    } catch (_) {
      if (mounted) setState(() => _stateMessage = 'Fileを読み込めませんでした。');
    }
  }

  Future<void> _copyInstruction() async {
    try {
      await widget.clipboardWriter(
        const OrloSyncInstructionProvider().buildCommonInstruction(),
      );
      if (mounted) setState(() => _stateMessage = 'Instructionをコピーしました。');
    } catch (_) {
      if (mounted) setState(() => _stateMessage = 'Instructionをコピーできませんでした。');
    }
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || !preview.canImport) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT'),
        content: Text('${preview.envelope.dataType}の内容を保存しますか？'),
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
      _stateMessage = null;
    });
    try {
      final result = await widget.gateway.apply(
        preview: preview,
        confirmedPayloadDigest: preview.payloadDigest,
      );
      if (!mounted) return;
      setState(() {
        _issues = result.issues;
        if (result.success) {
          _controller.clear();
          _preview = null;
          _stateMessage = 'ImportとRead-back Verificationが完了しました。';
        } else {
          _stateMessage = 'Importに失敗しました。';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _stateMessage = 'Importに失敗しました。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ORLO SYNC')),
    body: ListView(
      key: const ValueKey('orlo-sync-content'),
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(icon: Icons.sync, title: 'PASTE SYNC DATA'),
        AppSpacing.gapSM,
        OperationCard(
          child: OperationTextField(
            controller: _controller,
            label: 'Sync Data',
            hint: 'ORLO Sync JSONを貼り付けてください。',
            maxLines: 12,
            onChanged: (_) => setState(() {
              _preview = null;
              _issues = const [];
            }),
          ),
        ),
        AppSpacing.gapSM,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _selectFile,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('SELECT FILE'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _copyInstruction,
              icon: const Icon(Icons.content_copy),
              label: const Text('COPY CHATGPT INSTRUCTION'),
            ),
          ],
        ),
        AppSpacing.gapSM,
        OperationButton(
          text: 'PARSE',
          icon: Icons.manage_search,
          onPressed: _busy ? null : _parse,
        ),
        if (_busy) ...[
          AppSpacing.gapMD,
          const Center(child: CircularProgressIndicator()),
        ] else ...[
          if (_stateMessage != null) ...[
            AppSpacing.gapSM,
            Text(_stateMessage!),
          ],
          if (_issues.isNotEmpty) ...[
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.fact_check_outlined,
              title: 'VALIDATION',
            ),
            AppSpacing.gapSM,
            _IssueCard(issues: _issues),
          ],
          if (_preview != null) ...[
            AppSpacing.gapXL,
            const SectionHeader(icon: Icons.preview_outlined, title: 'PREVIEW'),
            AppSpacing.gapSM,
            _PreviewCard(preview: _preview!),
            if (_preview!.canImport) ...[
              AppSpacing.gapSM,
              OperationButton(
                text: 'IMPORT',
                icon: Icons.save_alt,
                onPressed: _apply,
              ),
            ],
          ],
        ],
      ],
    ),
  );
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issues});
  final List<SyncIssue> issues;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  issue.severity == SyncIssueSeverity.information
                      ? Icons.info_outline
                      : Icons.error_outline,
                  color: issue.severity == SyncIssueSeverity.information
                      ? null
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('${issue.path}  ${issue.message}')),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});
  final SyncPreview preview;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Type  ${preview.envelope.dataType}'),
        Text('Schema Version  ${preview.envelope.schemaVersion}'),
        Text('Package ID  ${preview.envelope.packageId}'),
        Text('Operation Date  ${preview.envelope.operationDate ?? '—'}'),
        Text('Source  ${preview.envelope.source.producer}'),
        Text('Records  ${preview.counts.records}'),
        Text('Create  ${preview.counts.create}'),
        Text('Update  ${preview.counts.update}'),
        Text('No-op  ${preview.counts.noOp}'),
        Text('Conflicts  ${preview.counts.conflict}'),
        Text('Warnings  ${preview.warningCount}'),
        Text('Blocking Errors  ${preview.blockingErrorCount}'),
        AppSpacing.gapSM,
        Text(preview.canImport ? 'Import ready.' : 'Importできません。'),
      ],
    ),
  );
}
