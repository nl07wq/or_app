import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class OperationCard extends StatelessWidget {
  final Widget child;

  const OperationCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 6,
      margin: AppSpacing.cardMargin,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
      child: Padding(padding: AppSpacing.cardPadding, child: child),
    );
  }
}
