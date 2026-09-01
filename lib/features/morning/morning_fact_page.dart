import 'package:flutter/material.dart';

import '../../core/models/work_type.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../operation_date/services/operation_date_service.dart';
import '../command_center/pages/command_center_page.dart';
import '../command_center/widgets/brief_debrief_page.dart';
import '../report_sync/models/report_sync_envelope.dart';
import '../report_sync/pages/report_sync_exchange_page.dart';

import 'services/morning_fact_initializer.dart';
import 'services/morning_submit_service.dart';
import 'widgets/body_card.dart';
import 'widgets/foot_card.dart';
import 'widgets/memo_input_card.dart';
import 'widgets/morning_submit_button.dart';
import 'widgets/recovery_card.dart';
import 'widgets/work_card.dart';

import '../../core/models/morning_data.dart';

typedef DailyBriefCreationPageBuilder = Widget Function(VoidCallback onApplied);

class MorningFactPage extends StatefulWidget {
  const MorningFactPage({
    super.key,
    this.data,
    this.operationDateService = const OperationDateService(),
    this.returnAfterSave = false,
    this.dailyBriefCreationPageBuilder,
  });

  final MorningData? data;
  final OperationDateService operationDateService;
  final bool returnAfterSave;
  final DailyBriefCreationPageBuilder? dailyBriefCreationPageBuilder;

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

      weightController.text = data.weight?.toString() ?? '';
      bodyFatController.text = data.weight == null
          ? ''
          : data.bodyFat?.toString() ?? '';
      weightUnmeasured = data.weight == null;

      sleepController.text = data.sleepHours == null
          ? ''
          : _formatTime(data.sleepHours!);
      sleepScoreController.text = data.sleepScore?.toString() ?? '';
      sleepTimeUnmeasured = data.sleepHours == null;
      selectedSleepType = data.sleepType;

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
      final values = await const MorningFactInitializer().initialize(
        beforeOrOnLocalDate: operationLocalDate,
      );
      if (!mounted) return;

      weightController.text = values.weight;
      bodyFatController.text = values.bodyFat;
      sleepController.text = values.sleep;
      sleepScoreController.text = values.sleepScore;

      setState(() {
        if (values.hasPreviousRecord) {
          weightUnmeasured = values.weight.isEmpty;
          if (weightUnmeasured) {
            bodyFatController.clear();
          }
          sleepTimeUnmeasured = values.sleep.isEmpty;
        }
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
  SleepType selectedSleepType = SleepType.sleep;
  bool weightUnmeasured = false;
  bool sleepTimeUnmeasured = false;
  String? _measuredWeight;
  String? _measuredBodyFat;
  String? _measuredSleepTime;
  String? _measuredSleepScore;

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

  Future<bool> _confirmDailyBriefCreation() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('DAILY BRIEF'),
          content: const Text('DAILY BRIEFを作成できます。\n今すぐ作成しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('YES'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('NO'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openDailyBriefCreation() async {
    var applied = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            widget.dailyBriefCreationPageBuilder?.call(() => applied = true) ??
            ReportSyncExchangePage(
              exchangeType: ReportSyncExchangeType.morningBrief,
              onApplied: () => applied = true,
            ),
      ),
    );
    if (!mounted) return;
    if (applied) {
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.commandCenter),
          builder: (_) => const CommandCenterPage(
            initialSection: CommandCenterSection.briefDebrief,
            initialBriefDebriefTab: BriefDebriefTab.dailyBrief,
          ),
        ),
        ModalRoute.withName(AppRoutes.dashboard),
      );
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false);
  }

  void _markBodyUnmeasured() {
    _measuredWeight = weightController.text;
    _measuredBodyFat = bodyFatController.text;
    setState(() {
      weightController.clear();
      bodyFatController.clear();
      weightUnmeasured = true;
    });
  }

  void _restoreMeasuredBody() {
    setState(() {
      weightController.text = _measuredWeight ?? '';
      bodyFatController.text = _measuredBodyFat ?? '';
      weightUnmeasured = false;
    });
  }

  void _markSleepTimeUnmeasured() {
    _measuredSleepTime = sleepController.text;
    _measuredSleepScore = sleepScoreController.text;
    setState(() {
      sleepController.clear();
      sleepScoreController.clear();
      sleepTimeUnmeasured = true;
    });
  }

  void _restoreMeasuredSleepTime() {
    setState(() {
      sleepController.text = _measuredSleepTime ?? '';
      sleepScoreController.text = _measuredSleepScore ?? '';
      sleepTimeUnmeasured = false;
    });
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
                      weightUnmeasured: weightUnmeasured,
                      onWeightUnmeasured: _markBodyUnmeasured,
                      onWeightMeasured: _restoreMeasuredBody,
                    ),

                    AppSpacing.gapMD,

                    RecoveryCard(
                      sleepController: sleepController,
                      sleepScoreController: sleepScoreController,
                      sleepType: selectedSleepType,
                      sleepTimeUnmeasured: sleepTimeUnmeasured,
                      onSleepTimeUnmeasured: _markSleepTimeUnmeasured,
                      onSleepTimeMeasured: _restoreMeasuredSleepTime,
                      onSleepTypeChanged: (value) {
                        setState(() {
                          selectedSleepType = value;
                          if (value == SleepType.nap) {
                            sleepScoreController.clear();
                          }
                        });
                      },
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
                            sleepType: selectedSleepType,
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

                          if (!widget.isEdit &&
                              await _confirmDailyBriefCreation()) {
                            if (!context.mounted) return;
                            await _openDailyBriefCreation();
                            return;
                          }

                          if (!context.mounted) return;

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
