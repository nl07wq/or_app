import 'package:flutter/material.dart';

import '../../../core/models/meal_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';

import 'food_record_tile.dart';

class FoodHistory extends StatelessWidget {
  final List<MealData> records;
  final Function(MealData) onDelete;
  final Function(MealData) onEdit;

  const FoodHistory({
    super.key,
    required this.records,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Saved Records", style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 12),

          Text("Records : ${records.length}"),

          AppSpacing.gapMD,

          ...records.map(
            (record) => FoodRecordTile(
              record: record,
              onEdit: () => onEdit(record),
              onDelete: () => onDelete(record),
            ),
          ),
        ],
      ),
    );
  }
}
