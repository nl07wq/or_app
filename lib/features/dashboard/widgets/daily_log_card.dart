import 'package:flutter/material.dart';

import '../../../core/engine/activity_summary.dart';
import '../../../core/engine/food_summary.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/daily_log_confirmation_validation.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/services/backup_file_export_service.dart';
import '../../morning/models/morning_fact.dart';
import '../../operation_date/models/operation_state.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/services/daily_finalize_coordinator_factory.dart';
import '../../report_sync/models/daily_debrief_record.dart';
import '../../report_sync/models/daily_debrief_state.dart';
import '../../repositories/app_repository_container.dart';
import 'backup_prompt_dialog.dart';

typedef DailyLogReviewCompleted =
    Future<void> Function(OperationLocalDate previousOperationDate);
typedef DailyLogFinalizeCompleted = Future<void> Function();

@visibleForTesting
Future<void> executeDailyLogFinalize({
  required Future<void> Function() finalize,
  required OperationLocalDate previousOperationDate,
  DailyLogFinalizeCompleted? afterFinalize,
  required DailyLogReviewCompleted? onReviewCompleted,
}) async {
  await finalize();
  await afterFinalize?.call();
  await onReviewCompleted?.call(previousOperationDate);
}

class DailyLogSection extends StatefulWidget {
  const DailyLogSection({
    super.key,
    required this.morningFact,
    required this.foodSummary,
    required this.activitySummary,
    required this.trainingSummary,
    required this.estimatedTotalBurn,
    this.onReviewCompleted,
    this.backupExportService,
  });

  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final ActivitySummary activitySummary;
  final TrainingSummary? trainingSummary;
  final double? estimatedTotalBurn;
  final DailyLogReviewCompleted? onReviewCompleted;
  final BackupFileExportService? backupExportService;

  @override
  State<DailyLogSection> createState() => _DailyLogSectionState();
}

class _DailyLogSectionState extends State<DailyLogSection> {
  late Future<_DailyCloseUiState> _closeState = _loadCloseState();
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    dailyDebriefRevisionNotifier.addListener(_handleDailyDebriefChanged);
  }

  @override
  void dispose() {
    dailyDebriefRevisionNotifier.removeListener(_handleDailyDebriefChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = appInitializationController.value.isReadOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.fact_check_outlined,
          title: 'DAILY LOG',
        ),
        AppSpacing.gapSM,
        FutureBuilder<_DailyCloseUiState>(
          future: _closeState,
          builder: (context, closeSnapshot) {
            final closeState = closeSnapshot.data;
            final locked =
                closeState?.phase != OperationPhase.open &&
                closeState?.phase != OperationPhase.awaitingDebrief;
            return DailyLogCard(
              morningFact: widget.morningFact,
              foodSummary: widget.foodSummary,
              activitySummary: widget.activitySummary,
              trainingSummary: widget.trainingSummary,
              phase: closeState?.phase ?? OperationPhase.finalizing,
              finalizeReady: closeState?.finalizeReady ?? false,
              onStatusTap: isReadOnly || locked
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.morning),
              onFoodTap: isReadOnly || locked
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.food),
              onTrainingTap: isReadOnly || locked
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.training),
              onActivityTap: isReadOnly || locked
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.activity),
              onPrimaryAction: isReadOnly || closeState == null || _isFinalizing
                  ? null
                  : closeState.phase == OperationPhase.awaitingDebrief &&
                        closeState.finalizeReady
                  ? _finalize
                  : null,
            );
          },
        ),
      ],
    );
  }

  Future<void> _finalize() async {
    if (_isFinalizing) return;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('FINALIZE DAY'),
        content: const Text(
          'Daily Debriefを含むこの日の記録を確定して\n'
          'Operation Dateを翌日へ進めますか？',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _isFinalizing = true);
    try {
      final state = await AppRepositoryRegistry.container.operationState
          .requireCurrent();
      final previousDate = state.operationDate;
      final onReviewCompleted = widget.onReviewCompleted;
      await executeDailyLogFinalize(
        finalize: () async {
          await DailyFinalizeCoordinatorFactory.production().finalize(
            targetLocalDate: previousDate,
          );
        },
        previousOperationDate: previousDate,
        afterFinalize: () async {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (_) => BackupPromptDialog(
              exportService:
                  widget.backupExportService ?? BackupFileExportService(),
            ),
          );
        },
        onReviewCompleted: onReviewCompleted,
      );
      if (!mounted) return;
      _reloadCloseState();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('FINALIZE DAYに失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  Future<_DailyCloseUiState> _loadCloseState() async {
    final container = AppRepositoryRegistry.container;
    final state = await container.operationState.requireCurrent();
    var finalizeReady = false;
    if (state.phase == OperationPhase.awaitingDebrief) {
      final debrief = await container.dailyDebriefs.readByLocalDate(
        state.operationDate.value,
      );
      finalizeReady =
          debrief != null &&
          await container.dailyDebriefSources.projectLifecycle(debrief) ==
              DailyDebriefLifecycleStatus.active;
      if (finalizeReady) {
        try {
          await DailyFinalizeCoordinatorFactory.production()
              .validateCurrentSourceSnapshot(state);
        } catch (_) {
          finalizeReady = false;
        }
      }
    }
    return _DailyCloseUiState(phase: state.phase, finalizeReady: finalizeReady);
  }

  void _reloadCloseState() {
    if (!mounted) return;
    setState(() {
      _closeState = _loadCloseState();
    });
  }

  void _handleDailyDebriefChanged() {
    _reloadCloseStateFor(dailyDebriefRevisionNotifier.value.operationDate);
  }

  Future<void> _reloadCloseStateFor(String operationDate) async {
    if (!mounted || !AppRepositoryRegistry.hasContainer) return;
    final state = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    if (!mounted || state.operationDate.value != operationDate) return;
    _reloadCloseState();
  }
}

