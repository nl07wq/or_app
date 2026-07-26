import 'package:flutter/material.dart';

import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../morning/models/morning_fact.dart';

class DailyLogCard extends StatelessWidget {
  const DailyLogCard({
    super.key,
    required this.morningFact,
    required this.foodSummary,
    required this.activitySummary,
    required this.trainingSummary,
    required this.onReview,
  });

  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final ActivitySummary activitySummary;
  final TrainingSummary? trainingSummary;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final statusState = morningFact == null
        ? _DailyLogEntryState.requiredMissing
        : _DailyLogEntryState.completed;
    final foodState = (foodSummary?.mealCount ?? 0) > 0
        ? _DailyLogEntryState.completed
        : _DailyLogEntryState.optionalMissing;
    final activityState = !activitySummary.isRecorded
        ? _DailyLogEntryState.optionalMissing
        : activitySummary.status == ActivitySummaryStatus.confirmed
        ? _DailyLogEntryState.completed
        : _DailyLogEntryState.optionalIncomplete;
    final trainingState = trainingSummary?.completed == true
        ? _DailyLogEntryState.completed
        : _DailyLogEntryState.optionalMissing;

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 360;
              final itemWidth = useTwoColumns
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _DailyLogEntryStatus(
                      label: 'STATUS',
                      state: statusState,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DailyLogEntryStatus(
                      label: 'FOOD',
                      state: foodState,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DailyLogEntryStatus(
                      label: 'TRAINING',
                      state: trainingState,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DailyLogEntryStatus(
                      label: 'ACTIVITY',
                      state: activityState,
                    ),
                  ),
                ],
              );
            },
          ),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.fact_check_outlined,
            text: 'DAILY REVIEW',
            onPressed: onReview,
          ),
        ],
      ),
    );
  }
}

enum _DailyLogEntryState {
  completed,
  requiredMissing,
  optionalMissing,
  optionalIncomplete,
}

class _DailyLogEntryStatus extends StatelessWidget {
  const _DailyLogEntryStatus({required this.label, required this.state});

  final String label;
  final _DailyLogEntryState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color, semanticsState) = switch (state) {
      _DailyLogEntryState.completed => (
        Icons.check_circle_outline,
        colorScheme.primary,
        'completed',
      ),
      _DailyLogEntryState.requiredMissing => (
        Icons.error_outline,
        colorScheme.error,
        'incomplete',
      ),
      _DailyLogEntryState.optionalMissing => (
        Icons.circle_outlined,
        colorScheme.onSurfaceVariant,
        'not recorded optional',
      ),
      _DailyLogEntryState.optionalIncomplete => (
        Icons.pending_outlined,
        colorScheme.onSurfaceVariant,
        'recorded incomplete optional',
      ),
    };

    return Semantics(
      label: '$label $semanticsState',
      container: true,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Icon(icon, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
