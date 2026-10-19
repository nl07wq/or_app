import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../core/services/daily_state_restore_service.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/pages/report_sync_exchange_page.dart';
import 'training_dot_matrix_title.dart';
import 'training_led_back_button.dart';
import 'training_kinetic_scaffold.dart';

class TrainingSyncCard extends StatelessWidget {
  const TrainingSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.sync,
      text: 'SYNC TRAINING',
      frostedGlass: true,
      safeGlassTransparencyFactor: .70,
      onPressed: appInitializationController.value.isReadOnly
          ? null
          : () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportSyncExchangePage(
                    exchangeType: ReportSyncExchangeType.training,
                    appBarTitle: TrainingDotMatrixTitle(
                      title: 'TRAINING REPORT SYNC',
                    ),
                    appBarLeading: TrainingLedBackButton(),
                    scaffoldBuilder: ({appBar, required body}) =>
                        TrainingKineticScaffold(appBar: appBar, body: body),
                  ),
                ),
              );
              await DailyStateRestoreService.restore(force: true);
            },
    );
  }
}
