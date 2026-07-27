import 'package:flutter/material.dart';

import 'food_nutrition_formatter.dart';
import 'food_edit_page.dart';
import 'services/food_submit_service.dart';

import '../../core/models/meal_data.dart';
import '../../core/models/food_item.dart';
import '../../core/repositories/food_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/state/app_initialization_state.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({super.key});

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  bool _isLoading = true;
  List<MealData> _records = const [];
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRecords(showLoading: false);
  }

  Future<void> _loadRecords({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    List<MealData>? loadedRecords;
    Object? loadError;
    try {
      loadedRecords = (await FoodRepository.getAll()).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (error) {
      loadError = error;
    } finally {
      if (mounted) {
        setState(() {
          if (loadError == null) {
            _records = List.unmodifiable(loadedRecords!);
          }
          _loadError = loadError;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRecord(MealData data) async {
    final result = await showHistoryDeleteDialog(
      context,
      title: data.isWaterEntry ? 'Water Record' : 'Meal Record',
    );

    if (!result) return;

    try {
      await FoodSubmitService.delete(data);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    }

    await _loadRecords();
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
                onPressed: appInitializationController.value.isReadOnly
                    ? null
                    : () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FoodEditPage(meal: meal),
                          ),
                        );

                        if (updated == true) {
                          await _loadRecords();
                        }
                      },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: appInitializationController.value.isReadOnly
                    ? null
                    : () => _deleteRecord(meal),
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
                  item.hasMeasuredAmount
                      ? item.amountMode == FoodAmountMode.baseMultiplier
                            ? '${item.name}  AMOUNT '
                                  '${FoodNutritionFormatter.amount(item.amount!)}'
                                  ' (${FoodNutritionFormatter.amount(item.physicalAmount!)}'
                                  '${item.baseUnit!.label})'
                            : '${item.name}  '
                                  '${FoodNutritionFormatter.amount(item.amount!)}'
                                  '${item.baseUnit!.label}'
                      : item.quantity > 1
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
      appBar: AppBar(title: const Text('FOOD')),
      body: Padding(padding: AppSpacing.cardPadding, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final loadError = _loadError;
    if (loadError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Unable to load food records.',
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapMD,
              Text(
                loadError.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              AppSpacing.gapMD,
              OperationButton(
                icon: Icons.refresh,
                text: 'RETRY',
                onPressed: _loadRecords,
              ),
            ],
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return const Center(child: Text('No meal records.'));
    }

    final groupedRecords = <String, List<MealData>>{};
    for (final meal in _records) {
      groupedRecords.putIfAbsent(meal.date, () => []).add(meal);
    }
    return ListView.separated(
      itemCount: groupedRecords.length,
      separatorBuilder: (_, _) => AppSpacing.gapXL,
      itemBuilder: (context, index) {
        final group = groupedRecords.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(icon: Icons.calendar_today, title: group.key),
            AppSpacing.gapMD,
            for (
              var mealIndex = 0;
              mealIndex < group.value.length;
              mealIndex++
            ) ...[
              _buildMealCard(context, group.value[mealIndex]),
              if (mealIndex < group.value.length - 1) AppSpacing.gapMD,
            ],
          ],
        );
      },
    );
  }
}
