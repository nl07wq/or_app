import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../services/app_metadata.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ABOUT')),
    body: ListView(
      key: const ValueKey('about-content'),
      padding: AppSpacing.cardPadding,
      children: const [
        SectionHeader(icon: Icons.info_outline, title: 'ABOUT'),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            children: [
              _AboutValue(label: 'App Version', value: AppMetadata.appVersion),
              Divider(),
              _AboutValue(
                label: 'Operation Reboot Version',
                value: AppMetadata.operationRebootVersion,
              ),
              Divider(),
              _AboutValue(
                label: 'Database Version',
                value: AppMetadata.databaseVersion,
              ),
              Divider(),
              _AboutValue(
                label: 'Backup Schema Version',
                value: AppMetadata.backupSchemaVersion,
              ),
              Divider(),
              _AboutValue(
                label: 'Build Number',
                value: AppMetadata.buildNumber,
              ),
              Divider(),
              _AboutValue(label: 'Copyright', value: AppMetadata.copyright),
              Divider(),
              _AboutValue(label: 'License', value: AppMetadata.license),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AboutValue extends StatelessWidget {
  const _AboutValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
  );
}
