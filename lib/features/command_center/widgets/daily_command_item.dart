import 'package:flutter/material.dart';

import '../../../core/engine/operation_status.dart';
import '../../../core/theme/app_spacing.dart';

class DailyCommandItem extends StatelessWidget {
  const DailyCommandItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.status,
  });

  final IconData icon;
  final String label;
  final String value;
  final OperationStatus? status;

  @override
  Widget build(BuildContext context) {
    final lampColor = _lampColor(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
          ],
        ),
        AppSpacing.gapXS,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lampColor != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.circle,
                  key: ValueKey('daily-command-status-lamp-${status!.name}'),
                  size: 18,
                  color: lampColor,
                  semanticLabel: '${status!.name} status lamp',
                ),
              ),
              SizedBox(width: AppSpacing.sm),
            ],
            Expanded(child: Text(value)),
          ],
        ),
      ],
    );
  }

  static Color? _lampColor(OperationStatus? status) => switch (status) {
    OperationStatus.green => Colors.green,
    OperationStatus.yellow => Colors.amber,
    OperationStatus.red => Colors.red,
    OperationStatus.black || null => null,
  };
}
