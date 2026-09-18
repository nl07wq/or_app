import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_dropdown.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../food_catalog_page.dart';
import '../models/food_catalog_models.dart';
import '../models/food_quantity_models.dart';
import '../services/food_nutrition_recalculation.dart';

class FoodInputFields extends StatelessWidget {
  static const _compactGap = SizedBox(height: AppSpacing.sm);
  static const _compactFieldPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  );
  static const _compactLabelStyle = TextStyle(fontSize: 12);
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
  final FoodQuantityUnit baseUnit;
  final bool recipeSelected;

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onBaseAmountChanged;
  final ValueChanged<FoodQuantityUnit> onBaseUnitChanged;
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
  final VoidCallback? onRecalculateNutrition;
  final String? recalculationBlockReason;

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
    this.onRecalculateNutrition,
    this.recalculationBlockReason,
  });

  @override
  Widget build(BuildContext context) {
    final baseAmount = _formatAmount(baseAmountController.text);
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: _compactFieldPadding,
          labelStyle: _compactLabelStyle.copyWith(
            color: theme.inputDecorationTheme.labelStyle?.color,
          ),
          floatingLabelStyle: _compactLabelStyle,
        ),
        textTheme: theme.textTheme.copyWith(
          bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
        ),
      ),
      child: Column(
        children: [
          if (nutritionCaptureInProgress)
            const _NutritionOcrProcessing()
          else
            OperationButton(
              key: const ValueKey('food-entry-ocr'),
              icon: Icons.document_scanner,
              text: 'SCAN NUTRITION LABEL',
              onPressed: onReadNutrition,
            ),

          _compactGap,

          OperationTextField(
            controller: foodNameController,
            label: 'NAME',
            onChanged: onChanged,
          ),

          _compactGap,

          LayoutBuilder(
            builder: (context, constraints) {
              final brand = OperationTextField(
                controller: brandController,
                label: 'BRAND',
                onChanged: onChanged,
              );
              final categoryField = OperationDropdown<FoodCatalogCategory>(
                key: ValueKey('food-entry-category-${category.name}'),
                label: 'CATEGORY',
                value: category,
                isExpanded: true,
                items: FoodCatalogCategory.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          foodCatalogCategoryLabel(value),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onCategoryChanged(value);
                },
              );
              if (constraints.maxWidth < 300) {
                return Column(children: [brand, _compactGap, categoryField]);
              }
              return Row(
                children: [
                  Expanded(child: brand),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: categoryField),
                ],
              );
            },
          ),

          _compactGap,

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
                  minimumSize: const Size(84, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),

          _compactGap,

          LayoutBuilder(
            builder: (context, constraints) {
              final quantity = _QuantityUnitGroup<FoodQuantityUnit?>(
                key: const ValueKey('food-entry-package-compound'),
                controller: packageQuantityController,
                label: '表示量',
                quantityKey: const ValueKey('food-entry-package-quantity'),
                unitKey: ValueKey(
                  'food-entry-package-unit-${packageUnit?.name ?? 'none'}',
                ),
                value: packageUnit,
                valueLabel: packageUnit == null
                    ? 'NOT SET'
                    : _quantityUnitLabel(packageUnit!),
                items: [null, ...FoodQuantityUnit.values]
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(
                          unit == null ? 'NOT SET' : _quantityUnitLabel(unit),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onUnitChanged: onPackageUnitChanged,
                onQuantityChanged: onPackageQuantityChanged,
              );
              if (recipeSelected) {
                if (constraints.maxWidth < 260) {
                  return quantity;
                }
                return quantity;
              }
              final baseQuantity = _QuantityUnitGroup<FoodQuantityUnit>(
                key: const ValueKey('food-entry-base-compound'),
                controller: baseAmountController,
                label: '登録基準量',
                quantityKey: const ValueKey('food-entry-base-quantity'),
                unitKey: ValueKey('food-entry-base-unit-${baseUnit.name}'),
                value: baseUnit,
                valueLabel: _quantityUnitLabel(baseUnit),
                items: FoodQuantityUnit.values
                    .map(
                      (unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(
                          _quantityUnitLabel(unit),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onUnitChanged: (unit) {
                  if (unit != null) onBaseUnitChanged(unit);
                },
                onQuantityChanged: onBaseAmountChanged,
              );
              if (constraints.maxWidth < 300) {
                return Column(children: [quantity, _compactGap, baseQuantity]);
              }
              return Row(
                children: [
                  Expanded(child: quantity),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: baseQuantity),
                ],
              );
            },
          ),

          _compactGap,

          OperationButton(
            key: const ValueKey('food-entry-recalculate-nutrition'),
            icon: Icons.calculate_outlined,
            text: _recalculationActionLabel(),
            onPressed: recalculationBlockReason == null
                ? onRecalculateNutrition
                : null,
          ),

          const SizedBox(height: AppSpacing.xs),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '栄養成分の基準量を設定',
              key: const ValueKey('food-entry-nutrition-basis-helper'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          if (_visibleRecalculationBlockReason case final reason?) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                reason,
                key: const ValueKey('food-entry-recalculation-reason'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],

          _compactGap,

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              recipeSelected
                  ? 'NUTRITION PER SERVING'
                  : baseAmount == '—'
                  ? '栄養成分'
                  : '$baseAmount${_quantityUnitLabel(baseUnit)}あたりの栄養成分',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

          _compactGap,

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
              const SizedBox(width: AppSpacing.sm),
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

          _compactGap,

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
              const SizedBox(width: AppSpacing.sm),
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

          _compactGap,

          LayoutBuilder(
            builder: (context, constraints) {
              final amount = OperationTextField(
                key: const ValueKey('food-amount-input'),
                controller: amountController,
                label: recipeSelected
                    ? 'SERVINGS'
                    : '実使用量 (${_quantityUnitLabel(baseUnit)})',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: onChanged,
              );
              final stepper = FoodNumericStepper(
                key: const ValueKey('food-amount-stepper-column'),
                fillParent: true,
                incrementKey: const ValueKey('food-amount-increment'),
                incrementTooltip: 'Increase amount',
                onIncrement: () => _stepAmount(1),
                decrementKey: const ValueKey('food-amount-decrement'),
                decrementTooltip: 'Decrease amount',
                onDecrement: _canDecrement ? () => _stepAmount(-1) : null,
              );
              final memo = OperationTextField(
                controller: foodMemoController,
                label: 'MEMO',
                minLines: 1,
                maxLines: 2,
                onChanged: onChanged,
              );
              if (constraints.maxWidth < 300) {
                return Column(
                  children: [
                    SizedBox(
                      height: 56,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: amount),
                          stepper,
                        ],
                      ),
                    ),
                    _compactGap,
                    memo,
                  ],
                );
              }
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: foodMemoController,
                builder: (context, value, _) {
                  // All three lower controls share one explicit outer row.
                  // A newline grows the field, stepper column, and Memo
                  // together to the approved two-line height.
                  final lines = '\n'.allMatches(value.text).length + 1;
                  final rowHeight = lines > 1 ? 72.0 : 56.0;
                  return SizedBox(
                    height: rowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The amount remains practical for decimal and four
                        // digit entry, while Memo receives the majority of
                        // the shared lower-row width.
                        SizedBox(width: 112, child: amount),
                        const SizedBox(width: AppSpacing.xs),
                        stepper,
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: memo),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String? get _visibleRecalculationBlockReason =>
      recalculationBlockReason == 'SET PACKAGE QUANTITY AND UNIT'
      ? null
      : recalculationBlockReason == null
      ? null
      : foodManualNutritionValidationMessage(recalculationBlockReason!);

  String _recalculationActionLabel() {
    final value = double.tryParse(baseAmountController.text.trim());
    if (value == null || !value.isFinite || value <= 0) return '栄養を換算';
    return '${_formatNumber(value)}${_quantityUnitLabel(baseUnit)}あたりに換算';
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

  bool get _canDecrement {
    final value = double.tryParse(amountController.text.trim());
    return value != null && value.isFinite && value - 1 > 0;
  }

  void _stepAmount(double delta) {
    final current = double.tryParse(amountController.text.trim());
    if (current == null || !current.isFinite) return;
    final next = current + delta;
    if (next <= 0) return;
    final value = _formatNumber(next);
    amountController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    onChanged(value);
  }
}

class _NutritionOcrProcessing extends StatefulWidget {
  const _NutritionOcrProcessing();

  @override
  State<_NutritionOcrProcessing> createState() =>
      _NutritionOcrProcessingState();
}

class _NutritionOcrProcessingState extends State<_NutritionOcrProcessing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 76,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => CustomPaint(
            size: const Size.square(42),
            painter: _NutritionAnalysisPainter(
              progress: _controller.value,
              color: Theme.of(context).colorScheme.primary,
              mutedColor: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Text('ANALYZING NUTRITION LABEL'),
      ],
    ),
  );
}

class _NutritionAnalysisPainter extends CustomPainter {
  const _NutritionAnalysisPainter({
    required this.progress,
    required this.color,
    required this.mutedColor,
  });

  final double progress;
  final Color color;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide * .42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    paint.color = mutedColor.withValues(alpha: .35);
    canvas.drawCircle(center, outer, paint);
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outer),
      progress * math.pi * 2,
      math.pi * .62,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NutritionAnalysisPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.mutedColor != mutedColor;
}

/// Shared presentation-only numeric field plus a compact vertical stepper.
/// Callers keep ownership of parsing, minimum values, and domain calculations.
class FoodNumericStepperRow extends StatelessWidget {
  const FoodNumericStepperRow({
    super.key,
    required this.inputKey,
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.incrementKey,
    required this.incrementTooltip,
    required this.onIncrement,
    required this.decrementKey,
    required this.decrementTooltip,
    required this.onDecrement,
    this.matchFieldHeight = false,
  });

  final Key inputKey;
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final Key incrementKey;
  final String incrementTooltip;
  final VoidCallback? onIncrement;
  final Key decrementKey;
  final String decrementTooltip;
  final VoidCallback? onDecrement;
  final bool matchFieldHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final field = OperationTextField(
        key: inputKey,
        controller: controller,
        label: label,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
      );
      final matchedField = matchFieldHeight && constraints.hasBoundedHeight
          ? SizedBox(height: constraints.maxHeight, child: field)
          : field;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: matchedField),
          const SizedBox(width: AppSpacing.xs),
          FoodNumericStepper(
            incrementKey: incrementKey,
            incrementTooltip: incrementTooltip,
            onIncrement: onIncrement,
            decrementKey: decrementKey,
            decrementTooltip: decrementTooltip,
            onDecrement: onDecrement,
          ),
        ],
      );
    },
  );
}

