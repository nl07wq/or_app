import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class SystemPage extends StatelessWidget {
  const SystemPage({super.key});

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
        const _SystemSection(
          icon: Icons.upload_file_outlined,
          title: 'EXPORT',
          description: 'Export Operation Reboot data.',
          buttonText: 'COMING LATER',
        ),
        AppSpacing.gapXL,
        const _SystemSection(
          icon: Icons.download_outlined,
          title: 'IMPORT',
          description: 'Import Operation Reboot data.',
          buttonText: 'COMING LATER',
        ),
        AppSpacing.gapXL,
        const _SystemSection(
          icon: Icons.monitor_heart_outlined,
          title: 'DIAGNOSTICS',
          description: 'System diagnostics.',
          buttonText: 'COMING LATER',
        ),
      ],
    ),
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
            _SystemActionButton(
              text: buttonText,
              icon: onPressed == null ? Icons.schedule_outlined : icon,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    ],
  );
}

class _SystemActionButton extends StatelessWidget {
  const _SystemActionButton({
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
