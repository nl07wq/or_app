import 'package:flutter/material.dart';
import '../../core/navigation/app_routes.dart';
import 'widgets/status_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/operation_button.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),

          const StatusCard(),

          const SizedBox(height: 24),

          const SectionHeader(icon: Icons.dashboard, title: "QUICK ACCESS"),

          const SizedBox(height: 8),

          const OperationDescription(
            text:
                "本日のOperation状況を確認し、\n"
                "各モジュールへアクセスします。",
          ),

          const SizedBox(height: 20),

          OperationButton(
            icon: Icons.play_arrow,
            text: "Morning Routine",
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.morningRoutine);
            },
          ),

          const SizedBox(height: 12),

          OperationButton(
            icon: Icons.restaurant,
            text: "Food",
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.food);
            },
          ),

          const SizedBox(height: 12),

          OperationButton(
            icon: Icons.fitness_center,
            text: "Training",
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.training);
            },
          ),

          const SizedBox(height: 12),

          OperationButton(
            icon: Icons.flag,
            text: "Command Center",
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.commandCenter);
            },
          ),

          const SizedBox(height: 12),

          OperationButton(
            icon: Icons.history,
            text: "History",
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.morningHistory);
            },
          ),
        ],
      ),
    );
  }
}