/// Fixed-width middle column shared by compact numeric controls. Its outer
/// height is supplied by the parent row, keeping the arrows visibly within
/// the same bounds as the neighboring field surfaces.
class FoodNumericStepper extends StatelessWidget {
  const FoodNumericStepper({
    super.key,
    this.fillParent = false,
    required this.incrementKey,
    required this.incrementTooltip,
    required this.onIncrement,
    required this.decrementKey,
    required this.decrementTooltip,
    required this.onDecrement,
  });

  static const width = 44.0;

  final bool fillParent;
  final Key incrementKey;
  final String incrementTooltip;
  final VoidCallback? onIncrement;
  final Key decrementKey;
  final String decrementTooltip;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (fillParent) ...[
          Expanded(
            child: FoodNumericStepButton(
              key: incrementKey,
              fillParent: true,
              icon: Icons.keyboard_arrow_up,
              tooltip: incrementTooltip,
              onPressed: onIncrement,
            ),
          ),
          Expanded(
            child: FoodNumericStepButton(
              key: decrementKey,
              fillParent: true,
              icon: Icons.keyboard_arrow_down,
              tooltip: decrementTooltip,
              onPressed: onDecrement,
            ),
          ),
        ] else ...[
          FoodNumericStepButton(
            key: incrementKey,
            icon: Icons.keyboard_arrow_up,
            tooltip: incrementTooltip,
            onPressed: onIncrement,
          ),
          FoodNumericStepButton(
            key: decrementKey,
            icon: Icons.keyboard_arrow_down,
            tooltip: decrementTooltip,
            onPressed: onDecrement,
          ),
        ],
      ],
    ),
  );
}

