import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class DeviceTransferStageController extends ValueNotifier<String?> {
  DeviceTransferStageController() : super(null);
}

class DeviceTransferPage extends StatefulWidget {
  const DeviceTransferPage({super.key, this.stageController});

  final DeviceTransferStageController? stageController;

  @override
  State<DeviceTransferPage> createState() => _DeviceTransferPageState();
}

class _DeviceTransferPageState extends State<DeviceTransferPage> {
  late final DeviceTransferStageController _stageController;
  late final bool _ownsStageController;

  @override
  void initState() {
    super.initState();
    _ownsStageController = widget.stageController == null;
    _stageController =
        widget.stageController ?? DeviceTransferStageController();
  }

  @override
  void dispose() {
    if (_ownsStageController) _stageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DEVICE TRANSFER')),
    body: ListView(
      key: const ValueKey('device-transfer-content'),
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.devices_outlined,
          title: 'DEVICE TRANSFER',
        ),
        AppSpacing.gapSM,
        const Text('端末移行・復旧・Record同期・過去記録取込の各機能を選択します。'),
        AppSpacing.gapXL,
        OperationCard(
          child: Column(
            children: [
              _DestinationTile(
                icon: Icons.settings_backup_restore,
                title: 'BACKUP & RESTORE',
                subtitle: '全正式Dataを保存・復元し、完全な端末移行や障害復旧に使用します。',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.backupRestore),
              ),
              const Divider(),
              _DestinationTile(
                icon: Icons.sync_alt,
                title: 'OPERATION SYNC',
                subtitle: '整合済み端末間で、不足している対象Recordを非破壊で同期します。',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.operationSync,
                  arguments: _stageController,
                ),
              ),
              const Divider(),
              _DestinationTile(
                icon: Icons.monitor_heart_outlined,
                title: 'SYSTEM MONITORING',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.systemMonitoring),
              ),
              const Divider(),
              _DestinationTile(
                icon: Icons.fitness_center_outlined,
                title: 'HISTORICAL TRAINING IMPORT',
                subtitle: '通常OPERATION SYNCとは別に、過去のTraining Recordを取り込みます。',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.historicalTrainingImport,
                ),
              ),
              const Divider(),
              _DestinationTile(
                icon: Icons.description_outlined,
                title: 'HISTORICAL DNS IMPORT',
                subtitle: '通常OPERATION SYNCとは別に、過去のLegacy DNSを取り込みます。',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.historicalDnsImport),
              ),
            ],
          ),
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class OperationSyncStageIndicator extends StatelessWidget {
  const OperationSyncStageIndicator({super.key, required this.controller});

  static const stages = [
    'SELECT TRANSFER PACKAGE',
    'VALIDATION',
    'PREVIEW',
    'APPLY',
    'VERIFY',
    'COMPLETE',
  ];

  final DeviceTransferStageController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: controller,
    builder: (context, activeStage, _) => OperationCard(
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final stage in stages)
            Chip(
              avatar: Icon(
                stage == activeStage
                    ? Icons.radio_button_checked
                    : Icons.circle_outlined,
                size: 18,
              ),
              label: Text(stage),
            ),
        ],
      ),
    ),
  );
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
