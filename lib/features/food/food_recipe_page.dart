import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../repositories/app_repository_container.dart';
import 'models/food_catalog_models.dart';
import 'models/food_provenance_models.dart';
import 'models/food_quantity_models.dart';
import 'models/nutrition_models.dart';
import 'models/recipe_models_v2.dart';
import 'services/food_application_service.dart';

class FoodRecipePage extends StatefulWidget {
  const FoodRecipePage({super.key});

  @override
  State<FoodRecipePage> createState() => _FoodRecipePageState();
}

class _FoodRecipePageState extends State<FoodRecipePage> {
  bool _showArchived = false;
  late Future<List<FoodRecipeDefinition>> _future = _load();
  Future<List<FoodRecipeDefinition>> _load() =>
      AppRepositoryRegistry.container.foodRecipes.list();
  void _refresh() => setState(() => _future = _load());

  Future<void> _open([FoodRecipeDefinition? recipe]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FoodRecipeEditorPage(recipe: recipe)),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('RECIPE DATABASE')),
    body: FutureBuilder<List<FoodRecipeDefinition>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final values = snapshot.data!
            .where((value) => _showArchived || !value.isArchived)
            .toList();
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            OperationButton(
              icon: Icons.add,
              text: 'ADD RECIPE',
              onPressed: _open,
            ),
            AppSpacing.gapMD,
            SwitchListTile(
              title: const Text('Show archived'),
              value: _showArchived,
              onChanged: (value) => setState(() => _showArchived = value),
            ),
            if (values.isEmpty) const Center(child: Text('No recipes.')),
            for (final recipe in values) ...[
              OperationCard(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.menu_book),
                  title: Text(recipe.name),
                  subtitle: Text(
                    '${recipe.ingredients.length} ingredients${recipe.isArchived ? ' · Archived' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(recipe),
                ),
              ),
              AppSpacing.gapSM,
            ],
          ],
        );
      },
    ),
  );
}

class FoodRecipeEditorPage extends StatefulWidget {
  final FoodRecipeDefinition? recipe;
  const FoodRecipeEditorPage({super.key, this.recipe});

  @override
  State<FoodRecipeEditorPage> createState() => _FoodRecipeEditorPageState();
}

