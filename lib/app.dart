import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/command_center/command_center_page.dart';

class OperationRebootApp extends StatelessWidget {
  const OperationRebootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'Operation Reboot',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.darkTheme,
  home: const CommandCenterPage(),
);
  }
}