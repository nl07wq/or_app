import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/state/app_initialization_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_gateway.dart';
import '../../operation_sync/models/operation_sync_history.dart';
import '../../operation_sync/models/operation_sync_issue.dart';
import '../../operation_sync/models/operation_sync_state.dart';
import '../../operation_sync/services/historical_dns_workflow.dart';
import '../../operation_sync/services/operation_sync_transfer_coordinator.dart';
import '../../operation_sync/services/historical_training_workflow.dart';
import '../../operation_sync/widgets/historical_dns_import_panel.dart';
import '../../operation_sync/widgets/historical_training_import_panel.dart';
import '../../repositories/app_repository_container.dart';
import 'device_transfer_page.dart';

class OperationSyncPage extends StatefulWidget {
  const OperationSyncPage({super.key, this.workflow, this.stageController});

  final OperationSyncWorkflow? workflow;
  final DeviceTransferStageController? stageController;

  @override
  State<OperationSyncPage> createState() => _OperationSyncPageState();
}

class _OperationSyncPageState extends State<OperationSyncPage> {
  OperationSyncWorkflow? _workflow;
  OperationSyncWorkspace? _workspace;
  OperationSyncSelection? _selection;
  String? _message;
  late final DeviceTransferStageController _stageController;
  late final bool _ownsStageController;
  bool _busy = false;

  bool get _productionAvailable =>
      kIsWeb &&
      appInitializationController.value.mode ==
          PersistenceMode.indexedDbReadWrite &&
      AppRepositoryRegistry.hasContainer;

  bool get _available => widget.workflow != null || _productionAvailable;

  @override
  void initState() {
    super.initState();
    _ownsStageController = widget.stageController == null;
    _stageController =
        widget.stageController ?? DeviceTransferStageController();
    if (_available) {
      _workflow =
          widget.workflow ?? OperationSyncTransferCoordinator.production();
      _load();
    }
  }

