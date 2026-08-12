import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../activity/models/activity_summary_state.dart';
import '../../dashboard/widgets/daily_log_card.dart';
import '../../food/models/food_summary_state.dart';
import '../../morning/models/morning_fact_state.dart';
import '../../repositories/app_repository_container.dart';
import '../../training/models/training_summary_state.dart';
import '../models/daily_command_read_model.dart';
import '../core/daily_assessment_rule_engine.dart';
import '../models/daily_assessment.dart';
import '../services/daily_assessment_fact_loader.dart';
import '../services/daily_command_read_model_builder.dart';
import '../services/daily_estimated_total_burn_service.dart';
import '../widgets/daily_assessment_card.dart';
import '../widgets/data_center_page.dart';
import '../widgets/brief_debrief_page.dart';
import '../../report_sync/models/morning_brief_state.dart';

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({super.key});

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  late final PageController _pageController;
  var _currentPage = 1;
  var _refreshToken = 0;

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
                const BriefDebriefPage(),
                _DailyCommandPage(
                  refreshToken: _refreshToken,
                  onRefresh: _refresh,
                ),
                const DataCenterPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCommandPage extends StatelessWidget {
  const _DailyCommandPage({
    required this.refreshToken,
    required this.onRefresh,
  });

  final int refreshToken;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        morningFactNotifier,
        foodSummaryNotifier,
        trainingSummaryNotifier,
        activitySummaryNotifier,
        morningBriefRevisionNotifier,
      ]),
      builder: (context, _) =>
          FutureBuilder<
            ({DailyCommandReadModel model, DailyAssessment assessment})
          >(
            key: ValueKey(refreshToken),
            future: _loadModel(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _ErrorContent(onRetry: onRefresh);
              }
              final result = snapshot.requireData;
              return _DailyCommandContent(
                model: result.model,
                assessment: result.assessment,
                onRefresh: onRefresh,
              );
            },
          ),
    );
  }

  Future<({DailyCommandReadModel model, DailyAssessment assessment})>
  _loadModel() async {
    final state = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    final morningBrief = await AppRepositoryRegistry.container.morningBriefs
        .readByLocalDate(state.operationDate.value);
    final status = morningFactNotifier.value;
    final burnWeight =
        await RecentStatusWeightResolver(
          AppRepositoryRegistry.container.status,
        ).resolve(
          operationDate: state.operationDate.value,
          currentWeightKg: status?.weight,
        );
    final model = DailyCommandReadModelBuilder.build(
      operationState: state,
      status: status,
      food: foodSummaryNotifier.value,
      training: trainingSummaryNotifier.value,
      activity: activitySummaryNotifier.value,
      morningBrief: morningBrief,
      burnWeightKg: burnWeight,
    );
    final facts = await DailyAssessmentFactLoader(
      AppRepositoryRegistry.container,
    ).load(state);
    return (
      model: model,
      assessment: const DailyAssessmentRuleEngine().evaluate(facts),
    );
  }
}

class _DailyCommandContent extends StatelessWidget {
  const _DailyCommandContent({
    required this.model,
    required this.assessment,
    required this.onRefresh,
  });

  final DailyCommandReadModel model;
  final DailyAssessment assessment;
  final VoidCallback onRefresh;

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
        const SectionHeader(
          icon: Icons.assessment_outlined,
          title: 'DAILY ASSESSMENT',
        ),
        AppSpacing.gapSM,
        DailyAssessmentView(assessment: assessment),
        AppSpacing.gapXL,
        DailyLogSection(
          morningFact: morningFactNotifier.value,
          foodSummary: foodSummaryNotifier.value,
          activitySummary: activitySummaryNotifier.value,
          trainingSummary: trainingSummaryNotifier.value,
          estimatedTotalBurn: model.estimatedTotalBurnKcal,
          onReviewCompleted: (_) async => onRefresh(),
        ),
        AppSpacing.gapLG,
      ],
    );
  }
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
    const labels = ['BRIEF / DEBRIEF', 'DAILY COMMAND', 'DATA CENTER'];
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

String _cycleLabel(DailyCommandCycleState state) => switch (state) {
  DailyCommandCycleState.standby => 'STANDBY',
  DailyCommandCycleState.active => 'ACTIVE',
  DailyCommandCycleState.reviewReady => 'REVIEW READY',
  DailyCommandCycleState.finalizing => 'FINALIZING',
  DailyCommandCycleState.recoveryRequired => 'RECOVERY REQUIRED',
};
