import 'package:flutter/material.dart';

import '../../core/models/morning_data.dart';
import '../../core/models/work_type.dart';
import '../../core/repositories/morning_repository.dart';
import '../../core/theme/app_spacing.dart';

import 'morning_history_page.dart';

import 'widgets/body_card.dart';
import 'widgets/memo_input_card.dart';
import 'widgets/morning_submit_button.dart';
import 'widgets/recovery_card.dart';
import 'widgets/foot_card.dart';
import 'widgets/bowel_card.dart';
import 'widgets/work_card.dart';

class MorningFactPage extends StatefulWidget {
  const MorningFactPage({super.key});

  @override
  State<MorningFactPage> createState() => _MorningFactPageState();
}

class _MorningFactPageState extends State<MorningFactPage> {
  @override
  void initState() {
    super.initState();

    weightController.text = "100.0";
  }

  // Controllers
  final weightController = TextEditingController();
  final bodyFatController = TextEditingController();

  final sleepController = TextEditingController();
  final sleepScoreController = TextEditingController();

  final footPainController = TextEditingController(); // ←これを追加

  final bowelAmountController = TextEditingController();
  final bowelShapeController = TextEditingController();

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
        title: const Text('入力エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Morning Fact')),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BodyCard(
                weightController: weightController,
                bodyFatController: bodyFatController,
              ),

              AppSpacing.gapMD,

              RecoveryCard(
                sleepController: sleepController,
                sleepScoreController: sleepScoreController,
              ),

              AppSpacing.gapMD,

              FootCard(controller: footPainController),

              AppSpacing.gapMD,

              BowelCard(
                amountController: bowelAmountController,
                shapeController: bowelShapeController,
              ),

              AppSpacing.gapMD,

              WorkCard(
                workType: selectedWorkType,
                workController: workController,
                onChanged: (value) {
                  if (value == null) return;

                  FocusManager.instance.primaryFocus?.unfocus();

                  setState(() {
                    selectedWorkType = value;
                  });
                },
              ),

              AppSpacing.gapMD,

              MemoInputCard(controller: memoController),

              AppSpacing.gapXL,

              MorningSubmitButton(
                onPressed: () async {
                  if (weightController.text.trim().isEmpty) {
                    _showError('体重を入力してください');
                    return;
                  }

                  if (sleepController.text.trim().isEmpty) {
                    _showError('睡眠時間を入力してください');
                    return;
                  }

                  if ((selectedWorkType == WorkType.work ||
                          selectedWorkType == WorkType.halfDay) &&
                      workController.text.trim().isEmpty) {
                    _showError('勤務時間を入力してください');
                    return;
                  }

                  final weight = double.tryParse(weightController.text.trim());

                  if (weight == null) {
                    _showError('体重は数字で入力してください');
                    return;
                  }

                  final bodyFat = double.tryParse(
                    bodyFatController.text.trim(),
                  );

                  if (bodyFat == null) {
                    _showError('体脂肪率を入力してください');
                    return;
                  }

                  final sleep = _parseTime(sleepController.text);

                  if (sleep == null) {
                    _showError('睡眠時間は 7:30 の形式で入力してください');
                    return;
                  }

                  final sleepScore = int.tryParse(
                    sleepScoreController.text.trim(),
                  );

                  if (sleepScore == null) {
                    _showError('睡眠スコアを入力してください');
                    return;
                  }

                  double work = 0;

                  if (selectedWorkType == WorkType.work ||
                      selectedWorkType == WorkType.halfDay) {
                    final parsed = _parseTime(workController.text);

                    if (parsed == null) {
                      _showError('勤務時間は 8:30 の形式で入力してください');
                      return;
                    }

                    work = parsed;
                  }

                  final morningData = MorningData(
                    date: DateTime.now().toIso8601String(),
                    weight: weight,
                    bodyFat: bodyFat,
                    sleepHours: sleep,
                    sleepScore: sleepScore,
                    footPain: int.tryParse(footPainController.text) ?? 3,
                    bowelAmount: int.tryParse(bowelAmountController.text) ?? 2,

                    bowelShape: int.tryParse(bowelAmountController.text) == 0
                        ? 0
                        : int.tryParse(bowelShapeController.text) ?? 2,
                    workType: selectedWorkType,
                    workHours: work,
                    memo: memoController.text.trim(),
                  );

                  await MorningRepository.save(morningData);

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
