import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/section_header.dart';

class DataCenterPage extends StatelessWidget {
  const DataCenterPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('data-center-content'),
    padding: AppSpacing.cardPadding,
    children: [
      const SectionHeader(icon: Icons.storage_outlined, title: 'DATA CENTER'),
      AppSpacing.gapSM,
      const Text('正式データの履歴と推移を確認します。'),
      AppSpacing.gapXL,
      const SectionHeader(icon: Icons.history, title: 'HISTORY'),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HISTORY', style: Theme.of(context).textTheme.titleMedium),
            AppSpacing.gapSM,
            const Text('保存済みの正式データから、各種履歴と推移を確認します。'),
            AppSpacing.gapMD,
            OperationButton(
              role: OperationActionRole.primary,
              text: 'OPEN HISTORY',
              icon: Icons.history,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.dataCenterHistory),
            ),
          ],
        ),
      ),
      AppSpacing.gapLG,
      const SectionHeader(
        icon: Icons.inventory_2_outlined,
        title: 'DAILY AGGREGATE RECORDS',
      ),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DAILY AGGREGATE RECORDS',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.gapSM,
            const Text('保存済みの日次圧縮RecordとSourceを確認・保守します。'),
            AppSpacing.gapMD,
            OperationButton(
              role: OperationActionRole.primary,
              text: 'OPEN DAILY AGGREGATE RECORDS',
              icon: Icons.inventory_2_outlined,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.dailyAggregateRecords),
            ),
          ],
        ),
      ),
      AppSpacing.gapLG,
    ],
  );
}
