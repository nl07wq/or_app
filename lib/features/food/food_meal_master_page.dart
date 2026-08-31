import 'package:flutter/material.dart';

import '../../core/state/app_initialization_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_text_field.dart';
import 'food_catalog_page.dart';
import 'food_nutrition_formatter.dart';
import 'models/food_catalog_models.dart';
import 'models/food_meal_master_models.dart';
import 'models/food_quantity_models.dart';
import 'models/recipe_models_v2.dart';
import 'repository/food_catalog_repository.dart';
import 'repository/food_meal_id_generator.dart';
import 'repository/food_meal_master_repository.dart';
import 'repository/food_recipe_repository.dart';

class FoodMealMasterEditorPage extends StatefulWidget {
  const FoodMealMasterEditorPage({
    super.key,
    required this.repository,
    required this.catalogRepository,
    required this.recipeRepository,
    this.initialMeal,
    this.now,
    this.idGenerator,
  });

  final FoodMealMasterRepository repository;
  final FoodCatalogRepository catalogRepository;
  final FoodRecipeRepository recipeRepository;
  final FoodMealMaster? initialMeal;
  final DateTime Function()? now;
  final FoodMealIdGenerator? idGenerator;

  @override
  State<FoodMealMasterEditorPage> createState() =>
      _FoodMealMasterEditorPageState();
}

class _FoodMealMasterEditorPageState extends State<FoodMealMasterEditorPage> {
  final _name = TextEditingController();
  final _memo = TextEditingController();
  final List<FoodMealMasterComponent> _components = [];
  Map<String, FoodCatalogEntry> _foods = const {};
  Map<String, FoodRecipeDefinition> _recipes = const {};
  bool _saving = false;
  String? _error;

  DateTime get _now => (widget.now ?? DateTime.now)().toUtc();
  FoodMealIdGenerator get _ids => widget.idGenerator ?? FoodMealIdGenerator();

  @override
  void initState() {
    super.initState();
    final meal = widget.initialMeal;
    if (meal != null) {
      _name.text = meal.name;
      _memo.text = meal.memo ?? '';
      _components.addAll(meal.components);
    }
    _loadSources();
  }

  Future<void> _loadSources() async {
    try {
      final values = await Future.wait([
        widget.catalogRepository.list(),
        widget.recipeRepository.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _foods = {
          for (final value in values[0] as List<FoodCatalogEntry>)
            value.foodId: value,
        };
        _recipes = {
          for (final value in values[1] as List<FoodRecipeDefinition>)
            if (!value.isArchived) value.recipeId: value,
        };
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'MEAL SOURCES LOAD FAILED');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _addComponent() async {
    final source = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogPage(
          repository: widget.catalogRepository,
          recipeRepository: widget.recipeRepository,
          mealRepository: widget.repository,
          selectionMode: true,
          mealsEnabled: false,
        ),
      ),
    );
    if (source == null || !mounted) return;
    final FoodQuantityDefinition initial;
    final FoodMealMasterComponentType type;
    final String? foodId;
    final String? recipeId;
    final String name;
    if (source case final FoodCatalogEntry food) {
      initial = food.baseQuantity;
      type = FoodMealMasterComponentType.food;
      foodId = food.foodId;
      recipeId = null;
      name = food.name;
    } else if (source case final FoodRecipeDefinition recipe) {
      final servings = recipe.servingCount ?? 1;
      initial = recipe.yieldQuantity.unit == FoodQuantityUnit.serving
          ? FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.serving)
          : FoodQuantityDefinition(
              value: recipe.yieldQuantity.value / servings,
              unit: recipe.yieldQuantity.unit,
            );
      type = FoodMealMasterComponentType.recipe;
      foodId = null;
      recipeId = recipe.recipeId;
      name = recipe.name;
    } else {
      return;
    }
    final quantity = await _chooseQuantity(name, initial);
    if (quantity == null || !mounted) return;
    setState(() {
      _components.add(
        FoodMealMasterComponent(
          componentId: _id(),
          componentType: type,
          foodReferenceId: foodId,
          recipeReferenceId: recipeId,
          quantity: quantity,
          sortOrder: _components.length,
        ),
      );
      _error = null;
    });
  }

