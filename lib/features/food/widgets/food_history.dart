import 'package:flutter/material.dart';

import '../../../core/models/food_data.dart';
import 'food_record_tile.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/theme/app_spacing.dart';

class FoodHistory extends StatelessWidget {
  final List<FoodData> records;
  final Function(FoodData) onDelete;

  const FoodHistory({super.key, required this.records, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Saved Records", style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 12),

          Text("保存件数 : ${records.length}"),

          AppSpacing.gapMD,

          ...records.map(
            (record) => FoodRecordTile(
              record: record,
              onDelete: () => onDelete(record),
            ),
          ),
        ],
      ),
    );
  }
}
