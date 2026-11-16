import 'package:flutter/material.dart';

import '../../../core/widgets/global_touch_ripple.dart';
import '../../themes/base_camp/base_camp_retro_theme.dart';
import 'food_form_theme.dart';

const foodQuantityUnitDisplayLabels = <String>[
  'NOT SET',
  'g',
  'mL',
  'piece',
  'pack',
  'serving',
];

/// Shared quantity-and-unit presentation used by manual FOOD entry and the
/// FOOD DATABASE editor. The selected UNIT value is rendered independently
/// from the dropdown arrow so its one-line bounds are identical in both flows.
class FoodQuantityUnitField<T> extends StatelessWidget {
  const FoodQuantityUnitField({
    super.key,
    required this.controller,
    required this.group,
    required this.label,
    required this.quantityKey,
    required this.unitKey,
    required this.value,
    required this.valueLabel,
    required this.fitLabels,
    required this.items,
    required this.onUnitChanged,
    required this.onQuantityChanged,
  });

  final TextEditingController controller;
  final String group;
  final String label;
  final Key quantityKey;
  final Key unitKey;
  final T value;
  final String valueLabel;
  final List<String> fitLabels;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onUnitChanged;
  final ValueChanged<String> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final classicTerminal = BaseCampRetroTheme.isApplied(Theme.of(context));
    final scheme = Theme.of(context).colorScheme;
    final fieldColor = classicTerminal
        ? scheme.surfaceContainer
        : FoodFormMetrics.fieldSurface;
    final borderColor = classicTerminal
        ? scheme.outline
        : FoodFormMetrics.separator;
    final captionColor = classicTerminal
        ? scheme.onSurfaceVariant
        : FoodFormMetrics.caption;
    final labelColor = classicTerminal
        ? scheme.onSurfaceVariant
        : FoodFormMetrics.fieldLabel;
    return Container(
      key: ValueKey('food-entry-$group-quantity-module'),
      height: 76,
      decoration: BoxDecoration(
        color: fieldColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(classicTerminal ? 4 : 12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        key: ValueKey('food-entry-$group-group-label'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          letterSpacing: .55,
                          color: captionColor,
                        ),
                      ),
                    ),
                    Text(
                      group == 'package' ? 'PACKAGE UNIT' : 'BASIS UNIT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: .45,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            key: ValueKey('food-entry-$group-horizontal-divider'),
            height: 1,
            color: borderColor,
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
                    ).inputFeedback(),
                  ),
                ),
                Container(
                  key: ValueKey('food-entry-$group-vertical-divider'),
                  width: 1,
                  color: borderColor,
                ),
                Expanded(
                  flex: 6,
                  child: Semantics(
                    label: '$label 単位',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const chevronWidth = 24.0;
                        const chevronRightPadding = 4.0;
                        const chevronClearance = 4.0;
                        const dividerPadding = 10.0;
                        final inheritedStyle = Theme.of(
                          context,
                        ).textTheme.bodyLarge;
                        final availableTextWidth =
                            constraints.maxWidth -
                            chevronWidth -
                            chevronRightPadding -
                            chevronClearance -
                            dividerPadding;
                        final selectedFontSize = fitFoodUnitSelectedFontSize(
                          labels: fitLabels,
                          style: inheritedStyle,
                          maxWidth: availableTextWidth,
                          maxHeight: constraints.maxHeight,
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                          maximum: classicTerminal ? 11.2 : 14,
                          minimum: classicTerminal ? 8 : 10,
                        );
                        final textStyle = inheritedStyle?.copyWith(
                          fontSize: selectedFontSize,
                          height: classicTerminal ? 1.2 : 1.1,
                        );
                        final textPainter = TextPainter(
                          text: TextSpan(text: valueLabel, style: textStyle),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                          maxLines: 1,
                        )..layout();
                        final chevronExclusionLeft =
                            constraints.maxWidth -
                            chevronWidth -
                            chevronRightPadding;
                        final unitTextLeft =
                            (chevronExclusionLeft -
                                    chevronClearance -
                                    textPainter.width)
                                .clamp(0.0, dividerPadding);

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
                              ).inputFeedback(),
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
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
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

double fitFoodUnitSelectedFontSize({
  required List<String> labels,
  required TextStyle? style,
  required double maxWidth,
  required double maxHeight,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required double maximum,
  required double minimum,
}) {
  var fontSize = maximum;
  bool fits(double candidate) => labels.every((label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: style?.copyWith(fontSize: candidate, height: 1.2),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return painter.width <= maxWidth && painter.height <= maxHeight;
  });

  while (fontSize > minimum && !fits(fontSize)) {
    fontSize -= .2;
  }
  assert(
    fits(fontSize),
    'The longest FOOD unit label does not fit the fixed selector at '
    '$fontSize px (${maxWidth}x$maxHeight).',
  );
  return fontSize;
}
