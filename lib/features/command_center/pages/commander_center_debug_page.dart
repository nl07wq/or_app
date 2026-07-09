import 'package:flutter/material.dart';

import '../core/command_engine.dart';
import '../core/morning_brief_builder.dart';
import '../models/morning_fact.dart';
import '../widgets/operation_action_card.dart';
import '../widgets/operation_status_badge.dart';

class CommanderCenterDebugPage extends StatelessWidget {
  const CommanderCenterDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    const fact = MorningFact(
      weight: 106.0,
      sleepMinutes: 420,
      fatigue: 2,
      plantarPain: 1,
    );

    final result = CommandEngine(morningFact: fact).buildResult();

    final brief = const MorningBriefBuilder().build(result, fact);

    return Scaffold(
      appBar: AppBar(title: const Text('Commander Center Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Situation'),
              subtitle: Text(brief.situation),
            ),
          ),

          Card(
            child: ListTile(
              title: const Text("Today's Summary"),
              subtitle: Text(brief.summary),
            ),
          ),

          Card(
            child: ListTile(
              title: const Text('Operation Status'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OperationStatusBadge(status: brief.operationStatus),
              ),
            ),
          ),

          Card(
            child: ListTile(
              title: const Text('Commander Intent'),
              subtitle: Text(brief.commanderIntent),
            ),
          ),

          OperationActionCard(
            action: brief.actions.isEmpty ? null : brief.actions.first,
          ),

          const SizedBox(height: 16),

          const Text(
            'States',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          ...result.states.map(
            (state) => Card(
              child: ListTile(
                title: Text(state.module),
                subtitle: Text(state.message),
                trailing: Text(state.status.name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
