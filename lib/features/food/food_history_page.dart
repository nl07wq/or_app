import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/section_header.dart';
import '../repositories/app_repository_container.dart';
import 'daily_meal_v2_page.dart';
import 'food_edit_page.dart';
import 'models/food_nutrition_aggregate.dart';
import 'models/food_unified_read_model.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({super.key});

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  late Future<List<FoodUnifiedReadModel>> _future = _load();

  Future<List<FoodUnifiedReadModel>> _load() =>
      AppRepositoryRegistry.container.foodMixedRead.readHistory();

  void _refresh() => setState(() {
    _future = _load();
  });

  Future<void> _open(FoodUnifiedReadModel record, {required bool edit}) async {
    switch (record.identity.recordKind) {
      case FoodRecordKind.legacyV1:
        final meal = await AppRepositoryRegistry.container.food.findById(
          record.identity.recordId,
        );
        if (meal == null || !mounted) return;
        if (edit) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FoodEditPage(meal: meal)),
          );
        } else {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(meal.mealType),
              content: Text(
                meal.isWaterEntry
                    ? '${meal.waterMl!.toStringAsFixed(0)} ml'
                    : meal.items.map((value) => value.name).join('\n'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          );
        }
      case FoodRecordKind.dailyMealV2:
        final meal = await AppRepositoryRegistry.container.dailyMealsV2
            .readById(record.identity.recordId);
        if (meal == null || !mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => edit
                ? DailyMealV2Page(meal: meal)
                : DailyMealV2DetailPage(meal: meal),
          ),
        );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('RECORD')),
    body: FutureBuilder<List<FoodUnifiedReadModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load food records.'),
                Text('${snapshot.error}'),
                AppSpacing.gapMD,
                SizedBox(
                  width: 240,
                  child: OperationButton(
                    text: 'RETRY',
                    icon: Icons.refresh,
                    onPressed: _refresh,
                  ),
                ),
              ],
            ),
          );
        }
        final values = snapshot.data!;
        if (values.isEmpty) {
          return const Center(child: Text('No meal records.'));
        }
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(icon: Icons.bolt, title: 'RECENT'),
            AppSpacing.gapSM,
            Text(values.take(3).map((value) => value.displayName).join(' · ')),
            AppSpacing.gapXL,
            for (final record in values) ...[
              OperationCard(
                child: InkWell(
                  onTap: () => _open(record, edit: false),
                  child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.localDate,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _open(record, edit: true),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                        Text(_mealLabel(record.mealType)),
                        if (record.waterMl == null)
                          for (final item in record.items)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.quantityLabel.isEmpty
                                      ? item.displayName
                                      : '${item.displayName}  ${item.quantityLabel}',
                                ),
                                Text(
                                  '${item.nutrition.calories?.toStringAsFixed(0) ?? 'Unknown'} kcal'
                                  '  Protein ${item.nutrition.protein?.toStringAsFixed(1) ?? 'Unknown'}'
                                  '  Fat ${item.nutrition.fat?.toStringAsFixed(1) ?? 'Unknown'}'
                                  '  Carbohydrate ${item.nutrition.carbohydrate?.toStringAsFixed(1) ?? 'Unknown'}',
                                ),
                              ],
                            ),
                        Text(
                          record.waterMl == null
                              ? '${record.items.length} items · ${_completeness(record.nutritionCompleteness)}'
                              : '${record.waterMl!.toStringAsFixed(0)} ml',
                        ),
                        if (record.waterMl == null)
                          Text(_nutrition(record.nutritionAggregate)),
                        if (record.memo != null) const Text('Memo recorded'),
                      ],
                    ),
                  ),
                ),
              ),
              AppSpacing.gapMD,
            ],
          ],
        );
      },
    ),
  );
}

String _completeness(FoodNutritionCompleteness value) =>
    value.name.toUpperCase();
String _mealLabel(String value) => switch (value) {
  'breakfast' => 'Breakfast',
  'lunch' => 'Lunch',
  'dinner' => 'Dinner',
  'snack' => 'Snack',
  'training' => 'Training',
  'water' => 'Water',
  _ => value,
};
String _nutrition(FoodNutritionAggregate value) =>
    'Calories ${_known(value.calories)} · P ${_known(value.protein)} · '
    'F ${_known(value.fat)} · C ${_known(value.carbohydrate)}';
String _known(FoodNutritionValueAggregate value) =>
    value.knownItemCount == 0 ? 'Unknown' : value.knownTotal.toStringAsFixed(1);
