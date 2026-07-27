import 'package:flutter/material.dart';

import '../../../core/models/food_item.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_dropdown.dart';
import '../../../core/widgets/operation_text_field.dart';

class FoodInputFields extends StatelessWidget {
  final TextEditingController foodNameController;
  final TextEditingController calorieController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final TextEditingController carbohydrateController;
  final TextEditingController baseAmountController;
  final TextEditingController amountController;
  final FoodBaseUnit baseUnit;
  final FoodAmountMode amountMode;

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onBaseAmountChanged;
  final ValueChanged<FoodBaseUnit> onBaseUnitChanged;

  const FoodInputFields({
    super.key,
    required this.foodNameController,
    required this.calorieController,
    required this.proteinController,
    required this.fatController,
    required this.carbohydrateController,
    required this.baseAmountController,
    required this.amountController,
    required this.baseUnit,
    required this.amountMode,
    required this.onChanged,
    required this.onBaseAmountChanged,
    required this.onBaseUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final baseAmount = _formatAmount(baseAmountController.text);
    final parsedBaseAmount = double.tryParse(baseAmountController.text.trim());
    final parsedAmount = double.tryParse(amountController.text.trim());
    final physicalAmount =
        amountMode == FoodAmountMode.baseMultiplier &&
            parsedBaseAmount != null &&
            parsedBaseAmount.isFinite &&
            parsedBaseAmount > 0 &&
            parsedAmount != null &&
            parsedAmount.isFinite &&
            parsedAmount > 0
        ? parsedBaseAmount * parsedAmount
        : null;

    return Column(
      children: [
        OperationTextField(
          controller: foodNameController,
          label: 'Food Name',
          onChanged: onChanged,
        ),

        AppSpacing.gapMD,

        Row(
          children: [
            Expanded(
              child: OperationTextField(
                controller: baseAmountController,
                label: 'BASE AMOUNT',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: onBaseAmountChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OperationDropdown<FoodBaseUnit>(
                label: 'BASE UNIT',
                value: baseUnit,
                items: FoodBaseUnit.values
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (unit) {
                  if (unit != null) onBaseUnitChanged(unit);
                },
              ),
            ),
          ],
        ),

        AppSpacing.gapMD,

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'NUTRITION PER $baseAmount${baseUnit.label}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),

        AppSpacing.gapMD,

        Row(
          children: [
            Expanded(
              child: OperationTextField(
                controller: calorieController,
                label: 'Calories',
                keyboardType: TextInputType.number,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OperationTextField(
                controller: proteinController,
                label: 'Protein',
                keyboardType: TextInputType.number,
                onChanged: onChanged,
              ),
            ),
          ],
        ),

        AppSpacing.gapMD,

        Row(
          children: [
            Expanded(
              child: OperationTextField(
                controller: fatController,
                label: 'Fat',
                keyboardType: TextInputType.number,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OperationTextField(
                controller: carbohydrateController,
                label: 'Carbohydrate',
                keyboardType: TextInputType.number,
                onChanged: onChanged,
              ),
            ),
          ],
        ),

        AppSpacing.gapMD,

        OperationTextField(
          controller: amountController,
          label: amountMode == FoodAmountMode.baseMultiplier
              ? 'AMOUNT'
              : 'QUANTITY (${baseUnit.label})',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
        ),

        if (amountMode == FoodAmountMode.baseMultiplier) ...[
          AppSpacing.gapXS,
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '1 AMOUNT = $baseAmount${baseUnit.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],

        if (physicalAmount != null) ...[
          AppSpacing.gapXS,
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '実使用量: ${_formatNumber(physicalAmount)}'
              '${baseUnit.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  static String _formatAmount(String source) {
    final value = double.tryParse(source.trim());
    if (value == null || !value.isFinite || value <= 0) return '—';
    return _formatNumber(value);
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }
}
