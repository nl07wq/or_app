import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/pages/report_sync_exchange_page.dart';

class FoodSyncCard extends StatelessWidget {
  const FoodSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('FOOD REPORT SYNC'),
          const SizedBox(height: 12),
          OperationButton(
            icon: Icons.sync,
            text: 'SYNC FOOD',
            onPressed: appInitializationController.value.isReadOnly
                ? null
                : () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportSyncExchangePage(
                          exchangeType: ReportSyncExchangeType.food,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}
