import 'package:flutter/material.dart';

import '../../core/state/app_initialization_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_text_field.dart';
import 'food_catalog_page.dart';
import 'food_nutrition_formatter.dart';
import 'models/food_catalog_models.dart';
import 'models/food_provenance_models.dart';
import 'models/food_quantity_models.dart';
import 'models/nutrition_models.dart';
import 'models/recipe_models_v2.dart';
import 'repository/food_catalog_repository.dart';
import 'repository/food_meal_id_generator.dart';
import 'repository/food_recipe_repository.dart';
import 'services/food_recipe_nutrition.dart';
import 'widgets/food_pfc_balance_card.dart';

class FoodRecipeEditorPage extends StatefulWidget {
  const FoodRecipeEditorPage({
    super.key,
    required this.repository,
    required this.catalogRepository,
    this.initialRecipe,
    this.now,
    this.idGenerator,
  });

  final FoodRecipeRepository repository;
  final FoodCatalogRepository catalogRepository;
  final FoodRecipeDefinition? initialRecipe;
  final DateTime Function()? now;
  final FoodMealIdGenerator? idGenerator;

  @override
  State<FoodRecipeEditorPage> createState() => _FoodRecipeEditorPageState();
}

class _FoodRecipeEditorPageState extends State<FoodRecipeEditorPage> {
  final _name = TextEditingController();
  final _yield = TextEditingController(text: '1');
  final _servings = TextEditingController(text: '1');
  final _memo = TextEditingController();
  final List<RecipeIngredientV2> _ingredients = [];
  FoodQuantityUnit _yieldUnit = FoodQuantityUnit.serving;
  bool _saving = false;
  String? _error;

  DateTime get _now => (widget.now ?? DateTime.now)().toUtc();
  FoodMealIdGenerator get _ids => widget.idGenerator ?? FoodMealIdGenerator();

  @override
  void initState() {
    super.initState();
    final recipe = widget.initialRecipe;
    if (recipe == null) return;
    _name.text = recipe.name;
    _yield.text = _amount(recipe.yieldQuantity.value);
    _yieldUnit = recipe.yieldQuantity.unit;
    _servings.text = recipe.servingCount == null
        ? ''
        : _amount(recipe.servingCount!);
    _memo.text = recipe.memo ?? '';
    _ingredients.addAll(recipe.ingredients);
  }