  @override
  void dispose() {
    if (_ownsStageController) _stageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final workspace = await _workflow!.load();
      if (mounted) {
        setState(() => _workspace = workspace);
      }
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    }
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _stageController.value = 'EXPORT';
      _message = null;
    });
    try {
      final result = await _workflow!.exportPackage();
      if (!mounted) return;
      setState(() {
        _message = result.delivery == BackupFileDelivery.cancelled
            ? 'TRANSFER EXPORT CANCELLED'
            : 'TRANSFER PACKAGE READY · ${result.package.manifest.recordCount} records';
      });
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stageController.value = null;
        });
      }
    }
  }

  Future<void> _selectPackage() async {
    setState(() {
      _busy = true;
      _stageController.value = 'VALIDATION';
      _message = null;
      _selection = null;
    });
    try {
      final selection = await _workflow!.selectAndPreview();
      if (selection == null || !mounted) return;
      final workspace = await _workflow!.load();
      if (!mounted) return;
      setState(() {
        _selection = selection;
        _workspace = workspace;
        _stageController.value = 'PREVIEW';
        _message = selection.preview.canApply
            ? 'PACKAGE VALIDATED · 適用前に内容を確認してください'
            : 'VALIDATION BLOCKED · 競合を解消してから再試行してください';
      });
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final selection = _selection;
    if (selection == null || !selection.preview.canApply) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          selection.isRecovery ? 'RESUME TRANSFER?' : 'APPLY TRANSFER?',
        ),
        content: Text(
          'この追加専用転送では${selection.preview.createCount}件の記録を作成し、'
          '${selection.preview.noChangeCount}件は変更しません。'
          'パッケージは整合性保護されていますが、暗号化されていません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(selection.isRecovery ? 'RESUME' : 'APPLY'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _stageController.value = 'APPLY';
      _message = 'APPLYING · この画面を閉じないでください';
    });
    try {
      await _workflow!.apply(selection);
      final workspace = await _workflow!.load();
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _selection = null;
        _stageController.value = 'COMPLETE';
        _message = 'READ-BACK VERIFIED · TRANSFER COMPLETE';
      });
    } catch (error) {
      final workspace = await _workflow!.load();
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _stageController.value = 'VERIFY';
        _message = _errorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _workspace?.state;
    final requiresRecovery = state?.requiresRecovery ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('OPERATION SYNC')),
      body: ListView(
        key: const ValueKey('operation-sync-content'),
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.devices_outlined,
            title: 'TRANSFER PACKAGE',
          ),
          AppSpacing.gapSM,
          const Text('整合済み端末間で、不足している対象Recordを非破壊で同期します。'),
          AppSpacing.gapMD,
          const OperationCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '転送ファイルには個人データが含まれ、暗号化されません。'
                    '明示的に保存または共有しない限り、ファイルはこのデバイス内に留まります。',
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.timeline_outlined,
            title: 'TRANSFER STEP',
          ),
          AppSpacing.gapSM,
          OperationSyncStageIndicator(controller: _stageController),
          AppSpacing.gapMD,
          if (requiresRecovery) _buildRecovery(state!),
          AppSpacing.gapMD,
          _SyncActionButton(
            key: const ValueKey('export-transfer-package'),
            text: 'EXPORT TRANSFER PACKAGE',
            icon: Icons.download_outlined,
            onPressed: _available && !_busy && !requiresRecovery
                ? _export
                : null,
          ),
          AppSpacing.gapMD,
          _SyncActionButton(
            key: const ValueKey('select-transfer-package'),
            text: requiresRecovery
                ? 'RESELECT PACKAGE TO RESUME'
                : 'SELECT TRANSFER PACKAGE',
            icon: Icons.upload_file_outlined,
            onPressed: _available && !_busy ? _selectPackage : null,
          ),
          if (!_available) ...[
            AppSpacing.gapMD,
            const Text(
              'Operation Syncのインポートとエクスポートは、永続ストレージを利用できる'
              'Web/PWAで使用できます。',
            ),
          ],
          if (_busy) ...[
            AppSpacing.gapMD,
            const Center(child: CircularProgressIndicator()),
          ],
          if (_selection != null) ...[
            AppSpacing.gapXL,
            _buildPreview(_selection!),
          ],
          if (_message != null) ...[
            AppSpacing.gapMD,
            SelectableText(_message!),
          ],
          AppSpacing.gapXL,
          _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildRecovery(OperationSyncState state) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'RECOVERY REQUIRED',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        AppSpacing.gapSM,
        Text('Phase: ${state.phase.stableId}'),
        Text('Operation: ${state.operationId ?? 'unavailable'}'),
        Text('Package digest: ${_shortDigest(state.packageDigest)}'),
        Text(
          'Checkpoint: ${state.checkpoint?.verificationStatus ?? 'unavailable'}',
        ),
        AppSpacing.gapSM,
        const Text(
          '同一の転送パッケージを再選択してください。処理を再開するには、'
          'ダイジェストがロック済みチェックポイントと一致する必要があります。',
        ),
      ],
    ),
  );

  Widget _buildPreview(OperationSyncSelection selection) {
    final preview = selection.preview;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PREVIEW', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSM,
          Text('File: ${selection.fileName} (${selection.fileSize} bytes)'),
          Text('Package: ${preview.packageId}'),
          Text('Schema: ${preview.schemaVersion}'),
          Text(
            'Operation Date: ${selection.package.manifest.sourceOperationDate}',
          ),
          Text('Digest: ${_shortDigest(preview.packageDigest)}'),
          AppSpacing.gapSM,
          Text('Modules: ${preview.moduleCount}'),
          Text('Records: ${preview.recordCount}'),
          Text('CREATE: ${preview.createCount}'),
          Text('NO CHANGES: ${preview.noChangeCount}'),
          Text('CONFLICT: ${preview.conflictCount}'),
          if (preview.issues.isNotEmpty) ...[
            AppSpacing.gapMD,
            for (final issue in preview.issues) _IssueRow(issue: issue),
          ],
          AppSpacing.gapMD,
          _SyncActionButton(
            key: const ValueKey('apply-transfer-package'),
            text: selection.isRecovery ? 'RESUME TRANSFER' : 'APPLY TRANSFER',
            icon: Icons.verified_outlined,
            onPressed: !_busy && preview.canApply ? _apply : null,
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() => _OperationSyncRecordSection(
    title: 'OPERATION SYNC RECORD',
    archiveKey: const ValueKey('view-all-operation-sync-records'),
    records: <_OperationSyncRecordView>[
      for (final item in _workspace?.history ?? const <OperationSyncHistory>[])
        _OperationSyncRecordView.legacy(item),
    ],
  );

  static String _shortDigest(String? digest) {
    if (digest == null) return 'unavailable';
    return digest.length <= 16 ? digest : '${digest.substring(0, 16)}…';
  }

  static String _errorMessage(Object error) {
    if (error is OperationSyncException) {
      return '${error.code.stableId}: ${error.message}';
    }
    return 'OPERATION SYNC FAILED: $error';
  }
}

class HistoricalTrainingImportPage extends StatefulWidget {
  final HistoricalTrainingWorkflow? workflow;

  const HistoricalTrainingImportPage({super.key, this.workflow});

  @override
  State<HistoricalTrainingImportPage> createState() =>
      _HistoricalTrainingImportPageState();
}

class _HistoricalTrainingImportPageState
    extends State<HistoricalTrainingImportPage> {
  HistoricalTrainingWorkflow? _workflow;
  List<OperationSyncRecord> _records = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _workflow =
        widget.workflow ??
        (_historicalProductionAvailable
            ? HistoricalTrainingWorkflowService.production()
            : null);
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await _workflow?.listRecords() ?? const [];
      if (mounted) setState(() => _records = List.unmodifiable(records));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => _HistoricalImportScaffold(
    title: 'HISTORICAL TRAINING IMPORT',
    recordTitle: 'HISTORICAL TRAINING IMPORT RECORD',
    panel: HistoricalTrainingImportPanel(
      workflow: _workflow,
      onRecordSaved: _loadRecords,
    ),
    records: _records,
    error: _error,
  );
}

class HistoricalDnsImportPage extends StatefulWidget {
  final HistoricalDnsWorkflow? workflow;

  const HistoricalDnsImportPage({super.key, this.workflow});

  @override
  State<HistoricalDnsImportPage> createState() =>
      _HistoricalDnsImportPageState();
}

class _HistoricalDnsImportPageState extends State<HistoricalDnsImportPage> {
  HistoricalDnsWorkflow? _workflow;
  List<OperationSyncRecord> _records = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _workflow =
        widget.workflow ??
        (_historicalProductionAvailable
            ? HistoricalDnsWorkflowService.production()
            : null);
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await _workflow?.listRecords() ?? const [];
      if (mounted) setState(() => _records = List.unmodifiable(records));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => _HistoricalImportScaffold(
    title: 'HISTORICAL DNS IMPORT',
    recordTitle: 'HISTORICAL DNS IMPORT RECORD',
    panel: HistoricalDnsImportPanel(
      workflow: _workflow,
      onRecordSaved: _loadRecords,
    ),
    records: _records,
    error: _error,
  );
}

class _HistoricalImportScaffold extends StatelessWidget {
  final String title;
  final String recordTitle;
  final Widget panel;
  final List<OperationSyncRecord> records;
  final String? error;

  const _HistoricalImportScaffold({
    required this.title,
    required this.recordTitle,
    required this.panel,
    required this.records,
    required this.error,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        panel,
        if (error != null) ...[AppSpacing.gapSM, SelectableText(error!)],
        AppSpacing.gapXL,
        _OperationSyncRecordSection(
          title: recordTitle,
          records: [
            for (final record in records)
              _OperationSyncRecordView.historical(record),
          ],
        ),
      ],
    ),
  );
}

