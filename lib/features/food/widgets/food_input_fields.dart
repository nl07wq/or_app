import 'package:flutter/material.dart';

import '../../../core/models/food_item.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_dropdown.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../food_catalog_page.dart';
import '../models/food_catalog_models.dart';
import '../models/food_quantity_models.dart';

class FoodInputFields extends StatelessWidget {
  final TextEditingController foodNameController;
  final TextEditingController brandController;
  final TextEditingController barcodeController;
  final TextEditingController packageQuantityController;
  final TextEditingController calorieController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final TextEditingController carbohydrateController;
  final TextEditingController baseAmountController;
  final TextEditingController amountController;
  final TextEditingController foodMemoController;
  final FoodCatalogCategory category;
  final FoodQuantityUnit? packageUnit;
  final FoodBaseUnit baseUnit;
  final FoodAmountMode amountMode;
  final bool recipeSelected;

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onBaseAmountChanged;
  final ValueChanged<FoodBaseUnit> onBaseUnitChanged;
  final ValueChanged<FoodCatalogCategory> onCategoryChanged;
  final ValueChanged<String> onPackageQuantityChanged;
  final ValueChanged<FoodQuantityUnit?> onPackageUnitChanged;
  final VoidCallback onCaloriesChanged;
  final VoidCallback onProteinChanged;
  final VoidCallback onFatChanged;
  final VoidCallback onCarbohydrateChanged;
  final VoidCallback? onScanBarcode;
  final bool barcodeScanInProgress;
  final VoidCallback? onReadNutrition;
  final bool nutritionCaptureInProgress;

  const FoodInputFields({
    super.key,
    required this.foodNameController,
    required this.brandController,
    required this.barcodeController,
    required this.packageQuantityController,
    required this.calorieController,
    required this.proteinController,
    required this.fatController,
    required this.carbohydrateController,
    required this.baseAmountController,
    required this.amountController,
    required this.foodMemoController,
    required this.category,
    required this.packageUnit,
    required this.baseUnit,
    required this.amountMode,
    this.recipeSelected = false,
    required this.onChanged,
    required this.onBaseAmountChanged,
    required this.onBaseUnitChanged,
    required this.onCategoryChanged,
    required this.onPackageQuantityChanged,
    required this.onPackageUnitChanged,
    required this.onCaloriesChanged,
    required this.onProteinChanged,
    required this.onFatChanged,
    required this.onCarbohydrateChanged,
    this.onScanBarcode,
    this.barcodeScanInProgress = false,
    this.onReadNutrition,
    this.nutritionCaptureInProgress = false,
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
        OperationButton(
          key: const ValueKey('food-entry-ocr'),
          icon: Icons.document_scanner,
          text: nutritionCaptureInProgress
              ? 'PROCESSING IMAGE'
              : 'SCAN NUTRITION LABEL',
          onPressed: onReadNutrition,
        ),

        AppSpacing.gapMD,

        OperationTextField(
          controller: foodNameController,
          label: 'NAME',
          onChanged: onChanged,
        ),

        AppSpacing.gapMD,

        OperationTextField(
          controller: brandController,
          label: 'BRAND',
          onChanged: onChanged,
        ),

        AppSpacing.gapMD,

        OperationDropdown<FoodCatalogCategory>(
          key: ValueKey('food-entry-category-${category.name}'),
          label: 'CATEGORY',
          value: category,
          items: FoodCatalogCategory.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(foodCatalogCategoryLabel(value)),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) onCategoryChanged(value);
          },
        ),

        AppSpacing.gapMD,

        Row(
          children: [
            Expanded(
              child: OperationTextField(
                controller: barcodeController,
                label: 'BARCODE / JAN',
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('food-entry-barcode-scan'),
              onPressed: onScanBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(barcodeScanInProgress ? '...' : 'SCAN'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(96, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),

        AppSpacing.gapMD,

        LayoutBuilder(
          builder: (context, constraints) {
            final quantity = OperationTextField(
              controller: packageQuantityController,
              label: 'PACKAGE QUANTITY',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: onPackageQuantityChanged,
            );
            final unit = OperationDropdown<FoodQuantityUnit?>(
              key: ValueKey(
                'food-entry-package-unit-${packageUnit?.name ?? 'none'}',
              ),
              label: 'PACKAGE UNIT',
              value: packageUnit,
              items: [null, ...FoodQuantityUnit.values]
                  .map(
                    (unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(
                        unit == null ? 'NOT SET' : _quantityUnitLabel(unit),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onPackageUnitChanged,
            );
            if (constraints.maxWidth < 300) {
              return Column(children: [quantity, AppSpacing.gapMD, unit]);
            }
            return Row(
              children: [
                Expanded(child: quantity),
                const SizedBox(width: 12),
                Expanded(child: unit),
              ],
            );
          },
        ),

        AppSpacing.gapMD,

        if (!recipeSelected)
          Row(
            children: [
              Expanded(
                child: OperationTextField(
                  controller: baseAmountController,
                  label: 'NUTRITION BASIS',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onBaseAmountChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OperationDropdown<FoodBaseUnit>(
                  key: ValueKey('food-entry-base-unit-${baseUnit.name}'),
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
            recipeSelected
                ? 'NUTRITION PER SERVING'
                : 'NUTRITION PER $baseAmount${baseUnit.label}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),

        AppSpacing.gapMD,

        Row(
          children: [
            Expanded(
              child: OperationTextField(
                controller: calorieController,
                label: 'CALORIES',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  onCaloriesChanged();
                  onChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OperationTextField(
                controller: proteinController,
                label: 'PROTEIN',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  onProteinChanged();
                  onChanged(value);
                },
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
                label: 'FAT',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  onFatChanged();
                  onChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OperationTextField(
                controller: carbohydrateController,
                label: 'CARBOHYDRATE',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  onCarbohydrateChanged();
                  onChanged(value);
                },
              ),
            ),
          ],
        ),

        AppSpacing.gapMD,

        OperationTextField(
          controller: foodMemoController,
          label: 'MEMO',
          maxLines: 2,
          onChanged: onChanged,
        ),

        AppSpacing.gapMD,

        OperationTextField(
          controller: amountController,
          label: recipeSelected
              ? 'SERVINGS'
              : amountMode == FoodAmountMode.baseMultiplier
              ? 'AMOUNT'
              : 'QUANTITY (${baseUnit.label})',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
        ),

        if (!recipeSelected && amountMode == FoodAmountMode.baseMultiplier) ...[
          AppSpacing.gapXS,
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '1 AMOUNT = $baseAmount${baseUnit.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],

        if (!recipeSelected && physicalAmount != null) ...[
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

String _quantityUnitLabel(FoodQuantityUnit unit) => switch (unit) {
  FoodQuantityUnit.gram => 'g',
  FoodQuantityUnit.milliliter => 'mL',
  FoodQuantityUnit.piece => 'piece',
  FoodQuantityUnit.pack => 'pack',
  FoodQuantityUnit.serving => 'serving',
};
