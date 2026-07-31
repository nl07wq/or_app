import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/services/daily_log_confirmation_validation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../activity/models/activity_summary_state.dart';
import '../../dashboard/log_confirmation_review_page.dart';
import '../../food/models/food_summary_state.dart';
import '../../morning/models/morning_fact_state.dart';
import '../../operation_date/models/daily_finalize_result.dart';
import '../../operation_date/services/daily_finalize_coordinator_factory.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/models/training_summary_state.dart';
import '../models/daily_command_read_model.dart';
import '../services/daily_command_read_model_builder.dart';
import '../widgets/daily_command_item.dart';

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({super.key});

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  late final PageController _pageController;
  var _currentPage = 1;
  var _refreshToken = 0;
  var _isRecovering = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int page) => _pageController.animateToPage(
    page,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );

  void _refresh() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COMMAND CENTER')),
      body: Column(
        children: [
          _WorkspaceHeader(
            currentPage: _currentPage,
            onSelectPage: _selectPage,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                const _BriefDebriefPage(),
                _DailyCommandPage(
                  refreshToken: _refreshToken,
                  isRecovering: _isRecovering,
                  onRefresh: _refresh,
                  onRecover: _recover,
                ),
                const _DataCenterPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recover() async {
    if (_isRecovering) return;
    setState(() => _isRecovering = true);
    try {
      await DailyFinalizeCoordinatorFactory.production().recover();
      if (mounted) _refresh();
    } on DailyFinalizeException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('復旧に失敗しました: ${error.code.name}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日次確定処理を再開できませんでした。')));
      }
    } finally {
      if (mounted) setState(() => _isRecovering = false);
    }
  }
}

class _DailyCommandPage extends StatelessWidget {
  const _DailyCommandPage({
    required this.refreshToken,
    required this.isRecovering,
    required this.onRefresh,
    required this.onRecover,
  });

  final int refreshToken;
  final bool isRecovering;
  final VoidCallback onRefresh;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        morningFactNotifier,
        foodSummaryNotifier,
        trainingSummaryNotifier,
        activitySummaryNotifier,
      ]),
      builder: (context, _) => FutureBuilder<DailyCommandReadModel>(
        key: ValueKey(refreshToken),
        future: _loadModel(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorContent(onRetry: onRefresh);
          }
          final model = snapshot.requireData;
          return _DailyCommandContent(
            model: model,
            isRecovering: isRecovering,
            onRecover: onRecover,
          );
        },
      ),
    );
  }

  Future<DailyCommandReadModel> _loadModel() async {
    final state = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    return DailyCommandReadModelBuilder.build(
      operationState: state,
      status: morningFactNotifier.value,
      food: foodSummaryNotifier.value,
      training: trainingSummaryNotifier.value,
      activity: activitySummaryNotifier.value,
    );
  }
}

class _DailyCommandContent extends StatelessWidget {
  const _DailyCommandContent({
    required this.model,
    required this.isRecovering,
    required this.onRecover,
  });

  final DailyCommandReadModel model;
  final bool isRecovering;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('daily-command-list'),
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.radar_outlined,
          title: 'CURRENT OPERATION',
        ),
        AppSpacing.gapSM,
        _KeyValueCard(
          values: {
            'Operation Date': model.operationDate,
            'Cycle State': _cycleLabel(model.cycleState),
          },
        ),
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.flag_outlined, title: 'DAILY COMMAND'),
        AppSpacing.gapSM,
        _CommandSummary(model: model),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.widgets_outlined,
          title: 'OPERATION MODULES',
        ),
        AppSpacing.gapSM,
        ..._moduleCards(context),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.fact_check_outlined,
          title: 'DAILY REVIEW',
        ),
        AppSpacing.gapSM,
        _reviewCard(context),
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.storage_outlined, title: 'DATA CENTER'),
        AppSpacing.gapSM,
        OperationButton(
          icon: Icons.backup_outlined,
          text: 'BACKUP & RESTORE',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.backupRestore),
        ),
        AppSpacing.gapLG,
      ],
    );
  }

  List<Widget> _moduleCards(BuildContext context) {
    final entries = [
      ('STATUS', model.statusModuleState, AppRoutes.morning),
      ('FOOD', model.foodModuleState, AppRoutes.food),
      ('TRAINING', model.trainingModuleState, AppRoutes.training),
      ('ACTIVITY', model.activityModuleState, AppRoutes.activity),
    ];
    return [
      for (final entry in entries) ...[
        OperationCard(
          child: Row(
            children: [
              Icon(
                _moduleIcon(entry.$2),
                color: _moduleColor(context, entry.$2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.$1)),
              Text(_moduleLabel(entry.$2)),
              IconButton(
                tooltip: '${entry.$1}を開く',
                onPressed: model.isHistoricalView
                    ? null
                    : () => Navigator.pushNamed(context, entry.$3),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        AppSpacing.gapSM,
      ],
    ];
  }

  Widget _reviewCard(BuildContext context) {
    if (model.recoveryRequired) {
      return OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECOVERY REQUIRED',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.gapSM,
            Text('対象日 ${model.operationDate} / ${model.persistentPhase.name}'),
            AppSpacing.gapMD,
            OperationButton(
              icon: Icons.restart_alt_outlined,
              text: isRecovering ? 'RECOVERING...' : 'RESUME FINALIZE',
              onPressed: isRecovering ? null : onRecover,
            ),
          ],
        ),
      );
    }
    final blockers = model.finalizeBlockingReasons
        .map(DailyLogConfirmationValidation.moduleLabel)
        .join(', ');
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.canFinalize ? 'Finalize可能' : 'Finalize不可'),
          if (blockers.isNotEmpty) ...[AppSpacing.gapSM, Text('不足: $blockers')],
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.preview_outlined,
            text: 'VIEW DAILY REVIEW',
            onPressed: model.isHistoricalView
                ? null
                : () => _openReview(context),
          ),
          AppSpacing.gapSM,
          OperationButton(
            icon: Icons.verified_outlined,
            text: 'FINALIZE DAY',
            onPressed: model.canFinalize ? () => _openReview(context) : null,
          ),
        ],
      ),
    );
  }

  void _openReview(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.logConfirmationReview,
      arguments: LogConfirmationReviewPage(
        morning: morningFactNotifier.value,
        food: foodSummaryNotifier.value,
        activity: activitySummaryNotifier.value,
        training: trainingSummaryNotifier.value,
        estimatedTotalBurn: model.estimatedTotalBurnKcal,
        targetDate: DateTime.parse(model.operationDate),
      ),
    );
  }
}

