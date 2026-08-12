import 'package:flutter/material.dart';

import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/services/daily_log_confirmation_validation.dart';
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
    this.onStatusTap,
    this.onFoodTap,
    this.onTrainingTap,
    this.onActivityTap,
  });

  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final ActivitySummary activitySummary;
  final TrainingSummary? trainingSummary;
  final VoidCallback? onReview;
  final VoidCallback? onStatusTap;
  final VoidCallback? onFoodTap;
  final VoidCallback? onTrainingTap;
  final VoidCallback? onActivityTap;

  @override
  Widget build(BuildContext context) {
    final validation = DailyLogConfirmationValidation.validate(
      morning: morningFact,
      food: foodSummary,
      activity: activitySummary,
      training: trainingSummary,
    );
    final statusState = validation.statusValid
        ? _DailyLogEntryState.completed
        : _DailyLogEntryState.requiredInvalid;
    final foodState = validation.foodValid
        ? _DailyLogEntryState.completed
        : _DailyLogEntryState.requiredInvalid;
    final activityState = validation.activityValid
        ? _DailyLogEntryState.completed
        : _DailyLogEntryState.requiredInvalid;
    final trainingState = !validation.trainingValid
        ? _DailyLogEntryState.requiredInvalid
        : validation.trainingRecorded
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
                      onTap: onStatusTap,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DailyLogEntryStatus(
                      label: 'FOOD',
                      state: foodState,
                      onTap: onFoodTap,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DailyLogEntryStatus(
                      label: 'TRAINING',
                      state: trainingState,
                      onTap: onTrainingTap,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DailyLogEntryStatus(
                      label: 'ACTIVITY',
                      state: activityState,
                      onTap: onActivityTap,
                    ),
                  ),
                ],
              );
            },
          ),
          AppSpacing.gapMD,
          _FinalizeReadiness(validation: validation),
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

enum _DailyLogEntryState { completed, requiredInvalid, optionalMissing }

class _DailyLogEntryStatus extends StatelessWidget {
  const _DailyLogEntryStatus({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _DailyLogEntryState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color, semanticsState) = switch (state) {
      _DailyLogEntryState.completed => (
        Icons.check_circle_outline,
        colorScheme.primary,
        'completed',
      ),
      _DailyLogEntryState.requiredInvalid => (
        Icons.error_outline,
        colorScheme.error,
        'incomplete',
      ),
      _DailyLogEntryState.optionalMissing => (
        Icons.circle_outlined,
        colorScheme.onSurfaceVariant,
        'not recorded optional',
      ),
    };

    return Semantics(
      label: '$label $semanticsState',
      container: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Icon(icon, color: color, size: 24),
                  AppSpacing.gapXS,
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinalizeReadiness extends StatelessWidget {
  const _FinalizeReadiness({required this.validation});

  final DailyLogValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final ready = validation.canFinalize;
    final colorScheme = Theme.of(context).colorScheme;
    final color = ready ? colorScheme.primary : colorScheme.error;
    final blockers = validation.blockingModules
        .map(DailyLogConfirmationValidation.moduleLabel)
        .join(', ');
    return Semantics(
      key: const ValueKey('dashboard-finalize-readiness'),
      label: ready ? 'FINALIZE READY' : 'FINALIZE BLOCKED $blockers',
      container: true,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ready ? Icons.check_circle_outline : Icons.error_outline,
              color: color,
            ),
            AppSpacing.gapSM,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'FINALIZE READY' : 'FINALIZE BLOCKED',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: color),
                  ),
                  if (!ready) Text(blockers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
