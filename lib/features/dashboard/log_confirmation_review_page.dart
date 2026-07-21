import 'package:flutter/material.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/training_summary.dart';
import '../../core/services/daily_log_confirmation_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../morning/models/morning_fact.dart';

class LogConfirmationReviewPage extends StatefulWidget {
  const LogConfirmationReviewPage({
    super.key,
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
  });

  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary activity;
  final TrainingSummary? training;

  @override
  State<LogConfirmationReviewPage> createState() =>
      _LogConfirmationReviewPageState();
}

class _LogConfirmationReviewPageState extends State<LogConfirmationReviewPage> {
  bool _isConfirming = false;

  Future<void> _confirmLog() async {
    if (_isConfirming) {
      return;
    }

    setState(() => _isConfirming = true);

    try {
      await DailyLogConfirmationService.confirmToday();

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on StateError {
      if (!mounted) {
        return;
      }

      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Morningデータが必要です。')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログの確定に失敗しました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Review Today's Log")),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.fact_check_outlined,
                title: 'LOG REVIEW',
              ),
              AppSpacing.gapMD,
              Text(
                'Date: ${DateTime.now().toIso8601String().split('T').first}',
              ),
              Text('Morning: ${widget.morning == null ? 'Missing' : 'Recorded'}'),
              Text(
                'Food: ${widget.food?.mealCount ?? 0} meals, '
                '${widget.food?.calories.toStringAsFixed(0) ?? '0'} kcal, '
                'P ${widget.food?.protein.toStringAsFixed(1) ?? '0.0'} g, '
                '${widget.food?.hydrationMl.toStringAsFixed(0) ?? '0'} ml',
              ),
              Text(
                'Activity: ${widget.activity.isRecorded ? '${_formatSteps(widget.activity.steps)} steps' : 'Not recorded'}',
              ),
              Text(
                'Training: ${widget.training == null ? 'Not recorded' : widget.training!.completed ? 'Completed' : 'Not completed'}',
              ),
              AppSpacing.gapLG,
              const Text(
                '確定後は、この日の通常編集・削除ができなくなります。\n'
                '変更する場合は訂正処理が必要です。',
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
                text: _isConfirming ? 'Confirming...' : 'Confirm Log',
                onPressed: _isConfirming ? null : _confirmLog,
              ),
              TextButton(
                onPressed: _isConfirming ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSteps(int steps) => steps.toString().replaceAllMapped(
        RegExp(r'(?<!^)(?=(\d{3})+$)'),
        (_) => ',',
      );
}
