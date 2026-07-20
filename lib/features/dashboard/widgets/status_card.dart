import 'package:flutter/material.dart';

import '../../../core/engine/operation_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class StatusCard extends StatelessWidget {
  final bool isReady;
  final OperationStatus? status;

  const StatusCard({
    super.key,
    required this.isReady,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.shield_outlined,
            title: 'OPERATION STATUS',
          ),
          AppSpacing.gapSM,
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(isReady ? 'READY' : 'STANDBY')),
              Text(
                status?.name.toUpperCase() ?? '--',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
