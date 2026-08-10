import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class DataCenterHistoryPage extends StatelessWidget {
  const DataCenterHistoryPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HISTORY')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(icon: Icons.history, title: 'HISTORY'),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BODY HISTORY',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              AppSpacing.gapSM,
              const Text('保存済みの正式データから、体重と体脂肪率の履歴を表示します。'),
              AppSpacing.gapMD,
              OperationButton(
                text: 'OPEN BODY HISTORY',
                icon: Icons.monitor_weight_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.bodyHistory),
              ),
            ],
          ),
        ),
        AppSpacing.gapMD,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NUTRITION HISTORY',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              AppSpacing.gapSM,
              const Text('保存済みの正式データから、摂取・推定消費・カロリー収支の履歴を表示します。'),
              AppSpacing.gapMD,
              OperationButton(
                text: 'OPEN NUTRITION HISTORY',
                icon: Icons.restaurant_outlined,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.nutritionHistory),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
