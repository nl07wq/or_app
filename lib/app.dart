import 'dart:async';

import 'package:flutter/material.dart';

import 'core/navigation/app_routes.dart';
import 'core/services/device_settings_controller.dart';
import 'core/services/font_readiness_service.dart';
import 'core/services/startup_diagnostic.dart';
import 'core/widgets/global_touch_ripple.dart';
import 'core/services/startup_initialization_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/boot_sequence.dart';
import 'core/widgets/startup_gate.dart';
import 'core/widgets/loading/or_loading_theme.dart';

import 'features/dashboard/dashboard_page.dart';
import 'features/dashboard/log_confirmation_detail_page.dart';
import 'features/dashboard/log_confirmation_review_page.dart';
import 'features/morning/morning_page.dart';
import 'features/food/food_page.dart';
import 'features/activity/activity_page.dart';
import 'features/training/training_page.dart';
import 'features/training/data_center_training_history_page.dart';
import 'features/command_center/pages/command_center_page.dart';
import 'features/body_history/pages/body_history_page.dart';
import 'features/body_history/pages/data_center_history_page.dart';
import 'features/nutrition_history/pages/nutrition_history_page.dart';
import 'features/digestive_history/pages/digestive_history_page.dart';
import 'features/activity_history/pages/activity_history_page.dart';
import 'features/sleep_history/pages/sleep_history_page.dart';
import 'features/daily_aggregate/pages/daily_aggregate_records_page.dart';
import 'features/import_export/backup_restore_page.dart';
import 'features/sync/pages/orlo_sync_page.dart';
import 'features/system/pages/operation_sync_page.dart';
import 'features/system/pages/about_page.dart';
import 'features/system/pages/animations_sandbox_page.dart';
import 'features/system/pages/profile_page.dart';
import 'features/system/pages/system_page.dart';
import 'features/system/pages/device_transfer_page.dart';
import 'features/system/pages/device_settings_page.dart';
import 'features/system/pages/system_monitoring_page.dart';
import 'features/system/pages/diagnostics_page.dart';
import 'features/system/pages/dashboard_diagnostic_page.dart';
import 'features/system/pages/startup_diagnostic_page.dart';
import 'features/system/pages/body_map_svg_preview_page.dart';
import 'features/weather/weather_settings_page.dart';
import 'features/reminders/pages/reminders_page.dart';
import 'features/notifications/services/notification_profile_controller.dart';
import 'features/themes/base_camp/base_camp_dashboard_page.dart';
import 'features/themes/base_camp/base_camp_presentation.dart';
import 'features/themes/base_camp/base_camp_retro_theme.dart';

Widget _presentationEntry(BaseCampScreen screen, Widget child) =>
    _PresentationEntry(screen: screen, child: child);

/// Non-dashboard routes are also retained by Navigator, so they must listen
/// to the persisted setting instead of evaluating it only at route creation.
class _PresentationEntry extends StatelessWidget {
  const _PresentationEntry({required this.screen, required this.child});
  final BaseCampScreen screen;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DeviceSettings>(
    valueListenable: DeviceSettingsController.instance,
    builder: (context, settings, _) => KeyedSubtree(
      key: ValueKey(settings.presentationTheme),
      child: settings.presentationTheme == AppPresentationTheme.baseCamp
          ? BaseCampScreenEntry(screen: screen, child: child)
          : child,
    ),
  );
}

Widget _dashboardPresentationEntry(BaseCampScreen screen) {
  return _DashboardPresentationEntry(screen: screen);
}

/// Routes are created once by Navigator.  Listening here makes an in-place
/// SYSTEM theme selection rebuild the active HOME instead of waiting for a
/// route recreation or an application restart.
class _DashboardPresentationEntry extends StatelessWidget {
  const _DashboardPresentationEntry({required this.screen});
  final BaseCampScreen screen;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DeviceSettings>(
    valueListenable: DeviceSettingsController.instance,
    builder: (context, settings, _) => KeyedSubtree(
      key: ValueKey(settings.presentationTheme),
      child: settings.presentationTheme == AppPresentationTheme.baseCamp
          ? BaseCampScreenEntry(
              screen: screen,
              child: const BaseCampDashboardPage(),
            )
          : const DashboardPage(),
    ),
  );
}

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

