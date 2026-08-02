import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../services/app_data_initialization_service.dart';

class SystemDataHealthSnapshot {
  const SystemDataHealthSnapshot({
    required this.integrity,
    required this.recoveryStatus,
    required this.healthStatus,
  });

  final String integrity;
  final String recoveryStatus;
  final String healthStatus;
}

class SystemPage extends StatefulWidget {
  const SystemPage({
    super.key,
    this.initializationService,
    this.dataHealthLoader,
  });

  final AppDataInitializationService? initializationService;
  final Future<SystemDataHealthSnapshot> Function()? dataHealthLoader;

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  late Future<SystemDataHealthSnapshot> _dataHealth;
  bool _initializing = false;
  String? _initializationResult;

  @override
  void initState() {
    super.initState();
    _dataHealth = _loadDataHealth();
  }

  Future<SystemDataHealthSnapshot> _loadDataHealth() async {
    final customLoader = widget.dataHealthLoader;
    if (customLoader != null) return customLoader();
    if (!AppRepositoryRegistry.hasContainer) {
      return const SystemDataHealthSnapshot(
        integrity: 'UNAVAILABLE',
        recoveryStatus: 'UNAVAILABLE',
        healthStatus: 'CHECK REQUIRED',
      );
    }
    try {
      final operationState = await AppRepositoryRegistry
          .container
          .operationState
          .findCurrent();
      final initialization = appInitializationController.value;
      final recoveryRequired =
          operationState?.requiresRecovery == true ||
          initialization.operationRecoveryRequired ||
          initialization.operationSyncRecoveryRequired;
      return SystemDataHealthSnapshot(
        integrity: operationState == null ? 'CHECK REQUIRED' : 'READABLE',
        recoveryStatus: recoveryRequired
            ? 'RECOVERY REQUIRED'
            : 'NO RECOVERY REQUIRED',
        healthStatus: operationState != null && !recoveryRequired
            ? 'HEALTHY'
            : 'ATTENTION',
      );
    } catch (_) {
      return const SystemDataHealthSnapshot(
        integrity: 'CHECK REQUIRED',
        recoveryStatus: 'UNKNOWN',
        healthStatus: 'ATTENTION',
      );
    }
  }

  Future<void> _requestInitialization() async {
    final confirmed = await _showInitializationDialog();
    if (confirmed != true || !mounted) return;
    setState(() {
      _initializing = true;
      _initializationResult = null;
    });
    try {
      final service =
          widget.initializationService ??
          AppDataInitializationService(
            AppRepositoryRegistry.container.database,
          );
      await service.initialize();
      appInitializationController.markReady();
      if (!mounted) return;
      setState(() {
        _initializationResult = 'APP DATA INITIALIZED';
        _dataHealth = _loadDataHealth();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializationResult = 'INITIALIZATION FAILED — NO DATA WAS CHANGED';
      });
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<bool?> _showInitializationDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _InitializationConfirmationDialog(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SYSTEM')),
    body: ListView(
      key: const ValueKey('system-content'),
      padding: AppSpacing.cardPadding,
      children: [
        _SystemSection(
          icon: Icons.sync_alt,
          title: 'OPERATION SYNC',
          description:
              'Transfer data between devices\n'
              'and import long-term archives.',
          buttonText: 'OPEN OPERATION SYNC',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.operationSync),
        ),
        AppSpacing.gapXL,
        const _StorageSection(),
        AppSpacing.gapXL,
        _DataHealthSection(snapshot: _dataHealth),
        AppSpacing.gapXL,
        _InitializeSection(
          busy: _initializing,
          result: _initializationResult,
          onPressed: appInitializationController.value.canWrite
              ? _requestInitialization
              : null,
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _InitializationConfirmationDialog extends StatefulWidget {
  const _InitializationConfirmationDialog();

  @override
  State<_InitializationConfirmationDialog> createState() =>
      _InitializationConfirmationDialogState();
}

class _InitializationConfirmationDialogState
    extends State<_InitializationConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('INITIALIZE APP DATA'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operation Rebootの運用データを初期化します。実行前に'
          'BACKUP & RESTOREからBackupを作成してください。',
        ),
        AppSpacing.gapMD,
        const Text('続行するには INITIALIZE と入力してください。'),
        AppSpacing.gapSM,
        TextField(
          key: const ValueKey('initialize-confirmation-input'),
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Confirmation'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('CANCEL'),
      ),
      FilledButton(
        key: const ValueKey('confirm-initialize-app-data'),
        onPressed: _controller.text == 'INITIALIZE'
            ? () => Navigator.pop(context, true)
            : null,
        child: const Text('INITIALIZE'),
      ),
    ],
  );
}

class _StorageSection extends StatelessWidget {
  const _StorageSection();

  @override
  Widget build(BuildContext context) => const _ReadOnlySection(
    icon: Icons.storage_outlined,
    title: 'STORAGE',
    values: [
      ('Database Size', 'Browser managed'),
      ('Last Backup', 'Not available'),
      ('Storage Usage', 'Browser managed'),
    ],
  );
}

class _DataHealthSection extends StatelessWidget {
  const _DataHealthSection({required this.snapshot});

  final Future<SystemDataHealthSnapshot> snapshot;

  @override
  Widget build(BuildContext context) => FutureBuilder<SystemDataHealthSnapshot>(
    future: snapshot,
    builder: (context, value) {
      final data = value.data;
      return _ReadOnlySection(
        icon: Icons.health_and_safety_outlined,
        title: 'DATA HEALTH',
        values: [
          ('Integrity', data?.integrity ?? 'CHECKING'),
          ('Recovery Status', data?.recoveryStatus ?? 'CHECKING'),
          ('Health Status', data?.healthStatus ?? 'CHECKING'),
        ],
      );
    },
  );
}

class _InitializeSection extends StatelessWidget {
  const _InitializeSection({
    required this.busy,
    required this.result,
    required this.onPressed,
  });

  final bool busy;
  final String? result;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.warning_amber_rounded,
        title: 'INITIALIZE APP DATA',
      ),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DANGER ZONE',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            AppSpacing.gapSM,
            const Text(
              'STATUS、ACTIVITY、TRAINING、FOODおよび運用履歴を初期化します。'
              'この操作は元に戻せません。',
            ),
            AppSpacing.gapMD,
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('initialize-app-data'),
                onPressed: busy ? null : onPressed,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(busy ? 'INITIALIZING' : 'INITIALIZE APP DATA'),
              ),
            ),
            if (result != null) ...[AppSpacing.gapSM, Text(result!)],
          ],
        ),
      ),
    ],
  );
}

class _ReadOnlySection extends StatelessWidget {
  const _ReadOnlySection({
    required this.icon,
    required this.title,
    required this.values,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(icon: icon, title: title),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          children: [
            for (var index = 0; index < values.length; index++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(values[index].$1),
                subtitle: Text(values[index].$2),
              ),
              if (index != values.length - 1) const Divider(),
            ],
          ],
        ),
      ),
    ],
  );
}

class _SystemSection extends StatelessWidget {
  const _SystemSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(icon: icon, title: title),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description),
            AppSpacing.gapMD,
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(buttonText),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
