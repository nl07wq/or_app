import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SETTINGS')),
    body: ListView(
      key: const ValueKey('settings-content'),
      padding: AppSpacing.cardPadding,
      children: const [
        SectionHeader(icon: Icons.settings_outlined, title: 'SETTINGS'),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            children: [
              _SettingsValue(label: 'Appearance', value: 'System default'),
              Divider(),
              _SettingsValue(label: 'Theme', value: 'Dark'),
              Divider(),
              _SettingsValue(label: 'Version', value: '1.0.0'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsValue extends StatelessWidget {
  const _SettingsValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
  );
}
