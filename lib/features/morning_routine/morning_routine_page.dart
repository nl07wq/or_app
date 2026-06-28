import 'package:flutter/material.dart';
import 'weight_input_card.dart';
import 'sleep_input_card.dart';
import 'work_input_card.dart';
import 'morning_submit_button.dart';
import '../../data/morning_data_sample.dart';
import '../../core/models/morning_data.dart';
import 'dart:convert';
import '../../core/services/morning_record_service.dart';
import '../morning_history/morning_history_page.dart';

class MorningRoutinePage extends StatefulWidget {
  const MorningRoutinePage({super.key});

  @override
  State<MorningRoutinePage> createState() => _MorningRoutinePageState();
}

class _MorningRoutinePageState extends State<MorningRoutinePage> {
  final weightController = TextEditingController();
  final sleepController = TextEditingController();
  final workController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final data = sampleMorningData;

    weightController.text = data.weight.toString();
    sleepController.text = data.sleepHours.toString();
    workController.text = data.workMemo;

    return Scaffold(
      appBar: AppBar(title: const Text("Morning Routine")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WeightInputCard(controller: weightController),
            SleepInputCard(controller: sleepController),

            const SizedBox(height: 16),

            WorkInputCard(controller: workController),
            const SizedBox(height: 24),

            MorningSubmitButton(
              onPressed: () {
                final morningData = MorningData(
                  date: DateTime.now().toIso8601String().split('T')[0],
                  weight: double.parse(weightController.text),
                  sleepHours: double.parse(sleepController.text),
                  workMemo: workController.text,
                );

                MorningRecordService.save(morningData);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MorningHistoryPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
