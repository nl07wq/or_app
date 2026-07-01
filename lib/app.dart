import 'package:flutter/material.dart';

import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';

import 'features/dashboard/dashboard_page.dart';
import 'features/morning_routine/morning_routine_page.dart';
import 'features/food/food_input_page.dart';
import 'features/training/training_input_page.dart';
import 'features/morning_history/morning_history_page.dart';
import 'features/command_center/command_center_page.dart';

class OperationRebootApp extends StatelessWidget {
  const OperationRebootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operation Reboot',
      debugShowCheckedModeBanner: false,
      theme: StandardTheme.theme,
      initialRoute: AppRoutes.dashboard,

      routes: {
        AppRoutes.dashboard: (_) => const DashboardPage(),
        AppRoutes.morningRoutine: (_) => const MorningRoutinePage(),
        AppRoutes.food: (_) => const FoodInputPage(),
        AppRoutes.training: (_) => const TrainingInputPage(),
        AppRoutes.morningHistory: (_) => const MorningHistoryPage(),
        AppRoutes.commandCenter: (_) => const CommandCenterPage(),
      },
    );
  }
}
