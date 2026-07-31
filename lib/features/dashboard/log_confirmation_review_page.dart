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
import '../import_export/services/backup_file_export_service.dart';
import '../operation_date/models/operation_local_date.dart';
import '../operation_date/models/daily_finalize_result.dart';
import '../operation_date/services/daily_finalize_coordinator_factory.dart';
import 'widgets/backup_prompt_dialog.dart';
import 'widgets/daily_review_body.dart';

typedef ConfirmDailyLog = Future<void> Function(double? estimatedTotalBurnKcal);

class LogConfirmationReviewPage extends StatefulWidget {
  const LogConfirmationReviewPage({
    super.key,
    required this.morning,
    required this.food,
    required this.activity,
    required this.training,
    required this.estimatedTotalBurn,
    required this.targetDate,
    this.backupExportService,
    this.confirmDailyLog,
  });

  final MorningFact? morning;
  final FoodSummary? food;
  final ActivitySummary activity;
  final TrainingSummary? training;
  final double? estimatedTotalBurn;
  final DateTime targetDate;
  final BackupFileExportService? backupExportService;
  final ConfirmDailyLog? confirmDailyLog;

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
      final confirmDailyLog = widget.confirmDailyLog;
      if (confirmDailyLog == null) {
        await DailyFinalizeCoordinatorFactory.production().finalize(
          targetLocalDate: OperationLocalDate.parse(
            _formatLocalDate(widget.targetDate),
          ),
          estimatedTotalBurnKcal: widget.estimatedTotalBurn,
        );
      } else {
        await confirmDailyLog(widget.estimatedTotalBurn);
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => BackupPromptDialog(
          exportService:
              widget.backupExportService ?? BackupFileExportService(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DailyLogValidationException catch (error) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      final labels = error.invalidModules
          .map(DailyLogConfirmationValidation.moduleLabel)
          .join(', ');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('必須記録を完了してください: $labels')));
    } on DailyFinalizeException catch (error) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DAILY LOGの確定に失敗しました: ${error.code.name}')),
      );
    } on StateError {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DAILY LOGのデータを準備できませんでした。')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('DAILY LOGの確定に失敗しました。')));
    }
  }

  String _formatLocalDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

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
                  '必須記録を完了してください: $invalidLabels',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              AppSpacing.gapLG,
              const Text(
                '確定後は本日の通常編集・削除がロックされます。'
                '変更が必要な場合は訂正フローを使用してください。',
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
              const Text('本日の記録を確定', textAlign: TextAlign.center),
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
