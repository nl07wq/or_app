import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../core/services/daily_state_restore_service.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/pages/report_sync_exchange_page.dart';
import '../../themes/base_camp/base_camp_presentation.dart';

class FoodSyncCard extends StatelessWidget {
  const FoodSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final baseCamp = BaseCampPresentation.isActive(context);
    return OperationCard(
      transparentSurface: !baseCamp,
      child: OperationButton(
        icon: Icons.sync,
        text: 'SYNC FOOD',
        frostedGradient: !baseCamp,
        onPressed: appInitializationController.value.isReadOnly
            ? null
            : () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportSyncExchangePage(
                      exchangeType: ReportSyncExchangeType.food,
                    ),
                  ),
                );
                await DailyStateRestoreService.restore(force: true);
              },
      ),
    );
  }
}
