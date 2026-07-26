import 'package:flutter/material.dart';

import '../../core/models/daily_log_confirmation.dart';
import '../../core/repositories/daily_log_confirmation_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import 'widgets/daily_review_body.dart';

class LogConfirmationDetailPage extends StatefulWidget {
  const LogConfirmationDetailPage({super.key, required this.targetDate});

  final DateTime? targetDate;

  @override
  State<LogConfirmationDetailPage> createState() =>
      _LogConfirmationDetailPageState();
}

class _LogConfirmationDetailPageState extends State<LogConfirmationDetailPage> {
  late final Future<DailyLogConfirmation?> _confirmation;

  @override
  void initState() {
    super.initState();
    _confirmation = widget.targetDate == null
        ? Future.value(null)
        : DailyLogConfirmationRepository.findByDate(widget.targetDate!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DAILY REVIEW')),
      body: FutureBuilder<DailyLogConfirmation?>(
        future: _confirmation,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load the confirmed daily review.'),
            );
          }

          final confirmation = snapshot.data;
          if (confirmation == null) {
            return const Center(
              child: Text('Confirmed daily review is not available.'),
            );
          }

          return ListView(
            padding: AppSpacing.cardPadding,
            children: [
              OperationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DailyReviewBody(
                      morning: confirmation.morning,
                      food: confirmation.food,
                      activity: confirmation.activity,
                      training: confirmation.training,
                      estimatedTotalBurnKcal:
                          confirmation.estimatedTotalBurnKcal,
                    ),
                    AppSpacing.gapLG,
                    Text(
                      'Confirmed at '
                      '${_formatDateTime(confirmation.confirmedAt)}',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
