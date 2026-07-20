import 'package:flutter/material.dart';

import '../../../core/models/food_item.dart';
import '../../../core/models/meal_data.dart';
import '../../../core/models/meal_type.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_description.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';

import 'food_input_fields.dart';
import 'food_item_list.dart';
import 'food_total_card.dart';

class FoodInputForm extends StatefulWidget {
  final Future<void> Function(MealData data) onSave;
  final MealData? initialMeal;

  const FoodInputForm({super.key, required this.onSave, this.initialMeal});

  @override
  State<FoodInputForm> createState() => _FoodInputFormState();
}

class _FoodInputFormState extends State<FoodInputForm> {
  final foodNameController = TextEditingController();
  final calorieController = TextEditingController();
  final proteinController = TextEditingController();
  final fatController = TextEditingController();
  final carbohydrateController = TextEditingController();
  final waterVolumeController = TextEditingController();
  final memoController = TextEditingController();

  MealType mealType = MealType.breakfast;

  final List<FoodItem> items = [];

  int? editingIndex;
  bool isWaterEntry = false;

  @override
  void initState() {
    super.initState();

    final meal = widget.initialMeal;

    if (meal == null) {
      return;
    }

    mealType = MealType.values.firstWhere(
      (e) => e.label == meal.mealType,
      orElse: () => MealType.breakfast,
    );

    memoController.text = meal.memo;
    isWaterEntry = meal.isWaterEntry;
    waterVolumeController.text = meal.waterMl?.toStringAsFixed(0) ?? '';

    items.addAll(meal.items);
  }

  @override
  void dispose() {
    foodNameController.dispose();
    calorieController.dispose();
    proteinController.dispose();
    fatController.dispose();
    carbohydrateController.dispose();
    waterVolumeController.dispose();
    memoController.dispose();
    super.dispose();
  }

  FoodItem? _currentFoodItem() {
    final name = foodNameController.text.trim();

    if (name.isEmpty) {
      return null;
    }

    return FoodItem(
      name: name,
      calories: int.tryParse(calorieController.text) ?? 0,
      protein: double.tryParse(proteinController.text) ?? 0,
      fat: double.tryParse(fatController.text) ?? 0,
      carbohydrate: double.tryParse(carbohydrateController.text) ?? 0,
    );
  }

  List<FoodItem> get previewItems {
    final result = List<FoodItem>.from(items);

    final current = _currentFoodItem();

    if (current != null) {
      result.add(current);
    }

    return result;
  }

  void _clearFoodInputs() {
    foodNameController.clear();
    calorieController.clear();
    proteinController.clear();
    fatController.clear();
    carbohydrateController.clear();
  }

  void _clearForm() {
    setState(() {
      items.clear();
      mealType = MealType.breakfast;
      memoController.clear();
      waterVolumeController.clear();
      isWaterEntry = false;
      _clearFoodInputs();
    });
  }

  void addFood() {
    final item = _currentFoodItem();

    if (item == null) {
      return;
    }

    setState(() {
      items.add(item);
      _clearFoodInputs();
    });
  }

  void removeFood(int index) {
    setState(() {
      items.removeAt(index);

      if (editingIndex == index) {
        editingIndex = null;
        _clearFoodInputs();
      } else if (editingIndex != null && editingIndex! > index) {
        editingIndex = editingIndex! - 1;
      }
    });
  }

  void editFood(int index) {
    final item = items[index];

    setState(() {
      editingIndex = index;

      foodNameController.text = item.name;
      calorieController.text = item.calories.toString();
      proteinController.text = item.protein.toString();
      fatController.text = item.fat.toString();
      carbohydrateController.text = item.carbohydrate.toString();
    });
  }

  void updateFood() {
    if (editingIndex == null) return;

    final item = _currentFoodItem();

    if (item == null) return;

    setState(() {
      items[editingIndex!] = item;

      editingIndex = null;

      _clearFoodInputs();
    });
  }

