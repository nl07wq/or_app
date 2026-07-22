import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_text_field.dart';

class TrainingSetRow extends StatelessWidget {
  final int setNo;

  final TextEditingController weightController;
  final TextEditingController repsController;
  final bool isActive;
  final VoidCallback onActivated;

  const TrainingSetRow({
    super.key,
    required this.setNo,
    required this.weightController,
    required this.repsController,
    required this.isActive,
    required this.onActivated,
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
              child: Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) onActivated();
                },
                child: OperationTextField(
                  controller: weightController,
                  label: 'Weight',
                  hint: 'kg',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) onActivated();
                },
                child: OperationTextField(
                  controller: repsController,
                  label: 'Reps',
                  hint: '回',
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          ],
        ),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: isActive
              ? Padding(
                  key: const ValueKey('active-set-controls'),
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _contextToolbar(),
                )
              : const SizedBox(key: ValueKey('inactive-set-controls')),
        ),
      ],
    );
  }

  Widget _contextToolbar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: const [-10.0, -5.0, -2.5, 2.5, 5.0, 10.0]
                .map(
                  (amount) => _quickButton(
                    kind: 'weight',
                    amount: amount,
                    onPressed: () => _adjustWeight(amount),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: const [-10, -5, -1, 1, 5, 10]
                .map(
                  (amount) => _quickButton(
                    kind: 'reps',
                    amount: amount,
                    onPressed: () => _adjustReps(amount),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _quickButton({
    required String kind,
    required num amount,
    required VoidCallback onPressed,
  }) {
    final amountText = _formatAmount(amount);
    final label = amount > 0 ? '+$amountText' : amountText;
    return SizedBox(
      width: 50,
      height: 42,
      child: OutlinedButton(
        key: ValueKey('$kind-adjust-$amount'),
        onPressed: () {
          onActivated();
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
        child: Text(label, semanticsLabel: 'Adjust $kind by $label'),
      ),
    );
  }

  void _adjustWeight(double amount) {
    final current = double.tryParse(weightController.text.trim()) ?? 0;
    final adjusted = current + amount;
    final text = adjusted == adjusted.truncateToDouble()
        ? adjusted.toInt().toString()
        : adjusted.toString();
    weightController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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

  String _formatAmount(num amount) {
    return amount == amount.truncateToDouble()
        ? amount.toInt().toString()
        : amount.toString();
  }
}