class DailyLogCard extends StatelessWidget {
  const DailyLogCard({
    super.key,
    required this.morningFact,
    required this.foodSummary,
    required this.activitySummary,
    required this.trainingSummary,
    required this.phase,
    required this.finalizeReady,
    required this.onPrimaryAction,
    this.onStatusTap,
    this.onFoodTap,
    this.onTrainingTap,
    this.onActivityTap,
  });

  final MorningFact? morningFact;
  final FoodSummary? foodSummary;
  final ActivitySummary activitySummary;
  final TrainingSummary? trainingSummary;
  final OperationPhase phase;
  final bool finalizeReady;
  final VoidCallback? onPrimaryAction;
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
    final primaryReady =
        phase == OperationPhase.awaitingDebrief && finalizeReady;
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
          _DailyCloseReadiness(phase: phase, finalizeReady: finalizeReady),
          AppSpacing.gapMD,
          _DailyCloseActionButton(
            text: phase == OperationPhase.finalizing
                ? 'DAILY CLOSE IN PROGRESS'
                : 'FINALIZE DAY',
            onPressed: primaryReady ? onPrimaryAction : null,
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

class _DailyCloseReadiness extends StatelessWidget {
  const _DailyCloseReadiness({
    required this.phase,
    required this.finalizeReady,
  });

  final OperationPhase phase;
  final bool finalizeReady;

  @override
  Widget build(BuildContext context) {
    final awaiting = phase == OperationPhase.awaitingDebrief;
    final ready = awaiting && finalizeReady;
    const action = 'FINALIZE';
    final colorScheme = Theme.of(context).colorScheme;
    final color = ready ? colorScheme.primary : colorScheme.error;
    return Semantics(
      key: const ValueKey('daily-log-finalize-readiness'),
      label: ready ? '$action READY' : '$action BLOCKED DAILY DEBRIEF REQUIRED',
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ready ? '$action READY' : '$action BLOCKED',
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: color),
                      ),
                    ),
                  ),
                  if (!ready)
                    Text(
                      awaiting
                          ? 'DAILY DEBRIEF RE-CREATE REQUIRED'
                          : 'DAILY DEBRIEF REQUIRED',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCloseActionButton extends StatelessWidget {
  const _DailyCloseActionButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: AppTextStyles.label),
        ),
      ),
    );
  }
}

class _DailyCloseUiState {
  const _DailyCloseUiState({required this.phase, required this.finalizeReady});

  final OperationPhase phase;
  final bool finalizeReady;
}
