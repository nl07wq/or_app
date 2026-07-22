import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_text_field.dart';

class TrainingSetRow extends StatelessWidget {
  final int setNo;

  final TextEditingController weightController;
  final TextEditingController repsController;

  const TrainingSetRow({
    super.key,
    required this.setNo,
    required this.weightController,
    required this.repsController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.gapSM,

        Row(
          children: [
            Expanded(
              child: OperationTextField(
                controller: weightController,
                label: 'Weight',
                hint: 'kg',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),

            AppSpacing.gapMD,

            Expanded(
              child: OperationTextField(
                controller: repsController,
                label: 'Reps',
                hint: '回',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        AppSpacing.gapSM,

        Row(
          children: [
            for (final amount in const [1, 5, 10]) ...[
              if (amount != 1) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _addReps(amount),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text('+$amount'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _addReps(int amount) {
    final current = int.tryParse(repsController.text.trim()) ?? 0;
    final text = (current + amount).toString();
    repsController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
