import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';
import '../training_analysis/pages/training_analysis_page.dart';

import 'widgets/training_history_button.dart';
import 'widgets/training_ambient_comparison.dart';
import 'widgets/training_dot_matrix_title.dart';
import 'widgets/training_led_back_button.dart';
import 'widgets/training_manual_card.dart';
import 'widgets/training_sync_card.dart';
import 'training_plan_import_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  TrainingAmbientVariant _ambientVariant = TrainingAmbientVariant.magneticFlux;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final horizontalPadding = mediaQuery.size.width < 360 ? 4.0 : AppSpacing.lg;
    final contentTopPadding =
        mediaQuery.padding.top + kToolbarHeight + AppSpacing.lg;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        key: const ValueKey('training-page-transparent-appbar'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? const TrainingLedBackButton()
            : null,
        title: const TrainingDotMatrixTitle(
          titleKey: ValueKey('training-page-appbar-title'),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // KINETIC ENGINE is a fixed viewport ambient. Its reference image
          // is authored at the matching portrait ratio, while only the
          // foreground content below scrolls.
          TrainingAmbientComparison(variant: _ambientVariant),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              contentTopPadding,
              horizontalPadding,
              AppSpacing.lg,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TrainingAmbientComparisonSelector(
                      selected: _ambientVariant,
                      onChanged: (variant) {
                        if (variant == _ambientVariant) return;
                        setState(() => _ambientVariant = variant);
                      },
                    ),
                    AppSpacing.gapMD,
                    const SectionHeader(
                      icon: Icons.fitness_center,
                      title: 'MANUAL ENTRY',
                    ),

                    AppSpacing.gapSM,

                    const OperationDescription(
                      text:
                          '本日のトレーニング内容を\n'
                          '手動で記録します。',
                    ),

                    AppSpacing.gapMD,

                    const TrainingManualCard(),

                    AppSpacing.gapXL,

                    const SectionHeader(
                      icon: Icons.event_note_outlined,
                      title: 'PLAN',
                    ),

                    AppSpacing.gapSM,

                    const OperationDescription(
                      text: 'トレーニング記録をもとに、\n次回のプランを作成します。',
                    ),

                    AppSpacing.gapMD,

                    OperationButton(
                      icon: Icons.event_note_outlined,
                      text: 'TRAINING PLAN',
                      frostedGlass: true,
                      safeGlassTransparencyFactor: .70,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrainingPlanImportPage(),
                        ),
                      ),
                    ),

                    AppSpacing.gapXL,

                    const SectionHeader(icon: Icons.history, title: 'RECORD'),

                    AppSpacing.gapSM,

                    const OperationDescription(
                      text:
                          '過去のトレーニング履歴を\n'
                          '確認・編集できます。',
                    ),

                    AppSpacing.gapMD,

                    const TrainingHistoryButton(),

                    AppSpacing.gapXL,

                    const SectionHeader(
                      icon: Icons.analytics_outlined,
                      title: 'ANALYSIS REPORT',
                    ),

                    AppSpacing.gapSM,

                    const OperationDescription(
                      text: 'トレーニング記録を選択して、\n分析レポートを作成・確認します。',
                    ),

                    AppSpacing.gapMD,

                    OperationButton(
                      icon: Icons.analytics_outlined,
                      text: 'TRAINING ANALYSIS REPORT',
                      frostedGlass: true,
                      safeGlassTransparencyFactor: .70,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrainingAnalysisPage(),
                        ),
                      ),
                    ),

                    AppSpacing.gapXL,

                    const SectionHeader(icon: Icons.sync, title: 'REPORT SYNC'),

                    AppSpacing.gapSM,

                    const OperationDescription(
                      text: 'ChatGPTから\nトレーニング記録を取り込みます。',
                    ),

                    AppSpacing.gapMD,

                    const TrainingSyncCard(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
