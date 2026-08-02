import 'dart:async';

import 'package:flutter/material.dart';

import 'core/navigation/app_routes.dart';
import 'core/services/startup_initialization_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/startup_gate.dart';

import 'features/dashboard/dashboard_page.dart';
import 'features/dashboard/log_confirmation_detail_page.dart';
import 'features/dashboard/log_confirmation_review_page.dart';
import 'features/morning/morning_page.dart';
import 'features/food/food_page.dart';
import 'features/activity/activity_page.dart';
import 'features/training/training_page.dart';
import 'features/command_center/pages/command_center_page.dart';
import 'features/import_export/backup_restore_page.dart';
import 'features/sync/pages/orlo_sync_page.dart';
import 'features/system/pages/operation_sync_page.dart';
import 'features/system/pages/about_page.dart';
import 'features/system/pages/profile_page.dart';
import 'features/system/pages/system_page.dart';

class OperationRebootApp extends StatefulWidget {
  final StartupInitializationService? initializationService;

  const OperationRebootApp({super.key, this.initializationService});

  @override
  State<OperationRebootApp> createState() => _OperationRebootAppState();
}

class _OperationRebootAppState extends State<OperationRebootApp> {
  late final StartupInitializationService _initializationService;

  @override
  void initState() {
    super.initState();
    _initializationService =
        widget.initializationService ?? StartupInitializationService();
    unawaited(_initializationService.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operation Reboot',
      debugShowCheckedModeBanner: false,
      theme: StandardTheme.theme,
      initialRoute: AppRoutes.dashboard,
      builder: (context, child) => StartupGate(
        service: _initializationService,
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
        AppRoutes.backupRestore: (_) => const BackupRestorePage(),
        AppRoutes.orloSync: (_) => OrloSyncPage(),
        AppRoutes.profile: (_) => const ProfilePage(),
        AppRoutes.about: (_) => const AboutPage(),
        AppRoutes.system: (_) => const SystemPage(),
        AppRoutes.operationSync: (_) => const OperationSyncPage(),
      },
    );
  }
}