class _QuantityUnitGroup<T> extends StatelessWidget {
  const _QuantityUnitGroup({
    super.key,
    required this.controller,
    required this.label,
    required this.quantityKey,
    required this.unitKey,
    required this.value,
    required this.valueLabel,
    required this.items,
    required this.onUnitChanged,
    required this.onQuantityChanged,
  });

  final TextEditingController controller;
  final String label;
  final Key quantityKey;
  final Key unitKey;
  final T value;
  final String valueLabel;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onUnitChanged;
  final ValueChanged<String> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final group = label == '表示量' ? 'package' : 'base';
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('food-entry-$group-quantity-module'),
      height: 70,
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: ExcludeSemantics(
              child: Center(
                child: Text(
                  label,
                  key: ValueKey('food-entry-$group-group-label'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontSize: 10.5),
                ),
              ),
            ),
          ),
          Container(
            key: ValueKey('food-entry-$group-horizontal-divider'),
            height: 1,
            color: colors.outlineVariant,
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Semantics(
                    label: '$label 数値',
                    textField: true,
                    child: TextField(
                      key: quantityKey,
                      controller: controller,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.only(left: 6, right: 10),
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: onQuantityChanged,
                    ),
                  ),
                ),
                Container(
                  key: ValueKey('food-entry-$group-vertical-divider'),
                  width: 1,
                  color: colors.outlineVariant,
                ),
                Expanded(
                  flex: 6,
                  child: Semantics(
                    label: '$label 単位',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textStyle = Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(fontSize: 14);
                        const chevronWidth = 24.0;
                        const chevronRightPadding = 4.0;
                        const chevronClearance = 4.0;
                        final textPainter = TextPainter(
                          text: TextSpan(text: valueLabel, style: textStyle),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout(maxWidth: constraints.maxWidth);
                        final chevronExclusionLeft =
                            constraints.maxWidth -
                            chevronWidth -
                            chevronRightPadding;
                        const preferredDividerPadding = 10.0;
                        final unitTextLeft =
                            (chevronExclusionLeft -
                                    chevronClearance -
                                    textPainter.width)
                                .clamp(0.0, preferredDividerPadding);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            DropdownButtonHideUnderline(
                              child: DropdownButton<T>(
                                key: unitKey,
                                value: value,
                                isExpanded: true,
                                alignment: AlignmentDirectional.centerStart,
                                padding: const EdgeInsets.only(right: 4),
                                style: textStyle,
                                selectedItemBuilder: (context) => items
                                    .map((_) => const SizedBox.shrink())
                                    .toList(growable: false),
                                items: items,
                                onChanged: onUnitChanged,
                              ),
                            ),
                            Positioned(
                              left: unitTextLeft,
                              right:
                                  chevronWidth +
                                  chevronRightPadding +
                                  chevronClearance,
                              top: 0,
                              bottom: 0,
                              child: ExcludeSemantics(
                                child: IgnorePointer(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      valueLabel,
                                      key: ValueKey(
                                        'food-entry-$group-unit-value',
                                      ),
                                      style: textStyle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FoodNumericStepButton extends StatelessWidget {
  const FoodNumericStepButton({
    super.key,
    this.fillParent = false,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool fillParent;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: FoodNumericStepper.width,
    height: fillParent ? null : 24,
    child: IconButton(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    ),
  );
}

String _quantityUnitLabel(FoodQuantityUnit unit) => switch (unit) {
  FoodQuantityUnit.gram => 'g',
  FoodQuantityUnit.milliliter => 'mL',
  FoodQuantityUnit.piece => 'piece',
  FoodQuantityUnit.pack => 'pack',
  FoodQuantityUnit.serving => 'serving',
};
