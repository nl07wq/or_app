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
import '../../operation_sync/services/operation_sync_transfer_coordinator.dart';
import '../../repositories/app_repository_container.dart';

class OperationSyncPage extends StatefulWidget {
  const OperationSyncPage({super.key, this.workflow});

  static const modules = [
    'STATUS',
    'ACTIVITY',
    'TRAINING',
    'FOOD',
    'CONFIRMATION',
    'ARCHIVE',
  ];

  final OperationSyncWorkflow? workflow;

  @override
  State<OperationSyncPage> createState() => _OperationSyncPageState();
}

class _OperationSyncPageState extends State<OperationSyncPage> {
  OperationSyncWorkflow? _workflow;
  OperationSyncWorkspace? _workspace;
  OperationSyncSelection? _selection;
  String? _message;
  String? _activeStage;
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
    if (_available) {
      _workflow =
          widget.workflow ?? OperationSyncTransferCoordinator.production();
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final workspace = await _workflow!.load();
      if (mounted) setState(() => _workspace = workspace);
    } catch (error) {
      if (mounted) setState(() => _message = _errorMessage(error));
    }
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _activeStage = 'EXPORT';
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
          _activeStage = null;
        });
      }
    }
  }

  Future<void> _selectPackage() async {
    setState(() {
      _busy = true;
      _activeStage = 'VALIDATION';
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
        _activeStage = 'PREVIEW';
        _message = selection.preview.canApply
            ? 'PACKAGE VALIDATED · review before apply'
            : 'VALIDATION BLOCKED · resolve conflicts before retry';
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
          'This merge-create-only transfer will create '
          '${selection.preview.createCount} records and keep '
          '${selection.preview.noChangeCount} unchanged. The package is '
          'integrity-protected but not encrypted.',
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
      _activeStage = 'APPLY';
      _message = 'APPLYING · do not close this page';
    });
    try {
      await _workflow!.apply(selection);
      final workspace = await _workflow!.load();
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _selection = null;
        _activeStage = 'COMPLETE';
        _message = 'READ-BACK VERIFIED · TRANSFER COMPLETE';
      });
    } catch (error) {
      final workspace = await _workflow!.load();
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _activeStage = 'VERIFY';
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
          const SectionHeader(icon: Icons.sync_alt, title: 'OPERATION SYNC'),
          AppSpacing.gapSM,
          const Text('Transfer data between devices with a verified package.'),
          AppSpacing.gapMD,
          const OperationCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Transfer files contain personal data and are not '
                    'encrypted. Files stay on this device unless you '
                    'explicitly save or share them.',
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapMD,
          _buildStages(),
          AppSpacing.gapMD,
          _buildModules(),
          if (requiresRecovery) ...[AppSpacing.gapMD, _buildRecovery(state!)],
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
              'Operation Sync import and export are available on Web/PWA '
              'with persistent storage.',
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

  Widget _buildStages() {
    const stages = [
      'SELECT TRANSFER PACKAGE',
      'VALIDATION',
      'PREVIEW',
      'APPLY',
      'VERIFY',
      'COMPLETE',
    ];
    return OperationCard(
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final stage in stages)
            Chip(
              avatar: Icon(
                stage == _activeStage
                    ? Icons.radio_button_checked
                    : Icons.circle_outlined,
                size: 18,
              ),
              label: Text(stage),
            ),
        ],
      ),
    );
  }

  Widget _buildModules() => OperationCard(
    child: Column(
      children: [
        for (final module in OperationSyncPage.modules)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              module == 'ARCHIVE'
                  ? Icons.schedule_outlined
                  : Icons.check_circle_outline,
            ),
            title: Text(module),
            trailing: Text(module == 'ARCHIVE' ? 'COMING LATER' : 'AVAILABLE'),
          ),
      ],
    ),
  );

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
          'Reselect the exact same transfer package. Its digest must match '
          'the locked checkpoint before the operation can resume.',
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

  Widget _buildHistory() {
    final history = _workspace?.history ?? const <OperationSyncHistory>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.history,
          title: 'OPERATION SYNC HISTORY',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: history.isEmpty
              ? const Text('NO OPERATION SYNC HISTORY')
              : Column(
                  children: [
                    for (var index = 0; index < history.length; index++) ...[
                      _HistoryRow(history: history[index]),
                      if (index != history.length - 1) const Divider(),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.history});

  final OperationSyncHistory history;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(switch (history.result) {
      OperationSyncHistoryResult.success => Icons.check_circle_outline,
      OperationSyncHistoryResult.failed => Icons.error_outline,
      OperationSyncHistoryResult.recoveryRequired => Icons.restore,
    }),
    title: Text(history.result.stableId.toUpperCase()),
    subtitle: Text(
      '${history.moduleIds.join(', ')}\n'
      'CREATE ${history.createCount} · NO CHANGES ${history.noChangeCount} · '
      'CONFLICT ${history.conflictCount}'
      '${history.failureCode == null ? '' : '\n${history.failureCode!.stableId}'}',
    ),
    isThreeLine: history.failureCode != null,
  );
}
