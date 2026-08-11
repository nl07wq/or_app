import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

import '../../../core/widgets/inputs/hud/hud_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_input_card.dart';

class BodyCard extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController bodyFatController;
  final bool weightUnmeasured;
  final VoidCallback onWeightUnmeasured;
  final VoidCallback onWeightMeasured;

  const BodyCard({
    super.key,
    required this.weightController,
    required this.bodyFatController,
    required this.weightUnmeasured,
    required this.onWeightUnmeasured,
    required this.onWeightMeasured,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(icon: Icons.monitor_weight, title: "BODY"),
              ),
              _UnmeasuredToggle(
                key: const ValueKey('Weight-unmeasured-toggle'),
                selected: weightUnmeasured,
                onPressed: weightUnmeasured
                    ? onWeightMeasured
                    : onWeightUnmeasured,
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (weightUnmeasured)
            const _UnmeasuredValue(title: 'Weight')
          else ...[
            HUDInputCard(
              title: "Weight",
              unit: "kg",
              controller: weightController,
              min: 40,
              max: 180,
              step: 0.1,
              initialValue: 100,
            ),
          ],

          const SizedBox(height: 32),

          if (weightUnmeasured)
            const _UnmeasuredValue(title: 'Body Fat')
          else ...[
            WheelInputCard(
              title: "Body Fat",
              unit: "%",
              controller: bodyFatController,
              min: 0,
              max: 60,
              step: 0.1,
              initialValue: 20,
            ),
          ],
        ],
      ),
    );
  }
}

class _UnmeasuredToggle extends StatelessWidget {
  const _UnmeasuredToggle({
    super.key,
    required this.selected,
    required this.onPressed,
  });

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: const Text('未計測'),
    selected: selected,
    onSelected: (_) => onPressed(),
  );
}

class _UnmeasuredValue extends StatelessWidget {
  const _UnmeasuredValue({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '未計測',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.lightBlueAccent,
          ),
        ),
      ),
    ],
  );
}
