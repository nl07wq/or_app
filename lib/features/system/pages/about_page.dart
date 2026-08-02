import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

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
              _AboutValue(label: 'Version', value: '1.0.0'),
              Divider(),
              _AboutValue(label: 'Operation Reboot Version', value: '1.0.0'),
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
