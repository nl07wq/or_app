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

        Align(
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final amount in const [-10, -5, -1]) ...[
                if (amount != -10) const SizedBox(width: AppSpacing.sm),
                _repQuickButton(amount),
              ],
              const SizedBox(width: AppSpacing.xl),
              for (final amount in const [1, 5, 10]) ...[
                if (amount != 1) const SizedBox(width: AppSpacing.sm),
                _repQuickButton(amount),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _repQuickButton(int amount) {
    return SizedBox(
      width: 40,
      height: 36,
      child: ActionChip(
        label: Text(amount > 0 ? '+$amount' : '$amount'),
        onPressed: () => _adjustReps(amount),
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _adjustReps(int amount) {
    final current = int.tryParse(repsController.text.trim()) ?? 0;
    final adjusted = current + amount;
    final text = (adjusted < 0 ? 0 : adjusted).toString();
    repsController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
