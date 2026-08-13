import 'package:flutter/material.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/training_summary.dart';
import '../../core/services/daily_log_confirmation_validation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../morning/models/morning_fact.dart';
import 'widgets/daily_review_body.dart';

typedef ConfirmDailyLog = Future<void> Function(double? estimatedTotalBurnKcal);

class LogConfirmationReviewPage extends StatelessWidget {
  const LogConfirmationReviewPage({
    super.key,
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
    required this.estimatedTotalBurn,
    required this.targetDate,
    this.confirmDailyLog,
  });

  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary activity;
  final TrainingSummary? training;
  final double? estimatedTotalBurn;
  final DateTime targetDate;

  /// Retained for source compatibility with callers that construct the
  /// read-only review directly. DAILY REVIEW no longer prepares a close.
  final ConfirmDailyLog? confirmDailyLog;

  @override
  Widget build(BuildContext context) {
    final validation = DailyLogConfirmationValidation.validate(
      morning: morning,
      food: food,
      activity: activity,
      training: training,
    );
    final invalidLabels = validation.blockingModules
        .map(DailyLogConfirmationValidation.moduleLabel)
        .join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('DAILY REVIEW')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DailyReviewBody(
                morning: morning,
                food: food,
                activity: activity,
                training: training,
                estimatedTotalBurnKcal: estimatedTotalBurn,
              ),
              if (!validation.canFinalize) ...[
                AppSpacing.gapLG,
                Text(
                  '必須記録を完了してください: $invalidLabels',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