  Future<FoodQuantityDefinition?> _chooseQuantity(
    String name,
    FoodQuantityDefinition initial,
  ) {
    final controller = TextEditingController(
      text: FoodNutritionFormatter.amount(initial.value),
    );
    return showDialog<FoodQuantityDefinition>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: OperationTextField(
          key: const ValueKey('meal-master-component-quantity'),
          controller: controller,
          label:
              'AMOUNT (${FoodNutritionFormatter.quantityUnit(initial.unit)})',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value.isFinite && value > 0) {
                Navigator.pop(
                  context,
                  FoodQuantityDefinition(value: value, unit: initial.unit),
                );
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _editQuantity(int index) async {
    final component = _components[index];
    final quantity = await _chooseQuantity(
      _componentName(component),
      component.quantity,
    );
    if (quantity == null || !mounted) return;
    setState(() {
      _components[index] = FoodMealMasterComponent.fromJson({
        ...component.toJson(),
        'quantity': quantity.toJson(),
      });
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _components.length) return;
    setState(() {
      final value = _components.removeAt(index);
      _components.insert(target, value);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty || _components.isEmpty) {
      setState(() => _error = 'ENTER A NAME AND AT LEAST ONE ITEM');
      return;
    }
    final timestamp = _now;
    final initial = widget.initialMeal;
    final meal = FoodMealMaster(
      mealMasterId: initial?.mealMasterId ?? _id(),
      name: name,
      memo: _nullable(_memo.text),
      components: [
        for (var index = 0; index < _components.length; index++)
          FoodMealMasterComponent.fromJson({
            ..._components[index].toJson(),
            'sortOrder': index,
          }),
      ],
      isArchived: initial?.isArchived ?? false,
      createdAt: initial?.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (initial == null) {
        await widget.repository.create(meal);
      } else {
        await widget.repository.update(meal);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'MEAL SAVE FAILED');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final meal = widget.initialMeal;
    if (meal == null) return;
    await widget.repository.archive(meal.mealMasterId);
    if (mounted) Navigator.pop(context, true);
  }

  String _componentName(FoodMealMasterComponent component) =>
      switch (component.componentType) {
        FoodMealMasterComponentType.food =>
          _foods[component.foodReferenceId]?.name ?? 'UNAVAILABLE FOOD',
        FoodMealMasterComponentType.recipe =>
          _recipes[component.recipeReferenceId]?.name ?? 'UNAVAILABLE RECIPE',
      };

  @override
  Widget build(BuildContext context) {
    final readOnly = appInitializationController.value.isReadOnly;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialMeal == null ? 'CREATE MEAL' : 'EDIT MEAL'),
      ),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          OperationTextField(
            key: const ValueKey('meal-master-name'),
            controller: _name,
            label: 'MEAL NAME',
          ),
          AppSpacing.gapMD,
          OperationTextField(
            key: const ValueKey('meal-master-memo'),
            controller: _memo,
            label: 'MEMO',
            maxLines: 3,
          ),
          AppSpacing.gapLG,
          Text('ITEMS', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          for (var index = 0; index < _components.length; index++) ...[
            OperationCard(
              child: ListTile(
                key: ValueKey('meal-master-component-$index'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _components[index].componentType ==
                          FoodMealMasterComponentType.food
                      ? Icons.restaurant_outlined
                      : Icons.menu_book_outlined,
                ),
                title: Text(_componentName(_components[index])),
                subtitle: Text(
                  FoodNutritionFormatter.compactQuantity(
                    _components[index].quantity,
                  ),
                ),
                onTap: readOnly ? null : () => _editQuantity(index),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'MOVE UP',
                      onPressed: readOnly || index == 0
                          ? null
                          : () => _move(index, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'MOVE DOWN',
                      onPressed: readOnly || index == _components.length - 1
                          ? null
                          : () => _move(index, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'REMOVE',
                      onPressed: readOnly
                          ? null
                          : () => setState(() => _components.removeAt(index)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.gapSM,
          ],
          OperationButton(
            key: const ValueKey('meal-master-add-component'),
            icon: Icons.add,
            text: 'ADD FOOD / RECIPE',
            onPressed: readOnly || _saving ? null : _addComponent,
          ),
          if (_error != null) ...[
            AppSpacing.gapSM,
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          AppSpacing.gapLG,
          OperationButton(
            key: const ValueKey('meal-master-save'),
            icon: Icons.save_outlined,
            text: 'SAVE MEAL',
            role: OperationActionRole.primary,
            onPressed: readOnly || _saving ? null : _save,
          ),
          if (widget.initialMeal != null) ...[
            AppSpacing.gapSM,
            OperationButton(
              key: const ValueKey('meal-master-archive'),
              icon: Icons.archive_outlined,
              text: 'ARCHIVE MEAL',
              role: OperationActionRole.danger,
              onPressed: readOnly || _saving ? null : _archive,
            ),
          ],
        ],
      ),
    );
  }

  String _id() {
    final value = _ids.generate();
    return value.startsWith('food:') ? value.substring(5) : value;
  }
}

String? _nullable(String source) {
  final value = source.trim();
  return value.isEmpty ? null : value;
}
