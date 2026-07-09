import 'package:flutter/material.dart';

import '../models/morning_fact.dart';
import '../services/morning_brief_service.dart';
import '../widgets/commander_panel.dart';

class CommandCenterPage extends StatelessWidget {
  const CommandCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    const fact = MorningFact(
      weight: 106.0,
      sleepMinutes: 420,
      fatigue: 2,
      plantarPain: 1,
    );

    final brief = const MorningBriefService().build(fact);

    return Scaffold(
      appBar: AppBar(title: const Text('Commander Center')),
      body: CommanderPanel(brief: brief),
    );
  }
}
