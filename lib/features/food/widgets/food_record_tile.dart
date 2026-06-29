import 'package:flutter/material.dart';
import '../../../core/models/food_data.dart';

class FoodRecordTile extends StatelessWidget {
  final FoodData record;
  final VoidCallback onDelete;

  const FoodRecordTile({
    super.key,
    required this.record,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _mealTypeLabel(record.mealType),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  tooltip: "削除",
                  onPressed: onDelete,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text("🍽 ${record.meal}", style: const TextStyle(fontSize: 16)),

            const SizedBox(height: 10),

            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                Text("🔥 ${record.calories} kcal"),
                Text("💪 P ${record.protein} g"),
                Text("🥑 F ${record.fat} g"),
                Text("🍚 C ${record.carbohydrate} g"),
              ],
            ),

            if (record.memo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text("📝 ${record.memo}"),
            ],
          ],
        ),
      ),
    );
  }
}

String _mealTypeLabel(String type) {
  switch (type) {
    case "朝食":
      return "🌅 朝食";
    case "昼食":
      return "☀️ 昼食";
    case "夕食":
      return "🌙 夕食";
    case "間食":
      return "🍫 間食";
    case "補食":
      return "💪 トレーニング補食";
    default:
      return type;
  }
}
