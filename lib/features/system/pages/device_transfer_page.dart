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
        const Text('アプリ全体の保存・復元・転送・整合性確認を行います。'),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.timeline_outlined,
          title: 'TRANSFER STEP',
        ),
        AppSpacing.gapSM,
        _DeviceTransferStageIndicator(controller: _stageController),
        AppSpacing.gapXL,
        OperationCard(
          child: Column(
            children: [
              _DestinationTile(
                icon: Icons.settings_backup_restore,
                title: 'BACKUP & RESTORE',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.backupRestore),
              ),
              const Divider(),
              _DestinationTile(
                icon: Icons.sync_alt,
                title: 'OPERATION SYNC',
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
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.historicalTrainingImport,
                ),
              ),
              const Divider(),
              _DestinationTile(
                icon: Icons.description_outlined,
                title: 'HISTORICAL DNS IMPORT',
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

class _DeviceTransferStageIndicator extends StatelessWidget {
  const _DeviceTransferStageIndicator({required this.controller});

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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
