import 'package:flutter/material.dart';
import '../../core/navigation/app_routes.dart';
import 'widgets/status_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StatusCard(),

          const SizedBox(height: 24),

          Text("Quick Access", style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text("Morning Routine"),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.morningRoutine);
            },
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.restaurant),
            label: const Text("Food Input"),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.food);
            },
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.fitness_center),
            label: const Text("Training"),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.training);
            },
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.flag),
            label: const Text("Command Center"),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.commandCenter);
            },
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text("Morning History"),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.morningHistory);
            },
          ),
        ],
      ),
    );
  }
}
