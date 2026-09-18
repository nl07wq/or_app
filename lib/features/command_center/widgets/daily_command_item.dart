import 'package:flutter/material.dart';

import '../../../core/engine/operation_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/status_lamp.dart';

class DailyCommandItem extends StatelessWidget {
  const DailyCommandItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.status,
    this.showStatusLamp,
    this.onValueTap,
    this.valueKey,
  });

  final IconData icon;
  final String label;
  final String value;
  final OperationStatus? status;
  final bool? showStatusLamp;
  final VoidCallback? onValueTap;
  final Key? valueKey;

  static Color statusColor(OperationStatus? status) =>
      _statusLamp(status).color;

  @override
  Widget build(BuildContext context) {
    final lamp = _statusLamp(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
        AppSpacing.gapXS,
        _valueRow(context, lamp),
      ],
    );
  }

  Widget _valueRow(BuildContext context, _StatusLamp lamp) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showStatusLamp ?? status != null) ...[
          StatusLamp(
            key: ValueKey('daily-command-status-lamp-${lamp.name}'),
            color: lamp.color,
            illuminated: lamp.filled,
            semanticLabel: '${lamp.name} status lamp',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(child: Text(value)),
      ],
    );
    final onTap = onValueTap;
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label $value',
      hint: '判定理由を表示',
      child: GestureDetector(
        key: valueKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }

  static _StatusLamp _statusLamp(OperationStatus? status) => switch (status) {
    OperationStatus.green => const _StatusLamp(
      name: 'green',
      color: AppColors.success,
      filled: true,
    ),
    OperationStatus.yellow => const _StatusLamp(
      name: 'yellow',
      color: AppColors.operationStatusYellow,
      filled: true,
    ),
    OperationStatus.red => const _StatusLamp(
      name: 'red',
      color: AppColors.danger,
      filled: true,
    ),
    OperationStatus.black || null => const _StatusLamp(
      name: 'standby',
      color: AppColors.secondary,
      filled: false,
    ),
  };
}

class _StatusLamp {
  const _StatusLamp({
    required this.name,
    required this.color,
    required this.filled,
  });

  final String name;
  final Color color;
  final bool filled;
}
