import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

import '../../../core/widgets/inputs/hud/hud_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_input_card.dart';

class BodyCard extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController bodyFatController;
  final bool weightUnmeasured;
  final bool bodyFatUnmeasured;
  final VoidCallback onWeightUnmeasured;
  final VoidCallback onWeightMeasured;
  final VoidCallback onBodyFatUnmeasured;
  final VoidCallback onBodyFatMeasured;

  const BodyCard({
    super.key,
    required this.weightController,
    required this.bodyFatController,
    required this.weightUnmeasured,
    required this.bodyFatUnmeasured,
    required this.onWeightUnmeasured,
    required this.onWeightMeasured,
    required this.onBodyFatUnmeasured,
    required this.onBodyFatMeasured,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.monitor_weight, title: "BODY"),

          const SizedBox(height: 20),

          if (weightUnmeasured)
            _UnmeasuredField(title: 'Weight', onMeasure: onWeightMeasured)
          else ...[
            HUDInputCard(
              title: "Weight",
              unit: "kg",
              controller: weightController,
              min: 40,
              max: 180,
              step: 0.1,
              initialValue: 100,
              headerAction: _UnmeasuredAction(
                key: const ValueKey('Weight-unmeasured-toggle'),
                onPressed: onWeightUnmeasured,
              ),
            ),
          ],

          const SizedBox(height: 32),

          if (bodyFatUnmeasured)
            _UnmeasuredField(
              title: 'Body Fat',
              onMeasure: weightUnmeasured ? null : onBodyFatMeasured,
            )
          else ...[
            WheelInputCard(
              title: "Body Fat",
              unit: "%",
              controller: bodyFatController,
              min: 0,
              max: 60,
              step: 0.1,
              initialValue: 20,
              headerAction: _UnmeasuredAction(
                key: const ValueKey('Body Fat-unmeasured-toggle'),
                onPressed: onBodyFatUnmeasured,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnmeasuredField extends StatelessWidget {
  const _UnmeasuredField({required this.title, required this.onMeasure});

  final String title;
  final VoidCallback? onMeasure;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      if (onMeasure == null)
        const Text(
          '未計測',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.lightBlueAccent,
          ),
        )
      else
        TextButton(
          key: ValueKey('$title-unmeasured-toggle'),
          onPressed: onMeasure,
          child: const Text(
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

class _UnmeasuredAction extends StatelessWidget {
  const _UnmeasuredAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(onPressed: onPressed, child: const Text('未計測')),
  );
}