class _OperationRebootAppState extends State<OperationRebootApp>
    with WidgetsBindingObserver {
  late final StartupInitializationService _initializationService;
  String? _lastInitializationMode;
  bool _appBuildRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    // Starts the local, bundled Japanese face load without introducing a
    // synthetic splash duration or blocking BootSequence.
    unawaited(FontReadinessService.instance.ensureReady());
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
    WidgetsBinding.instance.removeObserver(this);
    StartupDiagnostic.instance.record('FLUTTER', 'APP_ROOT_DISPOSE');
    _initializationService.controller.removeListener(
      _recordInitializationState,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationProfileController.instance.recoverOnForeground());
    }
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
      builder: (context, child) => ValueListenableBuilder<DeviceSettings>(
        valueListenable: DeviceSettingsController.instance,
        builder: (context, settings, _) {
          final mediaQuery = MediaQuery.maybeOf(context);
          final platformReducedMotion = mediaQuery?.disableAnimations ?? false;
          final resolvedMediaQuery = (mediaQuery ?? const MediaQueryData())
              .copyWith(
                disableAnimations: settings.resolvesReducedMotion(
                  platformReducedMotion,
                ),
              );
          final presentationTheme =
              settings.presentationTheme == AppPresentationTheme.baseCamp
              ? BaseCampRetroTheme.apply(Theme.of(context))
              : Theme.of(context);
          return Theme(
            data: presentationTheme,
            child: OrLoadingTheme(
              data: const OrLoadingThemeData(),
              child: MediaQuery(
                data: resolvedMediaQuery,
                child: GlobalTouchRipple(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      StartupGate(
                        service: _initializationService,
                        showBootSequence: true,
                        onBootEvent: widget.onBootEvent,
                        child: child ?? const SizedBox.shrink(),
                      ),
                      if (settings.brightness < 1)
                        IgnorePointer(
                          child: ColoredBox(
                            color: Colors.black.withValues(
                              alpha: (1 - settings.brightness) * .55,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),

      routes: {
        AppRoutes.dashboard: (_) =>
            _dashboardPresentationEntry(BaseCampScreen.dashboard),
        AppRoutes.finalizedDashboard: (_) =>
            _dashboardPresentationEntry(BaseCampScreen.finalizedDashboard),
        AppRoutes.logConfirmationReview: (context) {
          final page = ModalRoute.of(context)?.settings.arguments;
          return page is LogConfirmationReviewPage
              ? _presentationEntry(BaseCampScreen.logConfirmationReview, page)
              : const Scaffold(
                  body: Center(child: Text('Review unavailable.')),
                );
        },
        AppRoutes.logConfirmationDetail: (context) {
          final targetDate = ModalRoute.of(context)?.settings.arguments;
          return _presentationEntry(
            BaseCampScreen.logConfirmationDetail,
            LogConfirmationDetailPage(
              targetDate: targetDate is DateTime ? targetDate : null,
            ),
          );
        },
        AppRoutes.morning: (_) =>
            _presentationEntry(BaseCampScreen.morning, const MorningPage()),
        AppRoutes.food: (_) =>
            _presentationEntry(BaseCampScreen.food, const FoodPage()),
        AppRoutes.activity: (_) =>
            _presentationEntry(BaseCampScreen.activity, const ActivityPage()),
        AppRoutes.training: (_) =>
            _presentationEntry(BaseCampScreen.training, const TrainingPage()),
        AppRoutes.commandCenter: (_) => _presentationEntry(
          BaseCampScreen.commandCenter,
          const CommandCenterPage(),
        ),
        AppRoutes.dataCenterHistory: (_) => _presentationEntry(
          BaseCampScreen.dataCenterHistory,
          const DataCenterHistoryPage(),
        ),
        AppRoutes.bodyHistory: (_) => _presentationEntry(
          BaseCampScreen.bodyHistory,
          const BodyHistoryPage(),
        ),
        AppRoutes.nutritionHistory: (_) => _presentationEntry(
          BaseCampScreen.nutritionHistory,
          const NutritionHistoryPage(),
        ),
        AppRoutes.digestiveHistory: (_) => _presentationEntry(
          BaseCampScreen.digestiveHistory,
          const DigestiveHistoryPage(),
        ),
        AppRoutes.activityHistory: (_) => _presentationEntry(
          BaseCampScreen.activityHistory,
          const ActivityHistoryPage(),
        ),
        AppRoutes.sleepHistory: (_) => _presentationEntry(
          BaseCampScreen.sleepHistory,
          const SleepHistoryPage(),
        ),
        AppRoutes.trainingAnalyticsHistory: (_) => _presentationEntry(
          BaseCampScreen.trainingAnalyticsHistory,
          const DataCenterTrainingHistoryPage(),
        ),
        AppRoutes.dailyAggregateRecords: (_) => _presentationEntry(
          BaseCampScreen.dailyAggregateRecords,
          const DailyAggregateRecordsPage(),
        ),
        AppRoutes.dailyAggregateDetail: (context) {
          final operationDate = ModalRoute.of(context)?.settings.arguments;
          return operationDate is String
              ? _presentationEntry(
                  BaseCampScreen.dailyAggregateDetail,
                  DailyAggregateDetailPage(operationDate: operationDate),
                )
              : const Scaffold(
                  body: Center(child: Text('Daily Aggregate unavailable.')),
                );
        },
        AppRoutes.backupRestore: (_) => _presentationEntry(
          BaseCampScreen.backupRestore,
          const BackupRestorePage(),
        ),
        AppRoutes.orloSync: (_) =>
            _presentationEntry(BaseCampScreen.orloSync, OrloSyncPage()),
        AppRoutes.profile: (_) =>
            _presentationEntry(BaseCampScreen.profile, const ProfilePage()),
        AppRoutes.weatherSettings: (_) => _presentationEntry(
          BaseCampScreen.weatherSettings,
          const WeatherSettingsPage(),
        ),
        AppRoutes.reminders: (_) =>
            _presentationEntry(BaseCampScreen.reminders, const RemindersPage()),
        AppRoutes.about: (_) =>
            _presentationEntry(BaseCampScreen.about, const AboutPage()),
        AppRoutes.system: (_) =>
            _presentationEntry(BaseCampScreen.system, const SystemPage()),
        AppRoutes.deviceSettings: (_) => _presentationEntry(
          BaseCampScreen.deviceSettings,
          const DeviceSettingsPage(),
        ),
        AppRoutes.animationsSandbox: (_) => _presentationEntry(
          BaseCampScreen.animationsSandbox,
          const AnimationsSandboxPage(),
        ),
        AppRoutes.bodyMapSvgPreview: (_) => _presentationEntry(
          BaseCampScreen.bodyMapSvgPreview,
          const BodyMapSvgPreviewPage(),
        ),
        AppRoutes.bootSequencePreview: (_) => _presentationEntry(
          BaseCampScreen.bootSequencePreview,
          const BootSequencePreviewPage(),
        ),
        AppRoutes.bootSequenceCalibration: (_) => _presentationEntry(
          BaseCampScreen.bootSequenceCalibration,
          const BootSequenceCalibrationPage(),
        ),
        AppRoutes.deviceTransfer: (_) => _presentationEntry(
          BaseCampScreen.deviceTransfer,
          const DeviceTransferPage(),
        ),
        AppRoutes.systemMonitoring: (_) => _presentationEntry(
          BaseCampScreen.systemMonitoring,
          const SystemMonitoringPage(),
        ),
        AppRoutes.diagnostics: (_) => _presentationEntry(
          BaseCampScreen.diagnostics,
          const DiagnosticsPage(),
        ),
        AppRoutes.startupDiagnostic: (_) => _presentationEntry(
          BaseCampScreen.startupDiagnostic,
          const StartupDiagnosticPage(),
        ),
        AppRoutes.dashboardDiagnostic: (_) => _presentationEntry(
          BaseCampScreen.dashboardDiagnostic,
          const DashboardDiagnosticPage(),
        ),
        AppRoutes.operationSync: (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          return _presentationEntry(
            BaseCampScreen.operationSync,
            OperationSyncPage(
              stageController: arguments is DeviceTransferStageController
                  ? arguments
                  : null,
            ),
          );
        },
        AppRoutes.historicalTrainingImport: (_) => _presentationEntry(
          BaseCampScreen.historicalTrainingImport,
          const HistoricalTrainingImportPage(),
        ),
        AppRoutes.historicalDnsImport: (_) => _presentationEntry(
          BaseCampScreen.historicalDnsImport,
          const HistoricalDnsImportPage(),
        ),
      },
    );
  }
}
