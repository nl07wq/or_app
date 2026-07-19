import 'package:flutter/material.dart';

import '../../../core/models/meal_data.dart';

class FoodRecordTile extends StatelessWidget {
  final MealData record;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const FoodRecordTile({
    super.key,
    required this.record,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.mealType,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...record.items.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restaurant_menu),
                title: Text(item.name),
                subtitle: Text(
                  "${item.calories} kcal"
                  "  P ${item.protein}"
                  "  F ${item.fat}"
                  "  C ${item.carbohydrate}",
                ),
              ),
            ),
            if (record.memo.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.note_outlined),
                title: Text(record.memo),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