class _CommandSummary extends StatelessWidget {
  const _CommandSummary({required this.model});
  final DailyCommandReadModel model;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DailyCommandItem(
          icon: model.operationStatus == null
              ? Icons.cancel_outlined
              : Icons.check_circle_outline,
          label: 'OPERATION STATUS',
          value: model.operationStatus?.name.toUpperCase() ?? 'STANDBY',
          status: model.operationStatus,
        ),
        Text(model.statusReason),
        if (model.commanderIntent != null) ...[
          AppSpacing.gapMD,
          DailyCommandItem(
            icon: Icons.flag_outlined,
            label: 'COMMANDER INTENT',
            value: model.commanderIntent!,
          ),
        ],
        if (model.morningBriefSummary != null) ...[
          AppSpacing.gapMD,
          DailyCommandItem(
            icon: Icons.lightbulb_outline,
            label: 'ARGO COMMENT',
            value: model.morningBriefSummary!,
          ),
        ],
      ],
    ),
  );
}

class _KeyValueCard extends StatelessWidget {
  const _KeyValueCard({required this.values});
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: 24,
      runSpacing: 12,
      children: values.entries
          .map((entry) => Text('${entry.key}\n${entry.value}'))
          .toList(),
    ),
  );
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: OperationCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Current Operationを読み込めませんでした。'),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.refresh,
            text: 'RETRY',
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.currentPage,
    required this.onSelectPage,
  });
  final int currentPage;
  final ValueChanged<int> onSelectPage;
  @override
  Widget build(BuildContext context) {
    const labels = ['Brief / Debrief', 'Daily Command', 'Data Center'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: List.generate(
          labels.length,
          (index) => TextButton(
            onPressed: () => onSelectPage(index),
            child: Text(
              labels[index],
              style: TextStyle(
                fontWeight: index == currentPage ? FontWeight.bold : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BriefDebriefPage extends StatelessWidget {
  const _BriefDebriefPage();
  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.cardPadding,
    children: const [
      SectionHeader(icon: Icons.article_outlined, title: 'BRIEF / DEBRIEF'),
      AppSpacing.gapMD,
      _WorkspacePlaceholderCard(
        message: 'Morning BriefとDaily Debriefの履歴を表示する施設です。',
      ),
    ],
  );
}

class _DataCenterPage extends StatelessWidget {
  const _DataCenterPage();
  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.cardPadding,
    children: [
      const SectionHeader(icon: Icons.storage_outlined, title: 'DATA CENTER'),
      AppSpacing.gapMD,
      const _WorkspacePlaceholderCard(message: '正式なBACKUPとRESTOREを管理します。'),
      AppSpacing.gapMD,
      OperationButton(
        icon: Icons.backup_outlined,
        text: 'BACKUP & RESTORE',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.backupRestore),
      ),
    ],
  );
}

class _WorkspacePlaceholderCard extends StatelessWidget {
  const _WorkspacePlaceholderCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => OperationCard(child: Text(message));
}

String _cycleLabel(DailyCommandCycleState state) => switch (state) {
  DailyCommandCycleState.standby => 'STANDBY',
  DailyCommandCycleState.active => 'ACTIVE',
  DailyCommandCycleState.reviewReady => 'REVIEW READY',
  DailyCommandCycleState.finalizing => 'FINALIZING',
  DailyCommandCycleState.recoveryRequired => 'RECOVERY REQUIRED',
};

String _moduleLabel(DailyCommandModuleState state) => switch (state) {
  DailyCommandModuleState.missing => 'Missing',
  DailyCommandModuleState.recorded => 'Recorded',
  DailyCommandModuleState.invalid => 'Invalid',
  DailyCommandModuleState.optionalMissing => 'Optional',
};

IconData _moduleIcon(DailyCommandModuleState state) => switch (state) {
  DailyCommandModuleState.recorded => Icons.check_circle_outline,
  DailyCommandModuleState.optionalMissing => Icons.circle_outlined,
  _ => Icons.error_outline,
};

Color _moduleColor(BuildContext context, DailyCommandModuleState state) =>
    state == DailyCommandModuleState.recorded
    ? Theme.of(context).colorScheme.primary
    : state == DailyCommandModuleState.optionalMissing
    ? Theme.of(context).colorScheme.onSurfaceVariant
    : Theme.of(context).colorScheme.error;
