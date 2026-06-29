import 'package:flutter/material.dart';

import '../../../core/models/food_data.dart';
import 'food_record_tile.dart';
import '../../../core/widgets/operation_card.dart';

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
          const Text(
            "Saved Records",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Text("保存件数 : ${records.length}"),

          const SizedBox(height: 12),

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
