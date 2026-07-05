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
      ],
    );
  }
}
