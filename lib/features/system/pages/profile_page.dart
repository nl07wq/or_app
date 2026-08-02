import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PROFILE')),
    body: ListView(
      key: const ValueKey('profile-content'),
      padding: AppSpacing.cardPadding,
      children: const [
        SectionHeader(icon: Icons.person_outline, title: 'PROFILE'),
        AppSpacing.gapSM,
        OperationCard(
          child: _ProfileValue(label: 'User Name', value: 'Not configured'),
        ),
      ],
    ),
  );
}

class _ProfileValue extends StatelessWidget {
  const _ProfileValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value),
  );
}
