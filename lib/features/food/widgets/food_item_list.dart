import 'package:flutter/material.dart';

import '../food_nutrition_formatter.dart';
import '../models/food_catalog_models.dart';
import '../models/food_quantity_models.dart';
import '../models/recipe_models_v2.dart';
import '../services/food_recipe_nutrition.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'food_thumbnail.dart';

class FoodItemList extends StatelessWidget {
  final List<FoodItem> items;
  final List<FoodCatalogEntry?> catalogSources;
  final List<FoodRecipeDefinition?> recipeSources;
  final List<FoodQuantityUnit> quantityUnits;
  final Function(int) onDelete;
  final Function(int) onTap;
  final void Function(int index, int change) onQuantityChanged;
  final int editableItemCount;
  final IconData actionIcon;
  final String actionText;
  final VoidCallback onAction;

  const FoodItemList({
    super.key,
    required this.items,
    required this.catalogSources,
    required this.recipeSources,
    required this.quantityUnits,
    required this.onDelete,
    required this.onTap,
    required this.onQuantityChanged,
    required this.editableItemCount,
    required this.actionIcon,
    required this.actionText,
    required this.onAction,
  }) : assert(catalogSources.length == items.length),
       assert(recipeSources.length == items.length),
       assert(quantityUnits.length == items.length);

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.restaurant_menu,
            title: 'Meal Items (${items.length})',
          ),
          AppSpacing.gapMD,
          OperationButton(
            icon: actionIcon,
            text: actionText,
            onPressed: onAction,
          ),
          AppSpacing.gapMD,
          ...List.generate(items.length, (index) {
            final item = items[index];
            final catalog = catalogSources[index];
            final recipe = recipeSources[index];
            final quantityUnit = quantityUnits[index];
            final canAdjustQuantity = index < editableItemCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTap(index),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FoodThumbnail(visualKey: catalog?.visualKey),
                        AppSpacing.gapSM,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      key: ValueKey('meal-item-name-$index'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  if (item.hasMeasuredAmount)
                                    Text(
                                      'AMOUNT ${FoodNutritionFormatter.amount(item.amount!)}',
                                      key: ValueKey('meal-item-amount-$index'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    )
                                  else ...[
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.remove),
                                      tooltip: 'Decrease quantity',
                                      onPressed:
                                          canAdjustQuantity && item.quantity > 1
                                          ? () => onQuantityChanged(index, -1)
                                          : null,
                                    ),
                                    Text('${item.quantity}'),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add),
                                      tooltip: 'Increase quantity',
                                      onPressed: canAdjustQuantity
                                          ? () => onQuantityChanged(index, 1)
                                          : null,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                _metadata(item, catalog, recipe, quantityUnit),
                                key: ValueKey('meal-item-metadata-$index'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '${FoodNutritionFormatter.calories(item.totalCalories)}kcal'
                                '  P ${FoodNutritionFormatter.macro(item.totalProtein)}g'
                                '  F ${FoodNutritionFormatter.macro(item.totalFat)}g'
                                '  C ${FoodNutritionFormatter.macro(item.totalCarbohydrate)}g',
                                key: ValueKey('meal-item-nutrition-$index'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => onDelete(index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _metadata(
    FoodItem item,
    FoodCatalogEntry? catalog,
    FoodRecipeDefinition? recipe,
    FoodQuantityUnit quantityUnit,
  ) {
    final prefix = catalog == null
        ? recipe == null
              ? null
              : 'RECIPE'
        : FoodNutritionFormatter.category(catalog.category);
    final quantity = recipe == null
        ? _foodQuantity(item, quantityUnit)
        : FoodNutritionFormatter.compactQuantity(
            FoodRecipeNutrition.consumptionQuantity(
              recipe,
              (item.amount ?? item.quantity).toDouble(),
            ),
          );
    return prefix == null ? quantity : '$prefix  $quantity';
  }

  static String _foodQuantity(FoodItem item, FoodQuantityUnit quantityUnit) {
    if (!item.hasMeasuredAmount) return 'AMOUNT ${item.quantity}';
    final unit = FoodNutritionFormatter.quantityUnit(quantityUnit);
    final base = '${FoodNutritionFormatter.amount(item.baseAmount!)}$unit';
    final used = '${FoodNutritionFormatter.amount(item.physicalAmount!)}$unit';
    if (!quantityUnit.isPhysical) return used;
    if ((item.baseAmount! - item.physicalAmount!).abs() < 0.000001) {
      return used;
    }
    return 'Base $base · Used $used';
  }
}
