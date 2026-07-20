import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/engine/food_summary.dart';
import '../../../core/engine/operation_engine.dart';
import '../../../core/engine/operation_input.dart';
import '../../../core/engine/training_summary.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../food/models/food_summary_state.dart';
import '../../morning/models/morning_fact.dart';
import '../../morning/models/morning_fact_state.dart';
import '../../training/models/training_summary_state.dart';
import '../widgets/commander_panel.dart';

class CommandCenterPage extends StatefulWidget {
  const CommandCenterPage({super.key});

  @override
  State<CommandCenterPage> createState() => _CommandCenterPageState();
}

class _CommandCenterPageState extends State<CommandCenterPage> {
  late final PageController _pageController;
  var _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    unawaited(refreshFoodSummary());
    unawaited(refreshTrainingSummary());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MorningFact?>(
      valueListenable: morningFactNotifier,
      builder: (context, morningFact, _) {
        return ValueListenableBuilder<FoodSummary?>(
          valueListenable: foodSummaryNotifier,
          builder: (context, foodSummary, _) {
            return ValueListenableBuilder<TrainingSummary?>(
              valueListenable: trainingSummaryNotifier,
              builder: (context, trainingSummary, _) {
                final analysis = morningFact == null
                    ? null
                    : const OperationEngine().generateCommanderAnalysis(
                        OperationInput(
                          morning: morningFact,
                          food: foodSummary,
                          training: trainingSummary,
                        ),
                      );

                return Scaffold(
                  appBar: AppBar(title: const Text('Commander Center')),
                  body: Column(
                    children: [
                      _WorkspaceHeader(
                        currentPage: _currentPage,
                        onSelectPage: _selectPage,
                      ),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (page) {
                            setState(() => _currentPage = page);
                          },
                          children: [
                            const _BriefDebriefPage(),
                            CommanderPanel(analysis: analysis),
                            const _DataCenterPage(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  const _WorkspaceHeader({
    required this.currentPage,
    required this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Brief / Debrief', 'Daily Command', 'Data Center'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isSelected = index == currentPage;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TextButton(
              onPressed: () => onSelectPage(index),
              style: TextButton.styleFrom(
                foregroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BriefDebriefPage extends StatelessWidget {
  const _BriefDebriefPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.cardPadding,
      children: const [
        SectionHeader(
          icon: Icons.article_outlined,
          title: 'BRIEF / DEBRIEF',
        ),
        AppSpacing.gapMD,
        _WorkspacePlaceholderCard(
          message:
              'Command Cycle completion will make Morning Brief and Daily Debrief available here.',
          items: ['Morning Brief', 'Daily Debrief', 'Execution Report'],
        ),
      ],
    );
  }
}

class _DataCenterPage extends StatelessWidget {
  const _DataCenterPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.cardPadding,
      children: const [
        SectionHeader(icon: Icons.insights_outlined, title: 'DATA CENTER'),
        AppSpacing.gapMD,
        _WorkspacePlaceholderCard(
          message:
              'Long-term trends and analysis will appear here after the Command Cycle and Archive data are connected.',
          items: [
            'Body Trend',
            'Recovery Trend',
            'Nutrition Trend',
            'Hydration Trend',
            'Training Trend',
            'Week / Month Reports',
          ],
        ),
      ],
    );
  }
}

class _WorkspacePlaceholderCard extends StatelessWidget {
  final String message;
  final List<String> items;

  const _WorkspacePlaceholderCard({required this.message, required this.items});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          AppSpacing.gapMD,
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(item),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
