import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../services/app_metadata.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    this.releaseMetadata = AppMetadata.releaseMetadata,
  });

  final ReleaseMetadata releaseMetadata;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ABOUT')),
    body: ListView(
      key: const ValueKey('about-content'),
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(icon: Icons.info_outline, title: 'ABOUT'),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            children: [
              const _AboutValue(
                label: 'App Version',
                value: AppMetadata.appVersion,
              ),
              const Divider(),
              const _AboutValue(
                label: 'Operation Reboot Version',
                value: AppMetadata.operationRebootVersion,
              ),
              const Divider(),
              const _AboutValue(
                label: 'Database Version',
                value: AppMetadata.databaseVersion,
              ),
              const Divider(),
              const _AboutValue(
                label: 'Backup Schema Version',
                value: AppMetadata.backupSchemaVersion,
              ),
              const Divider(),
              const _AboutValue(
                label: 'Build Number',
                value: AppMetadata.buildNumber,
              ),
              const Divider(),
              _AboutValue(
                label: 'Last Updated',
                value: releaseMetadata.lastUpdated,
              ),
              const Divider(),
              _AboutValue(
                label: 'Release Commit',
                value: releaseMetadata.releaseCommit,
              ),
              const Divider(),
              const _AboutValue(
                label: 'Copyright',
                value: AppMetadata.copyright,
              ),
              const Divider(),
              const _AboutValue(label: 'License', value: AppMetadata.license),
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