  @override
  void dispose() {
    _name.dispose();
    _yield.dispose();
    _servings.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final food = await Navigator.push<FoodCatalogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogPage(
          repository: widget.catalogRepository,
          recipeRepository: widget.repository,
          selectionMode: true,
          recipesEnabled: false,
        ),
      ),
    );
    if (food == null || !mounted) return;
    final quantity = await _chooseQuantity(food);
    if (quantity == null || !mounted) return;
    final factor = quantity / food.baseQuantity.value;
    final ingredient = RecipeIngredientV2(
      ingredientId: _id(),
      foodReferenceId: food.foodId,
      nameSnapshot: food.name,
      quantity: FoodQuantityDefinition(
        value: quantity,
        unit: food.baseQuantity.unit,
      ),
      nutritionSnapshot: FoodRecipeNutrition.scale(food.nutrition, factor),
      nutritionStatus: food.nutritionStatus,
      provenanceSnapshot: food.provenance,
      sortOrder: _ingredients.length,
    );
    setState(() {
      _ingredients.add(ingredient);
      _error = null;
    });
  }

  Future<double?> _chooseQuantity(FoodCatalogEntry food) {
    final controller = TextEditingController(
      text: _amount(food.baseQuantity.value),
    );
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(food.name),
        content: OperationTextField(
          key: const ValueKey('recipe-ingredient-quantity'),
          controller: controller,
          label:
              'QUANTITY (${FoodNutritionFormatter.quantityUnit(food.baseQuantity.unit)})',
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
                Navigator.pop(context, value);
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final yieldValue = double.tryParse(_yield.text.trim());
    final servingsText = _servings.text.trim();
    final servingCount = servingsText.isEmpty
        ? null
        : double.tryParse(servingsText);
    if (name.isEmpty ||
        yieldValue == null ||
        !yieldValue.isFinite ||
        yieldValue <= 0 ||
        (servingsText.isNotEmpty &&
            (servingCount == null ||
                !servingCount.isFinite ||
                servingCount <= 0)) ||
        _ingredients.isEmpty) {
      setState(() => _error = 'ENTER A NAME, YIELD, AND INGREDIENTS');
      return;
    }
    final timestamp = _now;
    final initial = widget.initialRecipe;
    final nutrition = FoodRecipeNutrition.total(_ingredients);
    final recipe = FoodRecipeDefinition(
      recipeId: initial?.recipeId ?? _id(),
      name: name,
      ingredients: [
        for (var index = 0; index < _ingredients.length; index++)
          RecipeIngredientV2.fromJson({
            ..._ingredients[index].toJson(),
            'sortOrder': index,
          }),
      ],
      yieldQuantity: FoodQuantityDefinition(
        value: yieldValue,
        unit: _yieldUnit,
      ),
      servingCount: servingCount,
      nutrition: nutrition,
      nutritionStatus: nutrition.isEmpty
          ? NutritionStatus.unknown
          : NutritionStatus.calculated,
      provenance: FoodDataProvenance(
        sourceType: FoodProvenanceSourceType.recipeCalculation,
        capturedAt: initial?.provenance.capturedAt ?? timestamp,
      ),
      memo: _nullable(_memo.text),
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
        await widget.repository.create(recipe);
      } else {
        await widget.repository.update(recipe);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'RECIPE SAVE FAILED');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final recipe = widget.initialRecipe;
    if (recipe == null) return;
    await widget.repository.archive(recipe.recipeId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = FoodRecipeNutrition.total(_ingredients);
    final readOnly = appInitializationController.value.isReadOnly;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialRecipe == null ? 'CREATE RECIPE' : 'EDIT RECIPE',
        ),
      ),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          OperationTextField(
            key: const ValueKey('recipe-name'),
            controller: _name,
            label: 'NAME',
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapMD,
          LayoutBuilder(
            builder: (context, constraints) {
              final quantity = OperationTextField(
                key: const ValueKey('recipe-yield'),
                controller: _yield,
                label: 'YIELD QUANTITY',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
              );
              final unit = DropdownButtonFormField<FoodQuantityUnit>(
                initialValue: _yieldUnit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'YIELD UNIT'),
                items: [
                  for (final value in FoodQuantityUnit.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.stableId.toUpperCase()),
                    ),
                ],
                onChanged: readOnly
                    ? null
                    : (value) => setState(() => _yieldUnit = value!),
              );
              if (constraints.maxWidth < 420) {
                return Column(children: [quantity, AppSpacing.gapSM, unit]);
              }
              return Row(
                children: [
                  Expanded(child: quantity),
                  AppSpacing.gapSM,
                  Expanded(child: unit),
                ],
              );
            },
          ),
          AppSpacing.gapMD,
          OperationTextField(
            key: const ValueKey('recipe-serving-count'),
            controller: _servings,
            label: 'SERVING COUNT',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapMD,
          _RecipeSummaryHeader(
            name: _name.text.trim().isEmpty ? 'RECIPE' : _name.text.trim(),
            serving: _servingMetadata(),
          ),
          if (FoodPfcBalanceCard.hasBalance(nutrition)) ...[
            AppSpacing.gapMD,
            FoodPfcBalanceCard(
              nutrition: nutrition,
              title: 'TOTAL PFC BALANCE',
              keyPrefix: 'recipe-total-pfc',
            ),
          ],
          AppSpacing.gapMD,
          OperationTextField(
            key: const ValueKey('recipe-memo'),
            controller: _memo,
            label: 'MEMO',
            maxLines: 3,
          ),
          AppSpacing.gapLG,
          Text('INGREDIENTS', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapSM,
          for (var index = 0; index < _ingredients.length; index++) ...[
            OperationCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _ingredients[index].nameSnapshot,
                  key: ValueKey('recipe-ingredient-name-$index'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      FoodNutritionFormatter.quantity(
                        _ingredients[index].quantity,
                      ),
                      style: _recipeMetadataStyle(context),
                    ),
                    Text(
                      FoodNutritionFormatter.nutrition(
                        _ingredients[index].nutritionSnapshot,
                      ),
                      style: _recipeMetadataStyle(context),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: readOnly
                      ? null
                      : () => setState(() => _ingredients.removeAt(index)),
                ),
              ),
            ),
            AppSpacing.gapSM,
          ],
          OperationButton(
            key: const ValueKey('recipe-add-ingredient'),
            icon: Icons.add,
            text: 'ADD INGREDIENT FROM FOOD DATABASE',
            onPressed: readOnly || _saving ? null : _addIngredient,
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
            key: const ValueKey('recipe-save'),
            icon: Icons.save_outlined,
            text: 'SAVE RECIPE',
            role: OperationActionRole.primary,
            onPressed: readOnly || _saving ? null : _save,
          ),
          if (widget.initialRecipe != null) ...[
            AppSpacing.gapSM,
            OperationButton(
              key: const ValueKey('recipe-archive'),
              icon: Icons.archive_outlined,
              text: 'ARCHIVE RECIPE',
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

  String _servingMetadata() {
    final value = double.tryParse(_servings.text.trim());
    if (value != null && value.isFinite && value > 0) {
      return FoodNutritionFormatter.servings(value);
    }
    if (_yieldUnit == FoodQuantityUnit.serving) {
      final yieldValue = double.tryParse(_yield.text.trim());
      if (yieldValue != null && yieldValue.isFinite && yieldValue > 0) {
        return FoodNutritionFormatter.servings(yieldValue);
      }
    }
    return 'SERVING NOT SET';
  }
}

class _RecipeSummaryHeader extends StatelessWidget {
  const _RecipeSummaryHeader({required this.name, required this.serving});

  final String name;
  final String serving;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('recipe-summary-header'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        key: const ValueKey('recipe-primary-name'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      AppSpacing.gapXS,
      Text(
        serving,
        key: const ValueKey('recipe-serving-metadata'),
        style: _recipeMetadataStyle(context),
      ),
    ],
  );
}

TextStyle? _recipeMetadataStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodySmall
    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

String foodRecipeNutritionLabel(NutritionSnapshot value) => _nutrition(value);

String _nutrition(NutritionSnapshot value) =>
    FoodNutritionFormatter.nutrition(value);

String _amount(double value) => FoodNutritionFormatter.amount(value);

String? _nullable(String source) {
  final value = source.trim();
  return value.isEmpty ? null : value;
}
