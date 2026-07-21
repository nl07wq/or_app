import 'package:flutter/material.dart';

import '../../core/models/daily_log_confirmation.dart';
import '../../core/repositories/daily_log_confirmation_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

class LogConfirmationDetailPage extends StatefulWidget {
  const LogConfirmationDetailPage({super.key, required this.targetDate});

  final DateTime? targetDate;

  @override
  State<LogConfirmationDetailPage> createState() =>
      _LogConfirmationDetailPageState();
}

class _LogConfirmationDetailPageState
    extends State<LogConfirmationDetailPage> {
  late final Future<DailyLogConfirmation?> _confirmation;

  @override
  void initState() {
    super.initState();
    _confirmation = widget.targetDate == null
        ? Future.value(null)
        : DailyLogConfirmationRepository.findByDate(widget.targetDate!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Confirmation')),
      body: FutureBuilder<DailyLogConfirmation?>(
        future: _confirmation,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final confirmation = snapshot.data;
          if (confirmation == null) {
            return const Center(
              child: Text('確認データを読み込めませんでした。'),
            );
          }

          return ListView(
            padding: AppSpacing.cardPadding,
            children: [
              OperationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      icon: Icons.fact_check_outlined,
                      title: 'LOG CONFIRMATION',
                    ),
                    AppSpacing.gapMD,
                    Text(_formatDate(confirmation.date)),
                    AppSpacing.gapSM,
                    Text('Confirmed at ${_formatDateTime(confirmation.confirmedAt)}'),
                  ],
                ),
              ),
              AppSpacing.gapMD,
              _MorningSnapshotCard(confirmation: confirmation),
              AppSpacing.gapMD,
              _FoodSnapshotCard(confirmation: confirmation),
              AppSpacing.gapMD,
              _ActivitySnapshotCard(confirmation: confirmation),
              AppSpacing.gapMD,
              _TrainingSnapshotCard(confirmation: confirmation),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_formatDate(local)} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _MorningSnapshotCard extends StatelessWidget {
  const _MorningSnapshotCard({required this.confirmation});

  final DailyLogConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final morning = confirmation.morning;

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.wb_sunny_outlined, title: 'MORNING'),
          AppSpacing.gapMD,
          if (morning == null)
            const Text('Not recorded')
          else ...[
            const Text('Recorded'),
            Text('Weight: ${morning.weight.toStringAsFixed(1)} kg'),
            if (morning.bodyFat != null)
              Text('Body Fat: ${morning.bodyFat!.toStringAsFixed(1)} %'),
            Text('Sleep: ${_formatSleep(morning.sleepDuration)}'),
            Text('Work: ${morning.workHours.toStringAsFixed(1)} h'),
          ],
        ],
      ),
    );
  }
}

class _FoodSnapshotCard extends StatelessWidget {
  const _FoodSnapshotCard({required this.confirmation});

  final DailyLogConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final food = confirmation.food;

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.restaurant_outlined, title: 'FOOD'),
          AppSpacing.gapMD,
          if (food == null)
            const Text('Not recorded')
          else ...[
            Text('Meals: ${food.mealCount}'),
            Text('Calories: ${_formatWhole(food.calories)} kcal'),
            Text('Protein: ${food.protein.toStringAsFixed(1)} g'),
            Text('Fat: ${food.fat.toStringAsFixed(1)} g'),
            Text('Carbs: ${food.carbohydrates.toStringAsFixed(1)} g'),
            Text('Water: ${_formatWhole(food.hydrationMl)} mL'),
          ],
        ],
      ),
    );
  }
}

class _ActivitySnapshotCard extends StatelessWidget {
  const _ActivitySnapshotCard({required this.confirmation});

  final DailyLogConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final activity = confirmation.activity;

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.directions_walk_outlined,
            title: 'ACTIVITY',
          ),
          AppSpacing.gapMD,
          Text(
            activity == null || !activity.isRecorded
                ? 'Not recorded'
                : '${_formatWhole(activity.steps.toDouble())} steps',
          ),
        ],
      ),
    );
  }
}

class _TrainingSnapshotCard extends StatelessWidget {
  const _TrainingSnapshotCard({required this.confirmation});

  final DailyLogConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final training = confirmation.training;

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.fitness_center_outlined,
            title: 'TRAINING',
          ),
          AppSpacing.gapMD,
          Text(
            training == null
                ? 'Not recorded'
                : training.completed
                ? 'Completed'
                : 'Not completed',
          ),
        ],
      ),
    );
  }
}

String _formatSleep(Duration duration) {
  final minutes = duration.inMinutes.remainder(60);
  return '${duration.inHours}h ${minutes.toString().padLeft(2, '0')}m';
}

String _formatWhole(double value) => value.round().toString().replaceAllMapped(
      RegExp(r'(?<!^)(?=(\d{3})+$)'),
      (_) => ',',
    );
