import 'package:flutter/material.dart';
import 'weight_input_card.dart';
import 'sleep_input_card.dart';
import 'work_input_card.dart';
import 'morning_submit_button.dart';

class MorningRoutinePage extends StatelessWidget {
  const MorningRoutinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Morning Routine"),
      ),
      body: Padding(
  padding: EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WeightInputCard(),
      const SleepInputCard(),

const SizedBox(height: 16),

const WorkInputCard(),
const SizedBox(height: 24),

const MorningSubmitButton(),
    ],
  ),
),
    );
  }
}