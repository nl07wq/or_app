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

  final ValueChanged<String> onChanged;
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
    required this.onChanged,
    required this.onBaseUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final baseAmount = _formatAmount(baseAmountController.text);

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
                onChanged: onChanged,
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
          label: 'QUANTITY (${baseUnit.label})',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
        ),
      ],
    );
  }

  static String _formatAmount(String source) {
    final value = double.tryParse(source.trim());
    if (value == null || !value.isFinite || value <= 0) return '—';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }
}
