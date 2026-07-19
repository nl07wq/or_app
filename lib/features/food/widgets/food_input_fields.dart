import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_text_field.dart';

class FoodInputFields extends StatelessWidget {
  final TextEditingController foodNameController;
  final TextEditingController calorieController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final TextEditingController carbohydrateController;

  final ValueChanged<String> onChanged;

  const FoodInputFields({
    super.key,
    required this.foodNameController,
    required this.calorieController,
    required this.proteinController,
    required this.fatController,
    required this.carbohydrateController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}
