import 'dart:async';

import 'package:flutter/material.dart';

import 'core/navigation/app_routes.dart';
import 'core/services/daily_state_restore_service.dart';
import 'core/theme/app_theme.dart';

import 'features/dashboard/dashboard_page.dart';
import 'features/morning/morning_page.dart';
import 'features/food/food_page.dart';
import 'features/training/training_page.dart';
import 'features/command_center/pages/command_center_page.dart';

class OperationRebootApp extends StatefulWidget {
  const OperationRebootApp({super.key});

  @override
  State<OperationRebootApp> createState() => _OperationRebootAppState();
}

class _OperationRebootAppState extends State<OperationRebootApp> {
  @override
  void initState() {
    super.initState();
    unawaited(DailyStateRestoreService.restore());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operation Reboot',
      debugShowCheckedModeBanner: false,
      theme: StandardTheme.theme,
      initialRoute: AppRoutes.dashboard,

      routes: {
        AppRoutes.dashboard: (_) => const DashboardPage(),
        AppRoutes.morning: (_) => const MorningPage(),
        AppRoutes.food: (_) => const FoodPage(),
        AppRoutes.training: (_) => const TrainingPage(),
        AppRoutes.commandCenter: (_) => const CommandCenterPage(),
      },
    );
  }
}
