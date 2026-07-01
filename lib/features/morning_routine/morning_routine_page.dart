import 'package:flutter/material.dart';

import 'body_card.dart';
import 'sleep_input_card.dart';
import 'sleep_score_input_card.dart';
import 'work_card.dart';
import 'memo_input_card.dart';
import 'morning_submit_button.dart';
import 'recovery_card.dart';

import '../../core/models/morning_data.dart';
import '../../core/models/work_type.dart';
import '../../core/services/morning_record_service.dart';
import '../morning_history/morning_history_page.dart';

class MorningRoutinePage extends StatefulWidget {
  const MorningRoutinePage({super.key});

  @override
  State<MorningRoutinePage> createState() => _MorningRoutinePageState();
}

class _MorningRoutinePageState extends State<MorningRoutinePage> {
  final weightController = TextEditingController();
  final bodyFatController = TextEditingController();
  final sleepController = TextEditingController();
  final sleepScoreController = TextEditingController();
  final workController = TextEditingController();
  final memoController = TextEditingController();
  WorkType selectedWorkType = WorkType.work;

  double? _parseTime(String text) {
    final parts = text.trim().split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    if (minute < 0 || minute >= 60) return null;

    return hour + minute / 60;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("入力エラー"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Morning Routine")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BodyCard(
                weightController: weightController,
                bodyFatController: bodyFatController,
              ),

              const SizedBox(height: 16),

              RecoveryCard(
                sleepController: sleepController,
                sleepScoreController: sleepScoreController,
              ),

              const SizedBox(height: 16),

              WorkCard(
                workType: selectedWorkType,
                workController: workController,
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedWorkType = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              MemoInputCard(controller: memoController),

              const SizedBox(height: 24),

              MorningSubmitButton(
                onPressed: () async {
                  if (weightController.text.trim().isEmpty) {
                    _showError("体重を入力してください");
                    return;
                  }

                  if (sleepController.text.trim().isEmpty) {
                    _showError("睡眠時間を入力してください");
                    return;
                  }

                  if (workController.text.trim().isEmpty) {
                    _showError("勤務時間を入力してください");
                    return;
                  }

                  final weight = double.tryParse(weightController.text.trim());

                  if (weight == null) {
                    _showError("体重は数字で入力してください");
                    return;
                  }

                  final bodyFat = double.tryParse(
                    bodyFatController.text.trim(),
                  );

                  if (bodyFat == null) {
                    _showError("体脂肪率を入力してください");
                    return;
                  }

                  final sleep = _parseTime(sleepController.text);

                  if (sleep == null) {
                    _showError("睡眠時間は 7:30 の形式で入力してください");
                    return;
                  }

                  final sleepScore = int.tryParse(
                    sleepScoreController.text.trim(),
                  );

                  if (sleepScore == null) {
                    _showError("睡眠スコアを入力してください");
                    return;
                  }

                  final work = _parseTime(workController.text);

                  if (work == null) {
                    _showError("勤務時間は 8:30 の形式で入力してください");
                    return;
                  }

                  final morningData = MorningData(
                    date: DateTime.now().toIso8601String(),
                    weight: weight,
                    bodyFat: bodyFat,
                    sleepHours: sleep,
                    sleepScore: sleepScore,
                    workType: selectedWorkType,
                    workHours: work,
                    memo: memoController.text.trim(),
                  );

                  await MorningRecordService.save(morningData);

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MorningHistoryPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
