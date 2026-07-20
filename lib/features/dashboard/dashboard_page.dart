import 'package:flutter/material.dart';

import '../../core/engine/commander_snapshot.dart';
import '../../core/engine/food_summary.dart';
import '../../core/engine/operation_engine.dart';
import '../../core/engine/operation_input.dart';
import '../../core/engine/training_summary.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';

import '../food/models/food_summary_state.dart';

import '../training/models/training_summary_state.dart';

import 'widgets/status_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
                final input = morningFact == null
                    ? null
                    : OperationInput(
                        morning: morningFact,
                        food: foodSummary,
                        training: trainingSummary,
                      );
                final engine = const OperationEngine();
                final snapshot = input == null
                    ? null
                    : engine.generateCommanderSnapshot(input);
                final estimatedTDEE = input == null
                    ? null
                    : engine.estimateTDEE(input);

                return Scaffold(
          appBar: AppBar(title: const Text('ORLO DASHBOARD')),
          body: ListView(
            padding: AppSpacing.cardPadding,
            children: [
              SectionHeader(
                icon: Icons.dashboard_outlined,
                title: 'DAILY COMMAND',
              ),
              AppSpacing.gapLG,
              SectionHeader(
                icon: Icons.flag_outlined,
                title: 'COMMANDER INTENT',
              ),
              AppSpacing.gapSM,
              _CommanderIntentCard(snapshot: snapshot),
              AppSpacing.gapXL,
              StatusCard(
                isReady: morningFact != null,
                status: snapshot?.status,
              ),
              AppSpacing.gapXL,
              SectionHeader(
                icon: Icons.wb_sunny_outlined,
                title: 'MORNING BRIEF SUMMARY',
              ),
              AppSpacing.gapSM,
              _InfoCard(
                icon: Icons.lightbulb_outline,
                title: 'BRIEFING',
                message: snapshot?.summary ?? '--',
              ),
              AppSpacing.gapXL,
              SectionHeader(
                icon: Icons.timeline_outlined,
                title: 'OPERATION PROGRESS',
              ),
              AppSpacing.gapSM,
              _ProgressCard(
                morningFact: morningFact,
                estimatedTDEE: estimatedTDEE,
                foodSummary: foodSummary,
                trainingSummary: trainingSummary,
              ),
              AppSpacing.gapXL,
              SectionHeader(icon: Icons.bolt_outlined, title: 'QUICK ACCESS'),
              AppSpacing.gapSM,
              _MorningButton(),
              AppSpacing.gapMD,
              _FoodButton(),
              AppSpacing.gapMD,
              _TrainingButton(),
              AppSpacing.gapMD,
              _CommandCenterButton(),
              AppSpacing.gapMD,
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

class _CommanderIntentCard extends StatelessWidget {
  final CommanderSnapshot? snapshot;

  const _CommanderIntentCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.track_changes_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                '最優先目標',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          AppSpacing.gapLG,
          Text(
            snapshot?.commanderIntent ?? '--',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          AppSpacing.gapSM,
          Text(
            snapshot?.summary ?? '--',
          ),
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
                Text(title, style: Theme.of(context).textTheme.titleMedium),
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

class _ProgressCard extends StatelessWidget {
  final MorningFact? morningFact;
  final double? estimatedTDEE;
  final FoodSummary? foodSummary;
  final TrainingSummary? trainingSummary;

  const _ProgressCard({
    required this.morningFact,
    required this.estimatedTDEE,
    required this.foodSummary,
    required this.trainingSummary,
  });

  @override
  Widget build(BuildContext context) {
    final morningComplete = morningFact != null;
    final mealCount = foodSummary?.mealCount ?? 0;
    final calories = foodSummary?.calories ?? 0;
    final protein = foodSummary?.protein ?? 0;

    return OperationCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ProgressSummaryMetric(
                  label: 'WEIGHT',
                  value: morningFact == null
                      ? '--'
                      : '${morningFact!.weight.toStringAsFixed(1)} kg',
                ),
              ),
              Expanded(
                child: _ProgressSummaryMetric(
                  label: 'SLEEP',
                  value: morningFact == null
                      ? '--'
                      : _formatSleep(morningFact!.sleepDuration),
                ),
              ),
              Expanded(
                child: _ProgressSummaryMetric(
                  label: 'TDEE',
                  value: estimatedTDEE == null
                      ? '--'
                      : '${estimatedTDEE!.toStringAsFixed(0)} kcal',
                ),
              ),
            ],
          ),
          AppSpacing.gapLG,
          _ProgressRow(
            label: 'MORNING ROUTINE',
            status: morningComplete ? '完了' : '未完了',
            progress: morningComplete ? 1.0 : 0.0,
          ),
          AppSpacing.gapMD,
          _ProgressRow(
            label: 'FOOD',
            status: '$mealCount / 3',
            progress: (mealCount / 3).clamp(0.0, 1.0).toDouble(),
          ),
          AppSpacing.gapMD,
          _ProgressRow(
            label: 'CALORIES',
            status: '${calories.toStringAsFixed(0)} / 2200 kcal',
            progress: (calories / 2200).clamp(0.0, 1.0).toDouble(),
          ),
          AppSpacing.gapMD,
          _ProgressRow(
            label: 'PROTEIN',
            status: '${protein.toStringAsFixed(1)} / 100 g',
            progress: (protein / 100).clamp(0.0, 1.0).toDouble(),
          ),
          AppSpacing.gapMD,
          _ProgressRow(
            label: 'WATER',
            status: '0 / 3500 ml',
            progress: 0.0,
          ),
          AppSpacing.gapMD,
          _ProgressRow(
            label: 'TRAINING',
            status: trainingSummary?.completed == true ? '実施' : '未実施',
            progress: trainingSummary?.completed == true ? 1.0 : 0.0,
          ),
        ],
      ),
    );
  }

  String _formatSleep(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}

class _ProgressSummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ProgressSummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        AppSpacing.gapXS,
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String status;
  final double progress;

  const _ProgressRow({
    required this.label,
    required this.status,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text(status),
          ],
        ),
        AppSpacing.gapXS,
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

class _MorningButton extends StatelessWidget {
  const _MorningButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.play_arrow,
      text: 'Morning',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.morning);
      },
    );
  }
}

class _FoodButton extends StatelessWidget {
  const _FoodButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.restaurant,
      text: 'Food',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.food);
      },
    );
  }
}

class _TrainingButton extends StatelessWidget {
  const _TrainingButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.fitness_center,
      text: 'Training',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.training);
      },
    );
  }
}

class _CommandCenterButton extends StatelessWidget {
  const _CommandCenterButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.flag,
      text: 'Command Center',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.commandCenter);
      },
    );
  }
}