class _OperationSyncRecordSection extends StatelessWidget {
  final String title;
  final Key? archiveKey;
  final List<_OperationSyncRecordView> records;

  const _OperationSyncRecordSection({
    required this.title,
    this.archiveKey,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...records]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final recent = sorted.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(icon: Icons.fact_check_outlined, title: title),
        AppSpacing.gapSM,
        OperationCard(
          child: sorted.isEmpty
              ? const Row(
                  children: [
                    Icon(Icons.fact_check_outlined),
                    SizedBox(width: 10),
                    Expanded(child: Text('RECORDはありません')),
                  ],
                )
              : Column(
                  children: [
                    for (var index = 0; index < recent.length; index++) ...[
                      _MixedRecordRow(
                        record: recent[index],
                        onTap: () => _openMixedOperationSyncRecord(
                          context,
                          recent[index],
                          title,
                        ),
                      ),
                      if (index != recent.length - 1) const Divider(),
                    ],
                  ],
                ),
        ),
        if (sorted.isNotEmpty) ...[
          AppSpacing.gapSM,
          _OperationSyncRecordArchiveButton(
            key: archiveKey,
            text: 'VIEW ALL RECORDS',
            icon: Icons.list_alt,
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => _MixedOperationSyncRecordArchivePage(
                  title: title,
                  records: sorted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

bool get _historicalProductionAvailable =>
    kIsWeb &&
    appInitializationController.value.mode ==
        PersistenceMode.indexedDbReadWrite &&
    AppRepositoryRegistry.hasContainer;

class _OperationSyncRecordArchiveButton extends StatelessWidget {
  const _OperationSyncRecordArchiveButton({
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
    height: 52,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
    ),
  );
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final OperationSyncIssue issue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          issue.level == OperationSyncIssueLevel.blocking
              ? Icons.error_outline
              : Icons.info_outline,
          color: issue.level == OperationSyncIssueLevel.blocking
              ? Theme.of(context).colorScheme.error
              : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${issue.code.stableId}'
            '${issue.module == null ? '' : ' · ${issue.module}'}'
            '${issue.recordId == null ? '' : ' · ${issue.recordId}'}\n'
            '${issue.message}',
          ),
        ),
      ],
    ),
  );
}

