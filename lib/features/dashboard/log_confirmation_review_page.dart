import 'package:flutter/material.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/training_summary.dart';
import '../../core/services/daily_log_confirmation_service.dart';
import '../../core/services/daily_log_confirmation_validation.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../morning/models/morning_fact.dart';
import 'widgets/daily_review_body.dart';

class LogConfirmationReviewPage extends StatefulWidget {
  const LogConfirmationReviewPage({
    super.key,
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
    required this.estimatedTotalBurn,
  });

  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary activity;
  final TrainingSummary? training;
  final double? estimatedTotalBurn;

  @override
  State<LogConfirmationReviewPage> createState() =>
      _LogConfirmationReviewPageState();
}

class _LogConfirmationReviewPageState extends State<LogConfirmationReviewPage> {
  bool _isConfirming = false;

  DailyLogValidationResult get _validation =>
      DailyLogConfirmationValidation.validate(
        morning: widget.morning,
        food: widget.food,
        activity: widget.activity,
        training: widget.training,
      );

  Future<void> _confirmLog() async {
    if (_isConfirming || !_validation.canFinalize) {
      return;
    }

    setState(() => _isConfirming = true);

    try {
      await DailyLogConfirmationService.confirmToday(
        estimatedTotalBurnKcal: widget.estimatedTotalBurn,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on DailyLogValidationException catch (error) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      final labels = error.invalidModules
          .map(DailyLogConfirmationValidation.moduleLabel)
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete required records: $labels')),
      );
    } on StateError {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily Log data is not ready.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to finalize the daily log.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
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
                morning: widget.morning,
                food: widget.food,
                activity: widget.activity,
                training: widget.training,
                estimatedTotalBurnKcal: widget.estimatedTotalBurn,
              ),
              if (!validation.canFinalize) ...[
                AppSpacing.gapLG,
                Text(
                  'Complete required records: $invalidLabels',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              AppSpacing.gapLG,
              const Text(
                'Finalizing locks today’s normal edit and delete actions. '
                'Use the correction flow if changes are needed later.',
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OperationButton(
                icon: Icons.verified_outlined,
                text: _isConfirming ? 'FINALIZING...' : 'FINALIZE DAY',
                onPressed: _isConfirming || !validation.canFinalize
                    ? null
                    : _confirmLog,
              ),
              AppSpacing.gapXS,
              const Text(
                'Finalize today’s records',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: _isConfirming ? null : () => Navigator.pop(context),
                child: const Text('BACK TO EDIT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
