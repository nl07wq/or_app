import 'package:flutter/material.dart';

import '../../core/models/work_type.dart';
import '../../core/theme/app_spacing.dart';

import 'morning_history_page.dart';

import 'widgets/body_card.dart';
import 'widgets/memo_input_card.dart';
import 'widgets/morning_submit_button.dart';
import 'widgets/recovery_card.dart';
import 'widgets/foot_card.dart';
import 'widgets/bowel_card.dart';
import 'widgets/work_card.dart';

import 'services/morning_submit_service.dart';
import '../../core/models/morning_data.dart';

class MorningFactPage extends StatefulWidget {
  const MorningFactPage({super.key, this.data});

  final MorningData? data;

  bool get isEdit => data != null;

  @override
  State<MorningFactPage> createState() => _MorningFactPageState();
}

class _MorningFactPageState extends State<MorningFactPage> {
  @override
  void initState() {
    super.initState();

    if (widget.data != null) {
      final data = widget.data!;

      weightController.text = data.weight.toString();
      bodyFatController.text = data.bodyFat.toString();

      sleepController.text = data.sleepHours.toString();
      sleepScoreController.text = data.sleepScore.toString();

      footPainController.text = data.footPain.toString();

      bowelAmountController.text = data.bowelAmount.toString();
      bowelShapeController.text = data.bowelShape.toString();

      selectedWorkType = data.workType;

      workStartController.text = data.workStart;
      workEndController.text = data.workEnd;
      workBreakController.text = data.workBreak;

      memoController.text = data.memo;
    } else {
      // 新規入力時のデフォルト値
      workStartController.text = "11:00";
      workEndController.text = "18:00";
      workBreakController.text = "01:00";
    }
  }

  // Controllers
  final weightController = TextEditingController();
  final bodyFatController = TextEditingController();

  final sleepController = TextEditingController();
  final sleepScoreController = TextEditingController();

  final footPainController = TextEditingController();

  final bowelAmountController = TextEditingController();
  final bowelShapeController = TextEditingController();

  final workStartController = TextEditingController();

  final workEndController = TextEditingController();

  final workBreakController = TextEditingController();

  final memoController = TextEditingController();

  WorkType selectedWorkType = WorkType.work;

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
                onChanged: (value) {
                  setState(() {
                    selectedWorkType = value;
                  });
                },
                startController: workStartController,
                endController: workEndController,
                breakController: workBreakController,
              ),

              AppSpacing.gapMD,

              MemoInputCard(controller: memoController),

              AppSpacing.gapXL,

              MorningSubmitButton(
                onPressed: () async {
                  final error = await MorningSubmitService.submit(
                    workType: selectedWorkType,
                    weightText: weightController.text,
                    bodyFatText: bodyFatController.text,
                    sleepText: sleepController.text,
                    sleepScoreText: sleepScoreController.text,
                    footPainText: footPainController.text,
                    bowelAmountText: bowelAmountController.text,
                    bowelShapeText: bowelShapeController.text,
                    workStart: workStartController.text,
                    workEnd: workEndController.text,
                    workBreak: workBreakController.text,
                    memo: memoController.text,
                  );

                  if (!context.mounted) return;

                  if (error != null) {
                    _showError(error);
                    return;
                  }

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

  @override
  void dispose() {
    weightController.dispose();
    bodyFatController.dispose();

    sleepController.dispose();
    sleepScoreController.dispose();

    footPainController.dispose();

    bowelAmountController.dispose();
    bowelShapeController.dispose();

    workStartController.dispose();
    workEndController.dispose();
    workBreakController.dispose();

    memoController.dispose();

    super.dispose();
  }
}
