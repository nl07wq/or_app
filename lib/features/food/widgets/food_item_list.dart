import 'package:flutter/material.dart';

import '../../../core/models/food_item.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FoodItemList extends StatelessWidget {
  final List<FoodItem> items;
  final Function(int) onDelete;
  final Function(int) onTap;

  const FoodItemList({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onTap,
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

          ...List.generate(items.length, (index) {
            final item = items[index];

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
                              Text(
                                item.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),

                              AppSpacing.gapMD,

                              Text('Calories : ${item.calories} kcal'),
                              Text('Protein : ${item.protein} g'),
                              Text('Fat : ${item.fat} g'),
                              Text('Carbohydrate : ${item.carbohydrate} g'),
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
