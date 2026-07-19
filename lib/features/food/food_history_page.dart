import 'package:flutter/material.dart';

import 'food_edit_page.dart';

import '../../core/models/meal_data.dart';
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
  late Future<List<MealData>> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    _records = FoodRepository.getAll();
  }

  Future<void> _deleteRecord(MealData data) async {
    final result = await showHistoryDeleteDialog(context, title: 'Meal Record');

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
        child: FutureBuilder<List<MealData>>(
          future: _records,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = snapshot.data!;

            if (records.isEmpty) {
              return const Center(child: Text('No meal records.'));
            }

            return ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, __) => AppSpacing.gapMD,
              itemBuilder: (context, index) {
                final meal = records[index];

                return OperationCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meal.date,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FoodEditPage(meal: meal),
                                ),
                              );

                              if (updated == true) {
                                _loadRecords();
                                setState(() {});
                              }
                            },
                          ),

                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => _deleteRecord(meal),
                          ),
                        ],
                      ),

                      SectionHeader(
                        icon: Icons.restaurant,
                        title: meal.mealType,
                      ),

                      AppSpacing.gapMD,

                      ...meal.items.map(
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

                      if (meal.memo.isNotEmpty) ...[
                        AppSpacing.gapMD,
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.note_outlined),
                          title: Text(meal.memo),
                        ),
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
