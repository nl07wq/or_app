import 'package:flutter/material.dart';

import '../../core/models/work_type.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../operation_date/services/operation_date_service.dart';

import 'services/morning_fact_initializer.dart';
import 'services/morning_submit_service.dart';
import 'widgets/body_card.dart';
import 'widgets/foot_card.dart';
import 'widgets/memo_input_card.dart';
import 'widgets/morning_submit_button.dart';
import 'widgets/recovery_card.dart';
import 'widgets/work_card.dart';

import '../../core/models/morning_data.dart';

class MorningFactPage extends StatefulWidget {
  const MorningFactPage({
    super.key,
    this.data,
    this.operationDateService = const OperationDateService(),
    this.returnAfterSave = false,
  });

  final MorningData? data;
  final OperationDateService operationDateService;
  final bool returnAfterSave;

  bool get isEdit => data != null;

  @override
  State<MorningFactPage> createState() => _MorningFactPageState();
}

class _MorningFactPageState extends State<MorningFactPage> {
  bool _initialValuesLoaded = false;
  String? _operationLocalDate;
  Object? _operationDateError;

  @override
  void initState() {
    super.initState();

    if (widget.data != null) {
      final data = widget.data!;

      weightController.text = data.weight.toString();
      bodyFatController.text = data.bodyFat.toString();

      sleepController.text = _formatTime(data.sleepHours);
      sleepScoreController.text = data.sleepScore.toString();

      footPainController.text = data.footPain.toString();

      selectedWorkType = data.workType;

      workStartController.text = data.workStart;
      workEndController.text = data.workEnd;
      workBreakController.text = data.workBreak;

      memoController.text = data.memo;
      _initialValuesLoaded = true;
    } else {
      // 新規入力時のデフォルト値
      workStartController.text = "11:00";
      workEndController.text = "18:00";
      workBreakController.text = "01:00";

      _initializeNewMorning();
    }
  }

  Future<void> _initializeNewMorning() async {
    try {
      final operationLocalDate =
          (await widget.operationDateService.current()).value;
      final values = await const MorningFactInitializer().initialize();
      if (!mounted) return;

      weightController.text = values.weight;
      bodyFatController.text = values.bodyFat;
      sleepController.text = values.sleep;
      sleepScoreController.text = values.sleepScore;

      setState(() {
        _operationLocalDate = operationLocalDate;
        _initialValuesLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _operationDateError = error);
    }
  }

  // Controllers
  final weightController = TextEditingController();
  final bodyFatController = TextEditingController();

  final sleepController = TextEditingController();
  final sleepScoreController = TextEditingController();

  final footPainController = TextEditingController();

  final workStartController = TextEditingController();

  final workEndController = TextEditingController();

  final workBreakController = TextEditingController();

  final memoController = TextEditingController();

  WorkType selectedWorkType = WorkType.work;

  String _formatTime(double hours) {
    final totalMinutes = (hours * 60).round();
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    return '$hour:${minute.toString().padLeft(2, '0')}';
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
      appBar: AppBar(title: const Text('STATUS')),
      body: _operationDateError != null
          ? const Center(child: Text('Operation Dateを取得できませんでした。'))
          : !_initialValuesLoaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                      isEdit: widget.isEdit,
                      onPressed: () async {
                        String? error;
                        try {
                          error = await MorningSubmitService.submit(
                            existingData: widget.data,
                            workType: selectedWorkType,
                            weightText: weightController.text,
                            bodyFatText: bodyFatController.text,
                            sleepText: sleepController.text,
                            sleepScoreText: sleepScoreController.text,
                            footPainText: footPainController.text,
                            workStart: workStartController.text,
                            workEnd: workEndController.text,
                            workBreak: workBreakController.text,
                            memo: memoController.text,
                            operationLocalDate: _operationLocalDate,
                          );

                          if (!context.mounted) return;

                          if (error != null) {
                            _showError(error);
                            return;
                          }

                          if (widget.returnAfterSave) {
                            Navigator.pop(context, true);
                          } else {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.dashboard,
                              (route) => false,
                            );
                          }
                        } on ConfirmedDailyLogException catch (exception) {
                          if (context.mounted) {
                            showConfirmedLogMessage(context, exception);
                          }
                          return;
                        } catch (_) {
                          if (context.mounted) {
                            _showError('Operation Dateを取得できませんでした。');
                          }
                          return;
                        }
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

    workStartController.dispose();
    workEndController.dispose();
    workBreakController.dispose();

    memoController.dispose();

    super.dispose();
  }
}
