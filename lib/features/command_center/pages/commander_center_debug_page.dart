import 'package:flutter/material.dart';

import '../core/command_engine.dart';
import '../models/morning_fact.dart';

class CommanderCenterDebugPage extends StatelessWidget {
  const CommanderCenterDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final result = CommandEngine(
      morningFact: const MorningFact(
        weight: 100.0,
        sleepMinutes: 420,
        fatigue: 2,
        plantarPain: 1,
      ),
    ).buildResult();

    return Scaffold(
      appBar: AppBar(title: const Text('Commander Center Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Operation Status'),
              subtitle: Text(result.operationStatus.name),
            ),
          ),

          Card(
            child: ListTile(
              title: const Text('Commander Intent'),
              subtitle: Text(result.commanderIntent),
            ),
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
