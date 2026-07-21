import 'package:flutter/material.dart';

import 'food_nutrition_formatter.dart';
import 'food_edit_page.dart';
import 'services/food_submit_service.dart';

import '../../core/models/meal_data.dart';
import '../../core/repositories/food_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';

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
    _records = FoodRepository.getAll().then((records) {
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    });
  }

  Future<void> _deleteRecord(MealData data) async {
    final result = await showHistoryDeleteDialog(
      context,
      title: data.isWaterEntry ? 'Water Record' : 'Meal Record',
    );

    if (!result) return;

    try { await FoodSubmitService.delete(data); } on ConfirmedDailyLogException catch (error) { if (mounted) showConfirmedLogMessage(context, error); return; }

    _loadRecords();

    setState(() {});
  }

  Widget _buildMealCard(BuildContext context, MealData meal) {
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
            icon: meal.isWaterEntry
                ? Icons.water_drop_outlined
                : Icons.restaurant,
            title: meal.isWaterEntry ? 'Water' : meal.mealType,
          ),
          AppSpacing.gapMD,
          if (meal.isWaterEntry)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.water_drop_outlined),
              title: Text('${meal.waterMl!.toStringAsFixed(0)} ml'),
            )
          else
            ...meal.items.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restaurant_menu),
                title: Text(
                  item.quantity > 1
                      ? '${item.name} ×${item.quantity}'
                      : item.name,
                ),
                subtitle: Text(
                  "${FoodNutritionFormatter.calories(item.totalCalories)} kcal"
                  "  P ${FoodNutritionFormatter.macro(item.totalProtein)}"
                  "  F ${FoodNutritionFormatter.macro(item.totalFat)}"
                  "  C ${FoodNutritionFormatter.macro(item.totalCarbohydrate)}",
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FOOD HISTORY')),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: FutureBuilder<List<MealData>>(
          future: _records,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = snapshot.data!;

            final groupedRecords = <String, List<MealData>>{};

            for (final meal in records) {
              groupedRecords.putIfAbsent(meal.date, () => []).add(meal);
            }

            if (records.isEmpty) {
              return const Center(child: Text('No meal records.'));
            }

            return ListView.separated(
              itemCount: groupedRecords.length,
              separatorBuilder: (_, __) => AppSpacing.gapXL,
              itemBuilder: (context, index) {
                final group = groupedRecords.entries.elementAt(index);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      icon: Icons.calendar_today,
                      title: group.key,
                    ),
                    AppSpacing.gapMD,
                    for (var mealIndex = 0;
                        mealIndex < group.value.length;
                        mealIndex++) ...[
                      _buildMealCard(context, group.value[mealIndex]),
                      if (mealIndex < group.value.length - 1)
                        AppSpacing.gapMD,
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
