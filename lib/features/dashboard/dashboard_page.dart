import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';

import 'widgets/status_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: const [
          AppSpacing.gapLG,

          StatusCard(),

          AppSpacing.gapXL,

          SectionHeader(icon: Icons.dashboard, title: 'QUICK ACCESS'),

          AppSpacing.gapSM,

          OperationDescription(
            text:
                '本日のOperation状況を確認し、'
                '\n'
                '各モジュールへアクセスします。',
          ),

          AppSpacing.gapLG,

          _MorningButton(),

          AppSpacing.gapMD,

          _FoodButton(),

          AppSpacing.gapMD,

          _TrainingButton(),

          AppSpacing.gapMD,

          _CommandCenterButton(),

          AppSpacing.gapMD,
        ],
      ),
    );
  }
}

class _MorningButton extends StatelessWidget {
  const _MorningButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.play_arrow,
      text: 'Morning',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.morning);
      },
    );
  }
}

class _FoodButton extends StatelessWidget {
  const _FoodButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.restaurant,
      text: 'Food',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.food);
      },
    );
  }
}

class _TrainingButton extends StatelessWidget {
  const _TrainingButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.fitness_center,
      text: 'Training',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.training);
      },
    );
  }
}

class _CommandCenterButton extends StatelessWidget {
  const _CommandCenterButton();

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.flag,
      text: 'Command Center',
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.commandCenter);
      },
    );
  }
}
