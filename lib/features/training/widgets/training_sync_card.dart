import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../core/services/daily_state_restore_service.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/pages/report_sync_exchange_page.dart';

class TrainingSyncCard extends StatelessWidget {
  const TrainingSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.sync,
        text: 'SYNC TRAINING',
        onPressed: appInitializationController.value.isReadOnly
            ? null
            : () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportSyncExchangePage(
                      exchangeType: ReportSyncExchangeType.training,
                    ),
                  ),
                );
                await DailyStateRestoreService.restore(force: true);
              },
      ),
    );
  }
}
