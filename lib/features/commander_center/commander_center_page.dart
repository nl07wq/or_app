import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

class CommanderCenterPage extends StatelessWidget {
  const CommanderCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('COMMANDER CENTER')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: const [
          SectionHeader(icon: Icons.radar, title: 'COMMAND OVERVIEW'),
          AppSpacing.gapLG,
          SectionHeader(
            icon: Icons.shield_outlined,
            title: 'OPERATION STATUS',
          ),
          AppSpacing.gapSM,
          _InfoCard(
            icon: Icons.check_circle_outline,
            title: 'STANDBY',
            message: 'All placeholder systems are ready for today\'s operation.',
          ),
          AppSpacing.gapXL,
          SectionHeader(
            icon: Icons.flag_outlined,
            title: 'COMMANDER INTENT',
          ),
          AppSpacing.gapSM,
          _InfoCard(
            icon: Icons.track_changes_outlined,
            title: 'TODAY\'S FOCUS',
            message:
                'Maintain steady progress through meals, training, and recovery.',
          ),
          AppSpacing.gapLG,
          SectionHeader(
            icon: Icons.wb_sunny_outlined,
            title: 'MORNING BRIEF',
          ),
          AppSpacing.gapSM,
          _InfoCard(
            icon: Icons.lightbulb_outline,
            title: 'BRIEFING',
            message:
                'Start with a balanced breakfast and schedule a focused movement session.',
          ),
          AppSpacing.gapXL,
          SectionHeader(icon: Icons.bolt_outlined, title: 'QUICK ACTIONS'),
          AppSpacing.gapSM,
          OperationButton(
            icon: Icons.wb_sunny_outlined,
            text: 'LOG MORNING',
            onPressed: null,
          ),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.restaurant_outlined,
            text: 'LOG MEAL',
            onPressed: null,
          ),
          AppSpacing.gapMD,
          OperationButton(
            icon: Icons.fitness_center_outlined,
            text: 'LOG TRAINING',
            onPressed: null,
          ),
          AppSpacing.gapXL,
          SectionHeader(
            icon: Icons.monitor_heart_outlined,
            title: 'TODAY\'S METRICS',
          ),
          AppSpacing.gapSM,
          _MetricsCard(),
          AppSpacing.gapLG,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.gapSM,
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard();

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _Metric(label: 'MEALS', value: '0')),
              Expanded(child: _Metric(label: 'TRAINING', value: '0 min')),
              Expanded(child: _Metric(label: 'WATER', value: '0 L')),
            ],
          ),
          AppSpacing.gapMD,
          const Text('Placeholder metrics will update after future integration.'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapXS,
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
