import 'package:flutter/material.dart';

import '../../core/models/food_data.dart';
import '../../core/repositories/food_repository.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({super.key});

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  late Future<List<FoodData>> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    _records = FoodRepository.getAll();
  }

  Future<void> _deleteRecord(FoodData data) async {
    final result = await showHistoryDeleteDialog(context, title: 'Food Record');

    if (!result) return;

    await FoodRepository.remove(data);

    _loadRecords();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food History')),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: FutureBuilder<List<FoodData>>(
          future: _records,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = snapshot.data!;

            if (records.isEmpty) {
              return const Center(child: Text('No food records.'));
            }

            return ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, __) => AppSpacing.gapMD,
              itemBuilder: (context, index) {
                final food = records[index];

                return OperationCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 日付＋削除
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            food.date,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            tooltip: 'Delete',
                            onPressed: () {
                              _deleteRecord(food);
                            },
                          ),
                        ],
                      ),

                      AppSpacing.gapSM,

                      // 食事区分
                      SectionHeader(
                        icon: Icons.restaurant,
                        title: food.mealType,
                      ),

                      AppSpacing.gapMD,

                      // 食事名
                      Text(
                        food.meal,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),

                      AppSpacing.gapMD,

                      // 栄養情報
                      Text('🔥 ${food.calories} kcal'),
                      Text('🥩 P ${food.protein} g'),
                      Text('🧈 F ${food.fat} g'),
                      Text('🍚 C ${food.carbohydrate} g'),

                      if (food.memo.isNotEmpty) ...[
                        AppSpacing.gapMD,
                        Text('📝 ${food.memo}'),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