class _SyncActionButton extends StatelessWidget {
  const _SyncActionButton({
    super.key,
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

class _OperationSyncRecordView {
  final OperationSyncHistory? legacy;
  final OperationSyncRecord? historical;

  const _OperationSyncRecordView._({this.legacy, this.historical});
  factory _OperationSyncRecordView.legacy(OperationSyncHistory value) =>
      _OperationSyncRecordView._(legacy: value);
  factory _OperationSyncRecordView.historical(OperationSyncRecord value) =>
      _OperationSyncRecordView._(historical: value);

  String get operationId => legacy?.operationId ?? historical!.operationId;
  String get packageId => legacy?.packageId ?? historical!.exchangeId;
  String get sourceType => legacy?.sourceType ?? historical!.sourceMode;
  String get transferMode => legacy?.transferMode ?? historical!.importMode;
  String get modules {
    if (legacy != null) return legacy!.moduleIds.join(', ');
    return historical!.recordType == 'dailyAggregateV1'
        ? 'DAILY AGGREGATE V1'
        : 'TRAINING V2';
  }

  String get kind {
    if (legacy != null) return 'DEVICE TRANSFER';
    return historical!.workflowKind == 'historicalDns'
        ? 'HISTORICAL DNS'
        : 'HISTORICAL TRAINING';
  }

  int get recordCount => legacy?.recordCount ?? historical!.receivedCount;
  int get createCount => legacy?.createCount ?? historical!.newCount;
  int get noChangeCount => legacy?.noChangeCount ?? historical!.identicalCount;
  int get replacedCount => historical?.replacedCount ?? 0;
  int get conflictCount => legacy?.conflictCount ?? historical!.conflictCount;
  int get blockedCount => historical?.blockedCount ?? 0;
  int get invalidCount => historical?.invalidCount ?? 0;
  int get quarantineCount => legacy?.quarantineCount ?? 0;
  DateTime get completedAt => legacy?.completedAt ?? historical!.completedAt;
  String get result => legacy?.result.stableId ?? historical!.result.stableId;
  String? get failureCode =>
      legacy?.failureCode?.stableId ?? historical?.failureCode;
  String get resultSummary => legacy != null
      ? 'CREATE $createCount · NO CHANGES $noChangeCount · '
            'CONFLICT $conflictCount · QUARANTINE $quarantineCount'
      : 'CREATED $createCount · NO CHANGES $noChangeCount · '
            'REPLACED $replacedCount · BLOCKED $blockedCount · '
            'INVALID $invalidCount';
  IconData get icon {
    if (legacy?.result == OperationSyncHistoryResult.recoveryRequired) {
      return Icons.restore;
    }
    return result == 'success'
        ? Icons.check_circle_outline
        : Icons.error_outline;
  }
}

class _MixedRecordRow extends StatelessWidget {
  final _OperationSyncRecordView record;
  final VoidCallback onTap;
  const _MixedRecordRow({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(record.icon),
    title: Text(record.result.toUpperCase()),
    subtitle: Text(
      '${record.kind}\n'
      '${record.resultSummary}'
      '${record.failureCode == null ? '' : '\n${record.failureCode}'}',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
    isThreeLine: record.failureCode != null,
  );
}

void _openMixedOperationSyncRecord(
  BuildContext context,
  _OperationSyncRecordView record,
  String title,
) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          _MixedOperationSyncRecordPage(title: title, record: record),
    ),
  );
}

class _MixedOperationSyncRecordArchivePage extends StatelessWidget {
  final String title;
  final List<_OperationSyncRecordView> records;
  const _MixedOperationSyncRecordArchivePage({
    required this.title,
    required this.records,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView.separated(
      padding: AppSpacing.cardPadding,
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) => _MixedRecordRow(
        record: records[index],
        onTap: () =>
            _openMixedOperationSyncRecord(context, records[index], title),
      ),
    ),
  );
}

class _MixedOperationSyncRecordPage extends StatelessWidget {
  final String title;
  final _OperationSyncRecordView record;
  const _MixedOperationSyncRecordPage({
    required this.title,
    required this.record,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(record.icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.result.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMD,
              _OperationSyncRecordField(label: 'WORKFLOW', value: record.kind),
              _OperationSyncRecordField(
                label: 'OPERATION ID',
                value: record.operationId,
              ),
              _OperationSyncRecordField(
                label: 'EXCHANGE / PACKAGE ID',
                value: record.packageId,
              ),
              _OperationSyncRecordField(
                label: 'SOURCE MODE',
                value: record.sourceType,
              ),
              _OperationSyncRecordField(
                label: 'IMPORT / TRANSFER MODE',
                value: record.transferMode,
              ),
              _OperationSyncRecordField(
                label: 'RECORD TYPE / MODULES',
                value: record.modules,
              ),
              _OperationSyncRecordField(
                label: 'RECORDS',
                value: '${record.recordCount}',
              ),
              _OperationSyncRecordField(
                label: 'RESULT COUNTS',
                value: record.resultSummary,
              ),
              _OperationSyncRecordField(
                label: 'COMPLETED AT',
                value: record.completedAt.toLocal().toString(),
              ),
              if (record.failureCode != null)
                _OperationSyncRecordField(
                  label: 'FAILURE CODE',
                  value: record.failureCode!,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OperationSyncRecordField extends StatelessWidget {
  const _OperationSyncRecordField({required this.label, required this.value});

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
