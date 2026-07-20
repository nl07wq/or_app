import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/engine/food_summary.dart';
import '../../../core/engine/operation_engine.dart';
import '../../../core/engine/operation_input.dart';
import '../../../core/engine/training_summary.dart';
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
  @override
  void initState() {
    super.initState();
    unawaited(refreshFoodSummary());
    unawaited(refreshTrainingSummary());
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
                  body: CommanderPanel(analysis: analysis),
                );
              },
            );
          },
        );
      },
    );
  }
}
