import 'package:flutter/material.dart';
import '../../core/models/training_data.dart';
import '../../core/services/training_record_service.dart';

class TrainingInputPage extends StatefulWidget {
  const TrainingInputPage({super.key});

  @override
  State<TrainingInputPage> createState() => _TrainingInputPageState();
}

class _TrainingInputPageState extends State<TrainingInputPage> {
  final exerciseController = TextEditingController();

  final setsController = TextEditingController();

  final repsController = TextEditingController();

  final weightController = TextEditingController();

  final memoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Input')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: exerciseController,
              decoration: const InputDecoration(labelText: 'Exercise'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sets'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),

            const SizedBox(height: 12),

            TextField(
  controller: memoController,
  decoration: const InputDecoration(
    labelText: 'Memo',
  ),
),

const SizedBox(height: 20),

ElevatedButton(
  onPressed: () async {
    final record = TrainingData(
      date: DateTime.now().toIso8601String().split('T').first,
      exercise: exerciseController.text,
      sets: int.tryParse(setsController.text) ?? 0,
      reps: int.tryParse(repsController.text) ?? 0,
      weight: double.tryParse(weightController.text) ?? 0,
      memo: memoController.text,
    );

TrainingRecordService.save(record);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Training saved'),
      ),
    );
  },
  child: const Text('Save'),
),
          ], // children
        ), // Column
      ), // Padding
    ); // Scaffold
  }
}