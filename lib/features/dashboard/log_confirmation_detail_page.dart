import 'package:flutter/material.dart';

import '../../core/engine/activity_summary.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/training_summary.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/daily_state_restore_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../activity/models/activity_summary_state.dart';
import '../food/models/food_summary_state.dart';
import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';
import '../operation_date/models/operation_state.dart';
import '../operation_date/services/daily_finalize_undo_service.dart';
import '../repositories/app_repository_container.dart';
import '../training/models/training_summary_state.dart';
import 'widgets/daily_review_body.dart';

class LogConfirmationDetailPage extends StatefulWidget {
  const LogConfirmationDetailPage({super.key, required this.targetDate});

  /// Retained for route compatibility. The direct production route resolves
  /// the one-shot entitlement from Operation State.
  final DateTime? targetDate;

  @override
  State<LogConfirmationDetailPage> createState() =>
      _LogConfirmationDetailPageState();
}

class _LogConfirmationDetailPageState extends State<LogConfirmationDetailPage> {
  late Future<_LastFinalizeState> _state;
  bool _undoing = false;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  Future<_LastFinalizeState> _load() async {
    final container = AppRepositoryRegistry.container;
    final operationState = await container.operationState.requireCurrent();
    final target = operationState.phase == OperationPhase.awaitingDebrief
        ? operationState.operationDate
        : operationState.undoableFinalizeDate;
    if (target == null) return const _LastFinalizeState.missing();
    final localDate = target.value;
    final requested = widget.targetDate;
    if (requested != null && _formatLocalDate(requested) != localDate) {
      return const _LastFinalizeState.missing();
    }

    final confirmation = await container.confirmation.findByLocalDate(
      localDate,
    );
    await Future.wait<void>([
      refreshMorningFact(localDate: localDate),
      refreshFoodSummary(localDate: localDate),
      refreshActivitySummary(localDate: localDate),
      refreshTrainingSummary(localDate: localDate),
    ]);
    final inspection = await DailyFinalizeUndoService(
      container.database,
    ).inspect();
    return _LastFinalizeState(
      localDate: localDate,
      currentOperationDate: operationState.operationDate.value,
      finalizedAt: confirmation?.confirmedAt,
      morningSummary: morningFactNotifier.value,
      foodSummary: foodSummaryNotifier.value,
      activitySummary: activitySummaryNotifier.value,
      trainingSummary: trainingSummaryNotifier.value,
      undoInspection: inspection,
    );
  }

  Future<void> _confirmUndo(_LastFinalizeState state) async {
    final inspection = state.undoInspection;
    if (_undoing || inspection == null || !inspection.canUndo) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          inspection.isAwaitingDailyClose
              ? 'UNDO DAILY CLOSE'
              : 'UNDO LAST FINALIZE',
        ),
        content: Text(
          '${state.localDate}のFINALIZEを取り消しますか？\n\n'
          'Operation Dateを${state.localDate}へ戻します。\n\n'
          '入力済みのSTATUS・FOOD・ACTIVITY・TRAININGは削除されません。\n\n'
          'このUNDOを実行すると、続けて前の日のFINALIZEを取り消すことはできません。\n\n'
          '再びFINALIZE DAYを実行すると、その新しいFINALIZEを一度だけUNDOできます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('FINALIZEを取り消す'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _undoing = true);
    try {
      final result = await DailyFinalizeUndoService(
        AppRepositoryRegistry.container.database,
      ).undo(expectedRevision: inspection.revision);
      await DailyStateRestoreService.restore(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'LAST FINALIZEを取り消しました。\n'
            'Operation Dateを${result.restoredOperationDate}へ戻しました。',
          ),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboard,
        (route) => false,
      );
    } on DailyFinalizeUndoException catch (error) {
      if (!mounted) return;
      setState(() {
        _undoing = false;
        _state = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${error.code.name} · ${error.stage}\n${error.message}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LAST FINALIZE')),
    body: FutureBuilder<_LastFinalizeState>(
      future: _state,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('LAST FINALIZEを読み込めませんでした。'));
        }
        final state = snapshot.data;
        if (state == null || state.localDate == null) {
          return const Center(child: Text('取り消せる直前のFINALIZEはありません'));
        }
        final inspection = state.undoInspection!;
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.event_available_outlined,
              title: 'LAST FINALIZE',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.localDate!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  AppSpacing.gapXS,
                  Text(
                    state.finalizedAt == null
                        ? 'Finalized At: Not available'
                        : 'Finalized At: ${_formatDateTime(state.finalizedAt!)}',
                  ),
                  AppSpacing.gapXS,
                  Text('Current Operation Date: ${state.currentOperationDate}'),
                  AppSpacing.gapLG,
                  DailyReviewBody(
                    morning: state.morningSummary,
                    food: state.foodSummary,
                    activity: state.activitySummary,
                    training: state.trainingSummary,
                    estimatedTotalBurnKcal: null,
                  ),
                ],
              ),
            ),
            AppSpacing.gapLG,
            const Text(
              '直前に成功したFINALIZEを一度だけ取り消します。'
              '記録は保持したまま、Operation Dateを対象日へ戻します。',
            ),
            AppSpacing.gapSM,
            if (!inspection.canUndo) ...[
              Text(
                _blockedMessage(inspection.blockingError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              AppSpacing.gapSM,
            ],
            OperationButton(
              icon: Icons.undo,
              text: _undoing
                  ? 'UNDOING...'
                  : inspection.isAwaitingDailyClose
                  ? 'UNDO DAILY CLOSE'
                  : 'UNDO LAST FINALIZE',
              onPressed: inspection.canUndo && !_undoing
                  ? () => _confirmUndo(state)
                  : null,
            ),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );

  static String _blockedMessage(DailyFinalizeUndoException error) {
    if (error.code == DailyFinalizeUndoErrorCode.currentDateHasRecords ||
        error.code == DailyFinalizeUndoErrorCode.currentDateHasDraft) {
      return 'UNDO LAST FINALIZE BLOCKED\n'
          '現在のOperation Dateに入力済みデータがあります。\n'
          '入力済みデータを保持したまま、Operation Dateを前日へ戻すことはできません。';
    }
    return 'UNDO LAST FINALIZE BLOCKED\n'
        '${error.code.name} · ${error.stage}\n${error.message}';
  }

  static String _formatLocalDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_formatLocalDate(local)} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _LastFinalizeState {
  const _LastFinalizeState({
    required this.localDate,
    required this.currentOperationDate,
    required this.finalizedAt,
    required this.morningSummary,
    required this.foodSummary,
    required this.activitySummary,
    required this.trainingSummary,
    required this.undoInspection,
  });

  const _LastFinalizeState.missing()
    : localDate = null,
      currentOperationDate = null,
      finalizedAt = null,
      morningSummary = null,
      foodSummary = null,
      activitySummary = null,
      trainingSummary = null,
      undoInspection = null;

  final String? localDate;
  final String? currentOperationDate;
  final DateTime? finalizedAt;
  final MorningFact? morningSummary;
  final FoodSummary? foodSummary;
  final ActivitySummary? activitySummary;
  final TrainingSummary? trainingSummary;
  final DailyFinalizeUndoInspection? undoInspection;
}
