import 'package:flutter/material.dart';

import '../food_nutrition_formatter.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FoodItemList extends StatelessWidget {
  final List<FoodItem> items;
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
    required this.onDelete,
    required this.onTap,
    required this.onQuantityChanged,
    required this.editableItemCount,
    required this.actionIcon,
    required this.actionText,
    required this.onAction,
  });

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
            final canAdjustQuantity = index < editableItemCount;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(index),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    tooltip: 'Decrease quantity',
                                    onPressed:
                                        canAdjustQuantity && item.quantity > 1
                                        ? () => onQuantityChanged(index, -1)
                                        : null,
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    tooltip: 'Increase quantity',
                                    onPressed: canAdjustQuantity
                                        ? () => onQuantityChanged(index, 1)
                                        : null,
                                  ),
                                ],
                              ),

                              AppSpacing.gapMD,

                              Text(
                                'Calories : ${FoodNutritionFormatter.calories(item.totalCalories)} kcal',
                              ),
                              Text(
                                'Protein : ${FoodNutritionFormatter.macro(item.totalProtein)} g',
                              ),
                              Text(
                                'Fat : ${FoodNutritionFormatter.macro(item.totalFat)} g',
                              ),
                              Text(
                                'Carbohydrate : ${FoodNutritionFormatter.macro(item.totalCarbohydrate)} g',
                              ),
                            ],
                          ),
                        ),

                        IconButton(
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
}