class _FoodRecipeEditorPageState extends State<FoodRecipeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.recipe?.name);
  late final _yield = TextEditingController(
    text: '${widget.recipe?.yieldQuantity.value ?? 1}',
  );
  late final _servings = TextEditingController(
    text: widget.recipe?.servingCount?.toString(),
  );
  late final _memo = TextEditingController(text: widget.recipe?.memo);
  late FoodQuantityUnit _yieldUnit =
      widget.recipe?.yieldQuantity.unit ?? FoodQuantityUnit.serving;
  late List<RecipeIngredientV2> _ingredients = [...?widget.recipe?.ingredients];
  bool _saving = false;

  Future<void> _addCatalog() async {
    final catalog = (await AppRepositoryRegistry.container.foodCatalog.list())
        .where((value) => !value.isArchived)
        .toList();
    if (!mounted) return;
    final selected = await showDialog<FoodCatalogEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('ADD FROM FOOD DATABASE'),
        children: [
          for (final value in catalog)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(value.name),
            ),
        ],
      ),
    );
    if (selected == null) return;
    setState(
      () => _ingredients.add(
        RecipeIngredientV2(
          ingredientId: FoodApplicationService.newId(),
          foodReferenceId: selected.foodId,
          nameSnapshot: selected.name,
          quantity: selected.baseQuantity,
          nutritionSnapshot: selected.nutrition,
          nutritionStatus: selected.nutritionStatus,
          provenanceSnapshot: selected.provenance,
          sortOrder: _ingredients.length,
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
    final carbohydrate = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ADD CUSTOM ITEM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: quantity,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              controller: carbohydrate,
              decoration: const InputDecoration(labelText: 'Carbohydrate'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
    );
    final amount = double.tryParse(quantity.text);
    if (result != true ||
        name.text.trim().isEmpty ||
        amount == null ||
        amount <= 0) {
      return;
    }
    double? optional(TextEditingController controller) =>
        controller.text.trim().isEmpty
        ? null
        : double.tryParse(controller.text.trim());
    final nutrition = NutritionSnapshot(
      calories: optional(calories),
      protein: optional(protein),
      fat: optional(fat),
      carbohydrate: optional(carbohydrate),
    );
    setState(
      () => _ingredients.add(
        RecipeIngredientV2(
          ingredientId: FoodApplicationService.newId(),
          nameSnapshot: name.text.trim(),
          quantity: FoodQuantityDefinition(
            value: amount,
            unit: FoodQuantityUnit.serving,
          ),
          nutritionSnapshot: nutrition,
          nutritionStatus: nutrition.isEmpty
              ? NutritionStatus.unknown
              : NutritionStatus.estimated,
          provenanceSnapshot: FoodApplicationService.provenance(
            FoodProvenanceSourceType.userInput,
          ),
          sortOrder: _ingredients.length,
        ),
      ),
    );
  }

  void _remove(int index) => setState(() {
    _ingredients.removeAt(index);
    _ingredients = [
      for (var i = 0; i < _ingredients.length; i++)
        RecipeIngredientV2.fromJson({
          ..._ingredients[i].toJson(),
          'sortOrder': i,
        }),
    ];
  });

  void _move(int from, int offset) => setState(() {
    final to = from + offset;
    if (to < 0 || to >= _ingredients.length) return;
    final item = _ingredients.removeAt(from);
    _ingredients.insert(to, item);
    _ingredients = [
      for (var i = 0; i < _ingredients.length; i++)
        RecipeIngredientV2.fromJson({
          ..._ingredients[i].toJson(),
          'sortOrder': i,
        }),
    ];
  });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one ingredient is required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final nutrition = FoodApplicationService.recipeNutrition(_ingredients);
      final now = DateTime.now().toUtc();
      final current = widget.recipe;
      final recipe = FoodRecipeDefinition(
        recipeId: current?.recipeId ?? FoodApplicationService.newId(),
        name: _name.text.trim(),
        ingredients: _ingredients,
        yieldQuantity: FoodQuantityDefinition(
          value: double.parse(_yield.text),
          unit: _yieldUnit,
        ),
        servingCount: _servings.text.trim().isEmpty
            ? null
            : double.parse(_servings.text),
        nutrition: nutrition,
        nutritionStatus: nutrition.isEmpty
            ? NutritionStatus.unknown
            : (_ingredients.any((value) => value.nutritionSnapshot.isEmpty)
                  ? NutritionStatus.estimated
                  : NutritionStatus.calculated),
        provenance: FoodApplicationService.provenance(
          FoodProvenanceSourceType.recipeCalculation,
        ),
        memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
        isArchived: current?.isArchived ?? false,
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
      );
      final repository = AppRepositoryRegistry.container.foodRecipes;
      if (current == null) {
        await repository.create(recipe);
      } else {
        await repository.update(recipe);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _archive() async {
    await AppRepositoryRegistry.container.foodRecipes.archive(
      widget.recipe!.recipeId,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = FoodApplicationService.recipeNutrition(_ingredients);
    final completeness = nutrition.isEmpty
        ? 'UNKNOWN'
        : (_ingredients.any((value) => value.nutritionSnapshot.isEmpty)
              ? 'PARTIAL'
              : 'COMPLETE');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'ADD RECIPE' : 'RECIPE DETAIL'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required.'
                    : null,
              ),
              AppSpacing.gapMD,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yield,
                      decoration: const InputDecoration(
                        labelText: 'Yield Quantity',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField(
                      initialValue: _yieldUnit,
                      decoration: const InputDecoration(
                        labelText: 'Yield Unit',
                      ),
                      items: FoodQuantityUnit.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_recipeUnitLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _yieldUnit = value!),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _servings,
                decoration: const InputDecoration(labelText: 'Serving Count'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextFormField(
                controller: _memo,
                decoration: const InputDecoration(labelText: 'Memo'),
              ),
              AppSpacing.gapLG,
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _recipeAction(
                    'ADD FROM FOOD DATABASE',
                    Icons.restaurant,
                    _addCatalog,
                  ),
                  _recipeAction('ADD CUSTOM ITEM', Icons.add, _addCustom),
                ],
              ),
              AppSpacing.gapMD,
              for (var i = 0; i < _ingredients.length; i++)
                OperationCard(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(_ingredients[i].nameSnapshot),
                    subtitle: Text(
                      '${_ingredients[i].quantity.value} ${_recipeUnitLabel(_ingredients[i].quantity.unit)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: i == 0 ? null : () => _move(i, -1),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: i == _ingredients.length - 1
                              ? null
                              : () => _move(i, 1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(i),
                        ),
                      ],
                    ),
                  ),
                ),
              AppSpacing.gapMD,
              Text(
                '$completeness · Calories ${nutrition.calories?.toStringAsFixed(1) ?? 'Unknown'} · P ${nutrition.protein?.toStringAsFixed(1) ?? 'Unknown'} · F ${nutrition.fat?.toStringAsFixed(1) ?? 'Unknown'} · C ${nutrition.carbohydrate?.toStringAsFixed(1) ?? 'Unknown'}',
              ),
              AppSpacing.gapLG,
              OperationButton(
                text: widget.recipe == null ? 'ADD RECIPE' : 'UPDATE RECIPE',
                icon: Icons.save,
                onPressed: _saving ? null : _save,
              ),
              if (widget.recipe != null && !widget.recipe!.isArchived) ...[
                AppSpacing.gapMD,
                OperationButton(
                  text: 'ARCHIVE RECIPE',
                  icon: Icons.archive,
                  onPressed: _saving ? null : _archive,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _recipeAction(String text, IconData icon, VoidCallback onPressed) =>
    SizedBox(
      width: 240,
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

String _recipeUnitLabel(FoodQuantityUnit value) => switch (value) {
  FoodQuantityUnit.gram => 'Gram',
  FoodQuantityUnit.milliliter => 'Milliliter',
  FoodQuantityUnit.piece => 'Piece',
  FoodQuantityUnit.pack => 'Pack',
  FoodQuantityUnit.serving => 'Serving',
};