  Future<void> saveMeal() async {
    final waterMl = double.tryParse(waterVolumeController.text.trim());

    if (isWaterEntry && (waterMl == null || waterMl <= 0)) {
      return;
    }

    if (!isWaterEntry && previewItems.isEmpty) {
      return;
    }

    final meal = MealData(
      id:
          widget.initialMeal?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      date:
          widget.initialMeal?.date ??
          DateTime.now().toIso8601String().split('T').first,
      mealType: isWaterEntry ? 'Water' : mealType.label,
      items: isWaterEntry ? const [] : previewItems,
      memo: memoController.text.trim(),
      waterMl: isWaterEntry ? waterMl : null,
    );

    await widget.onSave(meal);

    if (!mounted) return;

    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    final preview = editingIndex == null ? previewItems : items;

    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.restaurant,
            title: widget.initialMeal == null ? 'FOOD ENTRY' : 'EDIT MEAL',
          ),
          AppSpacing.gapSM,

          const OperationDescription(text: '1食に複数の食品を追加して記録します。'),

          AppSpacing.gapXL,

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Entry Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          AppSpacing.gapMD,

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.restaurant, size: 18),
                label: const Text('Meal'),
                selected: !isWaterEntry,
                onSelected: (_) => setState(() => isWaterEntry = false),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.water_drop_outlined, size: 18),
                label: const Text('Water'),
                selected: isWaterEntry,
                onSelected: (_) => setState(() => isWaterEntry = true),
              ),
            ],
          ),

          AppSpacing.gapXL,

          if (isWaterEntry) ...[
            const SectionHeader(
              icon: Icons.water_drop_outlined,
              title: 'Water Entry',
            ),

            AppSpacing.gapMD,

            OperationTextField(
              controller: waterVolumeController,
              label: 'Water Volume (ml)',
              keyboardType: TextInputType.number,
            ),

            AppSpacing.gapXL,

            OperationButton(
              icon: Icons.water_drop_outlined,
              text: widget.initialMeal == null ? 'Save Water' : 'Update Water',
              onPressed: saveMeal,
            ),
          ] else ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Meal Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          AppSpacing.gapMD,

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MealType.values.map((type) {
              return ChoiceChip(
                avatar: Icon(type.icon, size: 18),
                label: Text(type.label),
                selected: mealType == type,
                onSelected: (_) {
                  setState(() {
                    mealType = type;
                  });
                },
              );
            }).toList(),
          ),

          AppSpacing.gapXL,

          const SectionHeader(
            icon: Icons.restaurant_menu,
            title: 'Add Food Item',
          ),

          AppSpacing.gapMD,

          FoodInputFields(
            foodNameController: foodNameController,
            calorieController: calorieController,
            proteinController: proteinController,
            fatController: fatController,
            carbohydrateController: carbohydrateController,
            onChanged: (_) => setState(() {}),
          ),

          AppSpacing.gapLG,

          if (preview.isNotEmpty) ...[
            AppSpacing.gapXL,

            FoodItemList(items: preview, onDelete: removeFood, onTap: editFood),

            AppSpacing.gapLG,

            OperationButton(
              icon: editingIndex == null
                  ? Icons.add_circle_outline
                  : Icons.edit_outlined,
              text: editingIndex == null ? 'Add Another Food' : 'Update Food',
              onPressed: editingIndex == null ? addFood : updateFood,
            ),

            AppSpacing.gapXL,

            FoodTotalCard(items: preview),

            AppSpacing.gapLG,

            OperationTextField(
              controller: memoController,
              label: 'Meal Memo',
              maxLines: 3,
            ),

            AppSpacing.gapXL,

            OperationButton(
              icon: Icons.save,
              text: widget.initialMeal == null ? 'Save Meal' : 'Update Meal',
              onPressed: saveMeal,
            ),
          ],
          ],
        ],
      ),
    );
  }
}
