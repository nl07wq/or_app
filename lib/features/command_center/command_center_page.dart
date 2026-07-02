import 'package:flutter/material.dart';

import '../../core/widgets/operation_button.dart';
import '../../core/widgets/section_title.dart';
import 'operation_status_card.dart';
import 'commander_intent_card.dart';
import '../../core/models/operation_data.dart';
import '../../data/operation_sample.dart';
import '../morning_routine/morning_routine_page.dart';
import '../food/food_entry_page.dart';
import '../training/training_input_page.dart';

class CommandCenterPage extends StatelessWidget {
  const CommandCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final operation = sampleOperation;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Operation Reboot"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(title: "COMMAND CENTER"),

            OperationStatusCard(
              status: operation.status,
              description: operation.description,
              operationId: operation.operationId,
              statusColor: Colors.green,
            ),

            CommanderIntentCard(intent: operation.commanderIntent),

            const Spacer(),

            OperationButton(
              text: "▶ Morning Routine",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MorningRoutinePage()),
                );
              },
            ),

            const SizedBox(height: 12),
            
            OperationButton(
              text: "🍱 Food Input",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodEntryPage()),
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            OperationButton(
              text: "🏋️ Training",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrainingInputPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
