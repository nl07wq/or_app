import 'dart:async';

import 'package:flutter/material.dart';

import 'core/navigation/app_routes.dart';
import 'core/services/startup_diagnostic.dart';
import 'core/services/startup_initialization_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/boot_sequence.dart';
import 'core/widgets/startup_gate.dart';

import 'features/dashboard/dashboard_page.dart';
import 'features/dashboard/log_confirmation_detail_page.dart';
import 'features/dashboard/log_confirmation_review_page.dart';
import 'features/morning/morning_page.dart';
import 'features/food/food_page.dart';
import 'features/activity/activity_page.dart';
import 'features/training/training_page.dart';
import 'features/command_center/pages/command_center_page.dart';
import 'features/body_history/pages/body_history_page.dart';
import 'features/body_history/pages/data_center_history_page.dart';
import 'features/nutrition_history/pages/nutrition_history_page.dart';
import 'features/daily_aggregate/pages/daily_aggregate_records_page.dart';
import 'features/import_export/backup_restore_page.dart';
import 'features/sync/pages/orlo_sync_page.dart';
import 'features/system/pages/operation_sync_page.dart';
import 'features/system/pages/about_page.dart';
import 'features/system/pages/animations_sandbox_page.dart';
import 'features/system/pages/profile_page.dart';
import 'features/system/pages/system_page.dart';
import 'features/system/pages/device_transfer_page.dart';
import 'features/system/pages/system_monitoring_page.dart';
import 'features/system/pages/startup_diagnostic_page.dart';

class OperationRebootApp extends StatefulWidget {
  final StartupInitializationService? initializationService;
  final BootSequenceEventListener? onBootEvent;

  const OperationRebootApp({
    super.key,
    this.initializationService,
    this.onBootEvent,
  });

  @override
  State<OperationRebootApp> createState() => _OperationRebootAppState();
}

class _OperationRebootAppState extends State<OperationRebootApp> {
  late final StartupInitializationService _initializationService;
  String? _lastInitializationMode;
  bool _appBuildRecorded = false;

  @override
  void initState() {
    super.initState();
    _initializationService =
        widget.initializationService ?? StartupInitializationService();
    _initializationService.controller.addListener(_recordInitializationState);
    _recordInitializationState();
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'APP_ROOT_INIT_STATE',
      fields: {
        'controller': identityHashCode(_initializationService.controller),
      },
    );
    StartupDiagnostic.instance.record('FLUTTER', 'INITIALIZATION_REQUESTED');
    unawaited(_initializationService.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final diagnostic = StartupDiagnostic.instance;
      diagnostic.record(
        'FLUTTER',
        'FIRST_FLUTTER_FRAME',
        presentation: diagnostic.currentPresentation,
      );
    });
  }

  void _recordInitializationState() {
    final state = _initializationService.controller.value;
    if (_lastInitializationMode == state.mode.name) return;
    _lastInitializationMode = state.mode.name;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'INITIALIZATION_STATE_CHANGED',
      state: state.mode.name,
      fields: {'stage': state.currentStage.name},
    );
  }

  @override
  void dispose() {
    StartupDiagnostic.instance.record('FLUTTER', 'APP_ROOT_DISPOSE');
    _initializationService.controller.removeListener(
      _recordInitializationState,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_appBuildRecorded) {
      _appBuildRecorded = true;
      StartupDiagnostic.instance.record('FLUTTER', 'APP_ROOT_BUILD');
    }
    return MaterialApp(
      title: 'Operation Reboot',
      debugShowCheckedModeBanner: false,
      theme: StandardTheme.theme,
      initialRoute: AppRoutes.dashboard,
      builder: (context, child) => StartupGate(
        service: _initializationService,
        showBootSequence: true,
        onBootEvent: widget.onBootEvent,
        child: child ?? const SizedBox.shrink(),
      ),

      routes: {
        AppRoutes.dashboard: (_) => const DashboardPage(),
        AppRoutes.logConfirmationReview: (context) {
          final page = ModalRoute.of(context)?.settings.arguments;
          return page is LogConfirmationReviewPage
              ? page
              : const Scaffold(
                  body: Center(child: Text('Review unavailable.')),
                );
        },
        AppRoutes.logConfirmationDetail: (context) {
          final targetDate = ModalRoute.of(context)?.settings.arguments;
          return LogConfirmationDetailPage(
            targetDate: targetDate is DateTime ? targetDate : null,
          );
        },
        AppRoutes.morning: (_) => const MorningPage(),
        AppRoutes.food: (_) => const FoodPage(),
        AppRoutes.activity: (_) => const ActivityPage(),
        AppRoutes.training: (_) => const TrainingPage(),
        AppRoutes.commandCenter: (_) => const CommandCenterPage(),
        AppRoutes.dataCenterHistory: (_) => const DataCenterHistoryPage(),
        AppRoutes.bodyHistory: (_) => const BodyHistoryPage(),
        AppRoutes.nutritionHistory: (_) => const NutritionHistoryPage(),
        AppRoutes.dailyAggregateRecords: (_) =>
            const DailyAggregateRecordsPage(),
        AppRoutes.dailyAggregateDetail: (context) {
          final operationDate = ModalRoute.of(context)?.settings.arguments;
          return operationDate is String
              ? DailyAggregateDetailPage(operationDate: operationDate)
              : const Scaffold(
                  body: Center(child: Text('Daily Aggregate unavailable.')),
                );
        },
        AppRoutes.backupRestore: (_) => const BackupRestorePage(),
        AppRoutes.orloSync: (_) => OrloSyncPage(),
        AppRoutes.profile: (_) => const ProfilePage(),
        AppRoutes.about: (_) => const AboutPage(),
        AppRoutes.system: (_) => const SystemPage(),
        AppRoutes.animationsSandbox: (_) => const AnimationsSandboxPage(),
        AppRoutes.bootSequencePreview: (_) => const BootSequencePreviewPage(),
        AppRoutes.bootSequenceCalibration: (_) =>
            const BootSequenceCalibrationPage(),
        AppRoutes.deviceTransfer: (_) => const DeviceTransferPage(),
        AppRoutes.systemMonitoring: (_) => const SystemMonitoringPage(),
        AppRoutes.startupDiagnostic: (_) => const StartupDiagnosticPage(),
        AppRoutes.operationSync: (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          return OperationSyncPage(
            stageController: arguments is DeviceTransferStageController
                ? arguments
                : null,
          );
        },
        AppRoutes.historicalTrainingImport: (_) =>
            const HistoricalTrainingImportPage(),
        AppRoutes.historicalDnsImport: (_) => const HistoricalDnsImportPage(),
      },
    );
  }
}
