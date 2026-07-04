import 'package:flutter/material.dart';

import '../../core/models/training_data.dart';
import '../../core/services/training_record_service.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/section_header.dart';

class TrainingEntryPage extends StatefulWidget {
  const TrainingEntryPage({super.key});

  @override
  State<TrainingEntryPage> createState() => _TrainingEntryPageState();
}

class _TrainingEntryPageState extends State<TrainingEntryPage> {
  final exerciseController = TextEditingController();
  final setsController = TextEditingController();
  final repsController = TextEditingController();
  final weightController = TextEditingController();
  final memoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Entry')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.fitness_center,
              title: 'TRAINING ENTRY',
            ),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  '本日のトレーニング内容を入力して\n'
                  '記録します。',
            ),

            AppSpacing.gapMD,

            OperationCard(
              child: Column(
                children: [
                  OperationTextField(
                    controller: exerciseController,
                    label: 'Exercise',
                  ),

                  AppSpacing.gapMD,

                  OperationTextField(
                    controller: setsController,
                    label: 'Sets',
                    keyboardType: TextInputType.number,
                  ),

                  AppSpacing.gapMD,

                  OperationTextField(
                    controller: repsController,
                    label: 'Reps',
                    keyboardType: TextInputType.number,
                  ),

                  AppSpacing.gapMD,

                  OperationTextField(
                    controller: weightController,
                    label: 'Weight (kg)',
                    keyboardType: TextInputType.number,
                  ),

                  AppSpacing.gapMD,

                  OperationTextField(
                    controller: memoController,
                    label: 'Memo',
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            AppSpacing.gapXL,

            OperationButton(
              icon: Icons.save,
              text: 'Save Training',
              onPressed: () {
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

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Training saved')));

                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
