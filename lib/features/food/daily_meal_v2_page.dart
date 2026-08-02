import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../operation_date/services/operation_date_service.dart';
import '../repositories/app_repository_container.dart';
import 'models/daily_meal_v2_models.dart';
import 'models/food_catalog_models.dart';
import 'models/food_provenance_models.dart';
import 'models/food_quantity_models.dart';
import 'models/food_unified_read_model.dart';
import 'models/nutrition_models.dart';
import 'models/recipe_models_v2.dart';
import 'services/food_application_service.dart';

class DailyMealV2Page extends StatefulWidget {
  final DailyMealV2? meal;
  final OperationDateService operationDateService;

  const DailyMealV2Page({
    super.key,
    this.meal,
    this.operationDateService = const OperationDateService(),
  });

  @override
  State<DailyMealV2Page> createState() => _DailyMealV2PageState();
}

class _DailyMealV2PageState extends State<DailyMealV2Page> {
  final _memo = TextEditingController();
  final _water = TextEditingController();
  String? _localDate;
  Object? _error;
  late DailyMealTypeV2 _mealType =
      widget.meal?.mealType ?? DailyMealTypeV2.breakfast;
  late List<DailyMealItemSnapshot> _items = [...?widget.meal?.items];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _memo.text = widget.meal?.memo ?? '';
    _water.text = widget.meal?.waterMl?.toString() ?? '';
    _resolveDate();
  }

  Future<void> _resolveDate() async {
    try {
      _localDate =
          widget.meal?.localDate ??
          (await widget.operationDateService.current()).value;
    } catch (error) {
      _error = error;
    }
    if (mounted) setState(() {});
  }

  Future<FoodQuantityDefinition?> _quantityDialog(
    FoodQuantityDefinition initial,
  ) async {
    final value = TextEditingController(text: initial.value.toString());
    var unit = initial.unit;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Quantity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: value,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              DropdownButtonFormField(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: FoodQuantityUnit.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(_unitLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (next) => setDialogState(() => unit = next!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(value.text.trim());
    if (result != true || amount == null || amount <= 0) return null;
    return FoodQuantityDefinition(value: amount, unit: unit);
  }

  Future<void> _addCatalog() async {
    final values = (await AppRepositoryRegistry.container.foodCatalog.list())
        .where((value) => !value.isArchived)
        .toList();
    if (!mounted) return;
    final selected = await showDialog<FoodCatalogEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('ADD FROM FOOD DATABASE'),
        children: [
          for (final value in values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(value.name),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final quantity = await _quantityDialog(selected.baseQuantity);
    if (quantity == null) return;
    setState(
      () => _items.add(
        FoodApplicationService.itemFromCatalog(
          selected,
          quantity,
          _items.length,
        ),
      ),
    );
  }

  Future<void> _addRecipe() async {
    final values = (await AppRepositoryRegistry.container.foodRecipes.list())
        .where((value) => !value.isArchived)
        .toList();
    if (!mounted) return;
    final selected = await showDialog<FoodRecipeDefinition>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('ADD FROM RECIPE DATABASE'),
        children: [
          for (final value in values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(value.name),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final quantity = await _quantityDialog(
      FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.serving),
    );
    if (quantity == null) return;
    setState(
      () => _items.add(
        FoodApplicationService.itemFromRecipe(
          selected,
          quantity,
          _items.length,
        ),
      ),
    );
  }

  Future<void> _addCustom() async {
    final name = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final calories = TextEditingController();
    final protein = TextEditingController();
    final fat = TextEditingController();
    final carbs = TextEditingController();
    var unit = FoodQuantityUnit.serving;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ADD CUSTOM ITEM'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantity,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField(
                        initialValue: unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: FoodQuantityUnit.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_unitLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => unit = value!),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: calories,
                  decoration: const InputDecoration(labelText: 'Calories'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: protein,
                  decoration: const InputDecoration(labelText: 'Protein'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: fat,
                  decoration: const InputDecoration(labelText: 'Fat'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: carbs,
                  decoration: const InputDecoration(labelText: 'Carbohydrate'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ADD'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(quantity.text);
    if (result != true ||
        name.text.trim().isEmpty ||
        amount == null ||
        amount <= 0) {
      return;
    }
    double? optional(TextEditingController value) =>
        value.text.trim().isEmpty ? null : double.tryParse(value.text.trim());
    final nutrition = NutritionSnapshot(
      calories: optional(calories),
      protein: optional(protein),
      fat: optional(fat),
      carbohydrate: optional(carbs),
    );
    setState(
      () => _items.add(
        DailyMealItemSnapshot(
          mealItemId: FoodApplicationService.newId(),
          nameSnapshot: name.text.trim(),
          quantity: FoodQuantityDefinition(value: amount, unit: unit),
          nutritionPerBase: nutrition,
          nutritionConsumed: nutrition,
          provenanceSnapshot: FoodApplicationService.provenance(
            FoodProvenanceSourceType.userInput,
          ),
          nutritionStatusSnapshot: nutrition.isEmpty
              ? NutritionStatus.unknown
              : NutritionStatus.estimated,
          sortOrder: _items.length,
        ),
      ),
    );
  }

  Future<void> _editNutrition(int index) async {
    final item = _items[index];
    final calories = TextEditingController(
      text: item.nutritionConsumed.calories?.toString() ?? '',
    );
    final protein = TextEditingController(
      text: item.nutritionConsumed.protein?.toString() ?? '',
    );
    final fat = TextEditingController(
      text: item.nutritionConsumed.fat?.toString() ?? '',
    );
    final carbohydrate = TextEditingController(
      text: item.nutritionConsumed.carbohydrate?.toString() ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consumed Nutrition'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: calories,
                decoration: const InputDecoration(labelText: 'Calories'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: protein,
                decoration: const InputDecoration(labelText: 'Protein'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: fat,
                decoration: const InputDecoration(labelText: 'Fat'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: carbohydrate,
                decoration: const InputDecoration(labelText: 'Carbohydrate'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const Text(
                'Use only confirmed values. Empty fields remain unknown.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    double? optional(TextEditingController value) =>
        value.text.trim().isEmpty ? null : double.tryParse(value.text.trim());
    final nutrition = NutritionSnapshot(
      calories: optional(calories),
      protein: optional(protein),
      fat: optional(fat),
      carbohydrate: optional(carbohydrate),
    );
    setState(
      () => _items[index] = DailyMealItemSnapshot.fromJson({
        ...item.toJson(),
        'nutritionConsumed': nutrition.toJson(),
        'nutritionStatusSnapshot': nutrition.isEmpty
            ? NutritionStatus.unknown.stableId
            : item.nutritionStatusSnapshot == NutritionStatus.unknown
            ? NutritionStatus.estimated.stableId
            : item.nutritionStatusSnapshot.stableId,
      }),
    );
  }

  Future<void> _addRecent() async {
    final recent = await AppRepositoryRegistry.container.foodMixedRead
        .readRecent(5);
    if (!mounted) return;
    final selected = await showDialog<FoodRecordIdentity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('RECENT'),
        children: [
          for (final value in recent)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value.identity),
              child: Text('${value.localDate} · ${value.displayName}'),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.recordKind == FoodRecordKind.legacyV1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Legacy quantity cannot be inferred. Use ADD CUSTOM ITEM.',
          ),
        ),
      );
      return;
    }
    final meal = await AppRepositoryRegistry.container.dailyMealsV2.readById(
      selected.recordId,
    );
    if (meal == null || meal.items.isEmpty || !mounted) return;
    setState(() {
      for (final source in meal.items) {
        _items.add(
          DailyMealItemSnapshot.fromJson({
            ...source.toJson(),
            'mealItemId': FoodApplicationService.newId(),
            'sortOrder': _items.length,
          }),
        );
      }
    });
  }

  void _remove(int index) => setState(() {
    _items.removeAt(index);
    _items = [
      for (var i = 0; i < _items.length; i++)
        DailyMealItemSnapshot.fromJson({..._items[i].toJson(), 'sortOrder': i}),
    ];
  });

  Future<void> _save() async {
    final localDate = _localDate;
    if (localDate == null || _saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc();
      final water = _water.text.trim().isEmpty
          ? null
          : double.parse(_water.text.trim());
      final meal = DailyMealV2(
        mealId: widget.meal?.mealId ?? FoodApplicationService.newId(),
        localDate: localDate,
        mealType: _mealType,
        items: _mealType == DailyMealTypeV2.water ? const [] : _items,
        memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
        waterMl: water,
        createdAt: widget.meal?.createdAt ?? now,
        updatedAt: now,
      );
      if (widget.meal == null) {
        await FoodApplicationService.createMeal(meal);
      } else {
        await FoodApplicationService.updateMeal(meal);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.meal == null ? 'MEALを保存しました' : 'MEALを更新しました'),
          ),
        );
        Navigator.popUntil(context, ModalRoute.withName(AppRoutes.food));
      }
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) {
        showConfirmedLogMessage(context, error);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localDate == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('FOOD')),
        body: Center(child: Text('Unable to resolve Operation Date.\n$_error')),
      );
    }
    final water = _mealType == DailyMealTypeV2.water;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meal == null ? 'MANUAL ENTRY' : 'UPDATE MEAL'),
      ),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          Text('Operation Date: $_localDate'),
          AppSpacing.gapMD,
          DropdownButtonFormField(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: 'Meal Type'),
            items: DailyMealTypeV2.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_mealTypeLabel(value)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _mealType = value!),
          ),
          TextField(
            controller: _memo,
            decoration: const InputDecoration(labelText: 'Memo'),
          ),
          TextField(
            controller: _water,
            decoration: InputDecoration(
              labelText: water ? 'Water Ml' : 'Water Ml (Optional)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (!water) ...[
            AppSpacing.gapLG,
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _mealAction(
                  'ADD FROM FOOD DATABASE',
                  Icons.restaurant,
                  _addCatalog,
                ),
                _mealAction(
                  'ADD FROM RECIPE DATABASE',
                  Icons.menu_book,
                  _addRecipe,
                ),
                _mealAction('ADD CUSTOM ITEM', Icons.add, _addCustom),
              ],
            ),
            _mealAction('ADD FROM RECENT', Icons.history, _addRecent),
            AppSpacing.gapMD,
            for (var i = 0; i < _items.length; i++) ...[
              OperationCard(
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(_items[i].nameSnapshot),
                  subtitle: Text(
                    '${_items[i].quantity.value} ${_unitLabel(_items[i].quantity.unit)} · ${_sourceLabel(_items[i])}\nCalories ${_items[i].nutritionConsumed.calories?.toStringAsFixed(1) ?? 'Unknown'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit consumed nutrition',
                        icon: const Icon(Icons.monitor_heart_outlined),
                        onPressed: () => _editNutrition(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(i),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.gapSM,
            ],
          ],
          AppSpacing.gapLG,
          OperationButton(
            text: widget.meal == null ? 'SAVE MEAL' : 'UPDATE MEAL',
            icon: Icons.save,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class DailyMealV2DetailPage extends StatelessWidget {
  final DailyMealV2 meal;
  const DailyMealV2DetailPage({super.key, required this.meal});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MEAL DETAIL'),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DailyMealV2Page(meal: meal)),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        Text(meal.localDate, style: Theme.of(context).textTheme.titleLarge),
        Text(_mealTypeLabel(meal.mealType)),
        AppSpacing.gapMD,
        if (meal.mealType == DailyMealTypeV2.water)
          Text('${meal.waterMl!.toStringAsFixed(0)} ml'),
        for (final item in meal.items) ...[
          OperationCard(
            child: ListTile(
              title: Text(item.nameSnapshot),
              subtitle: Text(
                '${item.quantity.value} ${_unitLabel(item.quantity.unit)}\nCalories ${item.nutritionConsumed.calories?.toStringAsFixed(1) ?? 'Unknown'} · P ${item.nutritionConsumed.protein?.toStringAsFixed(1) ?? 'Unknown'} · F ${item.nutritionConsumed.fat?.toStringAsFixed(1) ?? 'Unknown'} · C ${item.nutritionConsumed.carbohydrate?.toStringAsFixed(1) ?? 'Unknown'}',
              ),
            ),
          ),
          AppSpacing.gapSM,
        ],
        if (meal.memo != null) Text(meal.memo!),
      ],
    ),
  );
}

String _mealTypeLabel(DailyMealTypeV2 value) => switch (value) {
  DailyMealTypeV2.breakfast => 'Breakfast',
  DailyMealTypeV2.lunch => 'Lunch',
  DailyMealTypeV2.dinner => 'Dinner',
  DailyMealTypeV2.snack => 'Snack',
  DailyMealTypeV2.training => 'Training',
  DailyMealTypeV2.water => 'Water',
};
String _unitLabel(FoodQuantityUnit value) => switch (value) {
  FoodQuantityUnit.gram => 'Gram',
  FoodQuantityUnit.milliliter => 'Milliliter',
  FoodQuantityUnit.piece => 'Piece',
  FoodQuantityUnit.pack => 'Pack',
  FoodQuantityUnit.serving => 'Serving',
};
String _sourceLabel(DailyMealItemSnapshot item) => item.foodReferenceId != null
    ? 'Food Database'
    : item.recipeReferenceId != null
    ? 'Recipe Database'
    : 'Custom';

Widget _mealAction(String text, IconData icon, VoidCallback onPressed) =>
    SizedBox(
      width: 250,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
            ),
          ],
        ),
      ),
    );
