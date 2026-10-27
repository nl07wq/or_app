import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../core/state/app_initialization_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/loading/or_loading_surface.dart';
import '../../core/widgets/loading/or_loading_tokens.dart';
import '../repositories/app_repository_container.dart';
import 'models/food_catalog_models.dart';
import 'models/food_meal_master_models.dart';
import 'models/food_provenance_models.dart';
import 'models/food_quantity_models.dart';
import 'models/nutrition_models.dart';
import 'models/recipe_models_v2.dart';
import 'food_nutrition_formatter.dart';
import 'food_recipe_page.dart';
import 'food_meal_master_page.dart';
import 'repository/food_catalog_repository.dart';
import 'repository/food_meal_id_generator.dart';
import 'repository/food_recipe_repository.dart';
import 'repository/food_meal_master_repository.dart';
import 'services/food_input_capture_gateway.dart';
import 'services/food_nutrition_recalculation.dart';
import 'services/japanese_nutrition_ocr_parser.dart';
import 'services/japanese_package_ocr_parser.dart';
import 'widgets/food_ocr_scanner.dart';
import 'widgets/food_pfc_balance_card.dart';
import 'widgets/food_thumbnail.dart';
import 'widgets/food_form_theme.dart';
import 'widgets/food_feature_chrome.dart';
import 'widgets/food_saved_floating_hud.dart';

class FoodCatalogPage extends StatefulWidget {
  const FoodCatalogPage({
    super.key,
    this.repository,
    this.recipeRepository,
    this.mealRepository,
    this.selectionMode = false,
    this.recipesEnabled = true,
    this.mealsEnabled = true,
    this.initialSelectionView = FoodCatalogSelectionView.food,
    this.selectionViewLocked = false,
  });

  final FoodCatalogRepository? repository;
  final FoodRecipeRepository? recipeRepository;
  final FoodMealMasterRepository? mealRepository;
  final bool selectionMode;
  final bool recipesEnabled;
  final bool mealsEnabled;
  final FoodCatalogSelectionView initialSelectionView;
  final bool selectionViewLocked;

  @override
  State<FoodCatalogPage> createState() => _FoodCatalogPageState();
}

class _FoodCatalogPageState extends State<FoodCatalogPage> {
  final _search = TextEditingController();
  List<FoodCatalogEntry> _entries = const [];
  List<FoodRecipeDefinition> _recipes = const [];
  List<FoodMealMaster> _meals = const [];
  Object? _error;
  bool _loading = true;
  late _FoodDatabaseView _view;
  FoodCatalogCategory? _selectedCategory;

  FoodCatalogRepository get _repository =>
      widget.repository ?? AppRepositoryRegistry.container.foodCatalog;
  FoodRecipeRepository get _recipeRepository =>
      widget.recipeRepository ?? AppRepositoryRegistry.container.foodRecipes;
  FoodMealMasterRepository get _mealRepository =>
      widget.mealRepository ?? AppRepositoryRegistry.container.foodMealMasters;

  @override
  void initState() {
    super.initState();
    _view = switch (widget.initialSelectionView) {
      FoodCatalogSelectionView.food => _FoodDatabaseView.food,
      FoodCatalogSelectionView.recipe => _FoodDatabaseView.recipe,
      FoodCatalogSelectionView.meal => _FoodDatabaseView.meal,
    };
    switch (_view) {
      case _FoodDatabaseView.food:
        _load();
      case _FoodDatabaseView.recipe:
        _loadRecipes();
      case _FoodDatabaseView.meal:
        _loadMeals();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final entries = await _repository.list();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<FoodCatalogEntry> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _entries
        .where(
          (entry) =>
              (_selectedCategory == null ||
                  entry.category == _selectedCategory) &&
              (query.isEmpty ||
                  entry.name.toLowerCase().contains(query) ||
                  (entry.brand?.toLowerCase().contains(query) ?? false) ||
                  (entry.barcodeValue?.toLowerCase().contains(query) ?? false)),
        )
        .toList(growable: false);
  }

  List<FoodRecipeDefinition> get _visibleRecipes {
    final query = _search.text.trim().toLowerCase();
    return _recipes
        .where(
          (recipe) =>
              !recipe.isArchived &&
              (query.isEmpty || recipe.name.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  List<FoodMealMaster> get _visibleMeals {
    final query = _search.text.trim().toLowerCase();
    return _meals
        .where(
          (meal) =>
              !meal.isArchived &&
              (query.isEmpty || meal.name.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  Future<void> _selectView(_FoodDatabaseView view) async {
    if (_view == view) return;
    GlobalTouchRipple.previewFeedback(TouchFeedbackSound.cursor);
    setState(() {
      _view = view;
      _search.clear();
      _selectedCategory = null;
      _loading =
          (view == _FoodDatabaseView.recipe && _recipes.isEmpty) ||
          (view == _FoodDatabaseView.meal && _meals.isEmpty);
      _error = null;
    });
    if (_loading) {
      if (view == _FoodDatabaseView.recipe) {
        await _loadRecipes();
      } else {
        await _loadMeals();
      }
    }
  }

  Future<void> _loadMeals() async {
    try {
      final meals = await _mealRepository.list();
      if (!mounted) return;
      setState(() {
        _meals = meals;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadRecipes() async {
    try {
      final recipes = await _recipeRepository.list();
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([FoodCatalogEntry? entry]) async {
    FocusScope.of(context).unfocus();
    final saved = await Navigator.push<FoodCatalogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FoodCatalogEditorPage(repository: _repository, initialEntry: entry),
      ),
    );
    if (saved != null) await _load();
  }

  Future<void> _openEntry(FoodCatalogEntry entry) async {
    if (widget.selectionMode) {
      Navigator.pop(context, entry);
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FoodCatalogDetailPage(entry: entry, repository: _repository),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openRecipeEditor([FoodRecipeDefinition? recipe]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodRecipeEditorPage(
          repository: _recipeRepository,
          catalogRepository: _repository,
          initialRecipe: recipe,
        ),
      ),
    );
    if (changed == true) await _loadRecipes();
  }

  Future<void> _openRecipe(FoodRecipeDefinition recipe) async {
    if (widget.selectionMode) {
      Navigator.pop(context, recipe);
      return;
    }
    await _openRecipeEditor(recipe);
  }

  Future<void> _openMealEditor([FoodMealMaster? meal]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodMealMasterEditorPage(
          repository: _mealRepository,
          catalogRepository: _repository,
          recipeRepository: _recipeRepository,
          initialMeal: meal,
        ),
      ),
    );
    if (changed == true) await _loadMeals();
  }

  Future<void> _openMeal(FoodMealMaster meal) async {
    if (widget.selectionMode) {
      Navigator.pop(context, meal);
      return;
    }
    await _openMealEditor(meal);
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
    onWillPop: () async {
      FocusScope.of(context).unfocus();
      return true;
    },
    child: FoodFeatureScaffold(
      appBar: foodFeatureAppBar(
        leading: const ActionableBackButton(),
        title: widget.selectionMode
            ? widget.recipesEnabled
                  ? widget.mealsEnabled
                        ? MediaQuery.sizeOf(context).width < 480
                              ? 'SELECT MASTER'
                              : 'SELECT FOOD / RECIPE / MEAL'
                        : 'SELECT FOOD / RECIPE'
                  : 'SELECT FOOD'
            : 'FOOD DATABASE',
      ),
      floatingActionButton:
          widget.selectionMode || appInitializationController.value.isReadOnly
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('food-catalog-add'),
              onPressed: switch (_view) {
                _FoodDatabaseView.food => _openEditor,
                _FoodDatabaseView.recipe => _openRecipeEditor,
                _FoodDatabaseView.meal => _openMealEditor,
              },
              icon: const Icon(Icons.add),
              label: Text(switch (_view) {
                _FoodDatabaseView.food => 'ADD FOOD',
                _FoodDatabaseView.recipe => 'ADD RECIPE',
                _FoodDatabaseView.meal => 'CREATE MEAL',
              }),
            ).actionableFeedback(),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          children: [
            if (widget.recipesEnabled && !widget.selectionViewLocked) ...[
              SegmentedButton<_FoodDatabaseView>(
                key: const ValueKey('food-database-type'),
                segments: [
                  const ButtonSegment(
                    value: _FoodDatabaseView.food,
                    icon: Icon(Icons.restaurant_outlined),
                    label: Text('FOOD', maxLines: 1, softWrap: false),
                  ),
                  const ButtonSegment(
                    value: _FoodDatabaseView.recipe,
                    icon: Icon(Icons.menu_book_outlined),
                    label: Text('RECIPE', maxLines: 1, softWrap: false),
                  ),
                  if (widget.mealsEnabled)
                    const ButtonSegment(
                      value: _FoodDatabaseView.meal,
                      icon: Icon(Icons.view_list_outlined),
                      label: Text('MEAL', maxLines: 1, softWrap: false),
                    ),
                ],
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                selected: {_view},
                onSelectionChanged: (value) => _selectView(value.single),
              ).actionableFeedback(
                enabled: true,
                role: ActionableFeedbackRole.silent,
              ),
              AppSpacing.gapMD,
            ],
            if (_view == _FoodDatabaseView.food)
              Expanded(child: _foodDatabaseSurface())
            else ...[
              OperationTextField(
                key: const ValueKey('food-catalog-search'),
                controller: _search,
                label: _view == _FoodDatabaseView.recipe
                    ? 'SEARCH RECIPE NAME'
                    : 'SEARCH MEAL NAME',
                onChanged: (_) => setState(() {}),
              ),
              AppSpacing.gapMD,
              Expanded(child: _body()),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _foodDatabaseSurface() => Column(
    children: [
      DecoratedBox(
        key: const ValueKey('food-database-controls-glass'),
        decoration: BoxDecoration(
          color: const Color(0x66141B24),
          border: Border.all(color: const Color(0x99304659)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.search,
                      size: 19,
                      color: FoodFormMetrics.caption,
                    ),
                  ),
                  Expanded(
                    child: OperationTextField(
                      key: const ValueKey('food-catalog-search'),
                      controller: _search,
                      label: 'SEARCH NAME / BRAND / BARCODE',
                      glass: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: FoodFormMetrics.separator),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: _categoryFilter(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Expanded(child: _body()),
    ],
  );

  Widget _categoryFilter() => Semantics(
    label: 'CATEGORY FILTER',
    child: SingleChildScrollView(
      key: const ValueKey('food-category-filter-scroll'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _categoryChoice(label: 'ALL', category: null, keyName: 'all'),
          const SizedBox(width: AppSpacing.sm),
          _categoryChoice(
            label: '食材',
            category: FoodCatalogCategory.ingredient,
            keyName: 'ingredient',
          ),
          const SizedBox(width: AppSpacing.sm),
          _categoryChoice(
            label: '調理済み',
            category: FoodCatalogCategory.preparedFood,
            keyName: 'preparedFood',
          ),
          const SizedBox(width: AppSpacing.sm),
          _categoryChoice(
            label: '市販・包装品',
            category: FoodCatalogCategory.packagedFood,
            keyName: 'packagedFood',
          ),
          const SizedBox(width: AppSpacing.sm),
          _categoryChoice(
            label: '飲料',
            category: FoodCatalogCategory.beverage,
            keyName: 'beverage',
          ),
        ],
      ),
    ),
  );

  Widget _categoryChoice({
    required String label,
    required FoodCatalogCategory? category,
    required String keyName,
  }) {
    final selected = _selectedCategory == category;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label category filter',
      child: ChoiceChip(
        key: ValueKey('food-category-filter-$keyName'),
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectCategory(category),
        showCheckmark: true,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
        selectedColor: colorScheme.primaryContainer.withValues(alpha: 0.55),
        backgroundColor: colorScheme.surface.withValues(alpha: 0.35),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
    );
  }

  void _selectCategory(FoodCatalogCategory? category) {
    if (_selectedCategory == category) return;
    GlobalTouchRipple.previewFeedback(TouchFeedbackSound.cursor);
    setState(() => _selectedCategory = category);
  }

  Widget _body() {
    if (_loading) return const OrLoadingSurface(title: 'LOADING FOOD DATABASE');
    if (_error != null) {
      return OrLoadingSurface(
        title: 'FOOD DATABASE UNAVAILABLE',
        subtitle: 'The catalog could not be loaded.',
        state: OrLoadingPhase.failed,
        onRetry: switch (_view) {
          _FoodDatabaseView.food => _load,
          _FoodDatabaseView.recipe => _loadRecipes,
          _FoodDatabaseView.meal => _loadMeals,
        },
      );
    }
    if (_view == _FoodDatabaseView.recipe) return _recipeBody();
    if (_view == _FoodDatabaseView.meal) return _mealBody();
    final entries = _visible;
    if (entries.isEmpty) return const Center(child: Text('食品が見つかりません'));
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => AppSpacing.gapSM,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _FoodCatalogListCard(
          entry: entry,
          onTap: () => _openEntry(entry),
        );
      },
    );
  }

  Widget _recipeBody() {
    final recipes = _visibleRecipes;
    if (recipes.isEmpty) {
      return const Center(child: Text('RECIPE NOT FOUND'));
    }
    return ListView.separated(
      itemCount: recipes.length,
      separatorBuilder: (_, _) => AppSpacing.gapSM,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return OperationCard(
          child: ListTile(
            key: ValueKey('food-recipe-${recipe.recipeId}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(
              recipe.name,
              key: ValueKey('food-recipe-name-${recipe.recipeId}'),
              style: _databaseListPrimaryStyle(context),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foodRecipeSummaryLabel(recipe),
                  key: ValueKey('food-recipe-serving-${recipe.recipeId}'),
                  style: _databaseListMetadataStyle(context),
                ),
                Text(
                  FoodNutritionFormatter.compactNutrition(recipe.nutrition),
                  key: ValueKey('food-recipe-nutrition-${recipe.recipeId}'),
                  style: _databaseListMetadataStyle(context),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openRecipe(recipe),
          ).actionableFeedback(enabled: true),
        );
      },
    );
  }

  Widget _mealBody() {
    final meals = _visibleMeals;
    if (meals.isEmpty) return const Center(child: Text('MEAL NOT FOUND'));
    return ListView.separated(
      itemCount: meals.length,
      separatorBuilder: (_, _) => AppSpacing.gapSM,
      itemBuilder: (context, index) {
        final meal = meals[index];
        return OperationCard(
          child: ListTile(
            key: ValueKey('food-meal-master-${meal.mealMasterId}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_list_outlined),
            title: Text(meal.name, style: _databaseListPrimaryStyle(context)),
            subtitle: Text(
              '${meal.components.length} ITEMS',
              style: _databaseListMetadataStyle(context),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openMeal(meal),
          ).actionableFeedback(enabled: true),
        );
      },
    );
  }
}

enum FoodCatalogSelectionView { food, recipe, meal }

enum _FoodDatabaseView { food, recipe, meal }

TextStyle? _databaseListPrimaryStyle(BuildContext context) => Theme.of(
  context,
).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

TextStyle? _databaseListMetadataStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.2,
    );

class _FoodCatalogListCard extends StatelessWidget {
  const _FoodCatalogListCard({required this.entry, required this.onTap});

  final FoodCatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metadata = [
      if (entry.brand?.isNotEmpty ?? false) entry.brand!,
      foodCatalogCategoryLabel(entry.category),
      FoodNutritionFormatter.compactQuantity(entry.baseQuantity),
    ].join('  ');
    return Material(
      color: const Color(0xA8141B24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x88304659)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FoodThumbnail(visualKey: entry.visualKey, size: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          key: ValueKey('food-catalog-name-${entry.foodId}'),
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                          style: _databaseListPrimaryStyle(
                            context,
                          )?.copyWith(fontSize: 16, height: 1.25),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          metadata,
                          key: ValueKey(
                            'food-catalog-metadata-${entry.foodId}',
                          ),
                          style: _databaseListMetadataStyle(context),
                        ),
                        if (entry.barcodeValue case final barcode?) ...[
                          const SizedBox(height: 2),
                          Text(
                            barcode,
                            style: _databaseListMetadataStyle(
                              context,
                            )?.copyWith(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0xFF2C4050)),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cells = [
                    _NutritionCell(
                      label: 'kcal',
                      number: _nutritionNumber(
                        entry.nutrition.calories,
                        kcal: true,
                      ),
                      unit: entry.nutrition.calories == null ? '' : 'kcal',
                      valueColor: const Color(0xFFF1F7FF),
                    ),
                    _NutritionCell(
                      label: 'P',
                      number: _nutritionNumber(entry.nutrition.protein),
                      unit: entry.nutrition.protein == null ? '' : 'g',
                      valueColor: foodDetailProteinColor,
                      labelColor: FoodFormMetrics.protein,
                    ),
                    _NutritionCell(
                      label: 'F',
                      number: _nutritionNumber(entry.nutrition.fat),
                      unit: entry.nutrition.fat == null ? '' : 'g',
                      valueColor: foodDetailFatColor,
                      labelColor: FoodFormMetrics.fat,
                    ),
                    _NutritionCell(
                      label: 'C',
                      number: _nutritionNumber(entry.nutrition.carbohydrate),
                      unit: entry.nutrition.carbohydrate == null ? '' : 'g',
                      valueColor: foodDetailCarbohydrateColor,
                      labelColor: FoodFormMetrics.carbohydrate,
                    ),
                  ];
                  final row = constraints.maxWidth >= 250
                      ? Row(
                          children: [
                            for (final cell in cells) Expanded(child: cell),
                          ],
                        )
                      : Wrap(
                          children: [
                            for (final cell in cells)
                              SizedBox(
                                width: constraints.maxWidth / 2,
                                child: cell,
                              ),
                          ],
                        );
                  return Semantics(
                    label: FoodNutritionFormatter.compactNutrition(
                      entry.nutrition,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('food-catalog-nutrition-${entry.foodId}'),
                      child: row,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ).actionableFeedback(enabled: true),
    );
  }

  String _nutritionNumber(num? value, {bool kcal = false}) => value == null
      ? '—'
      : kcal
      ? FoodNutritionFormatter.calories(value)
      : FoodNutritionFormatter.macro(value);
}

class _NutritionCell extends StatelessWidget {
  const _NutritionCell({
    required this.label,
    required this.number,
    required this.unit,
    required this.valueColor,
    this.labelColor,
  });

  final String label;
  final String number;
  final String unit;
  final Color valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: number,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: valueColor.withValues(alpha: .78),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: labelColor ?? FoodFormMetrics.caption,
          ),
        ),
      ],
    ),
  );
}

class FoodCatalogEditorPage extends StatefulWidget {
  const FoodCatalogEditorPage({
    super.key,
    required this.repository,
    this.initialEntry,
    this.draft,
    this.captureGateway,
  });

  final FoodCatalogRepository repository;
  final FoodCatalogEntry? initialEntry;
  final FoodCatalogDraft? draft;
  final FoodInputCaptureGateway? captureGateway;

  @override
  State<FoodCatalogEditorPage> createState() => _FoodCatalogEditorPageState();
}

class FoodCatalogDraft {
  const FoodCatalogDraft({
    required this.name,
    required this.baseQuantity,
    required this.nutrition,
    this.category = FoodCatalogCategory.preparedFood,
    this.brand,
    this.barcodeValue,
    this.barcodeFormat,
    this.packageQuantity,
    this.packageUnit,
    this.visualKey,
    this.memo,
  }) : assert(
         (packageQuantity == null) == (packageUnit == null),
         'packageQuantity and packageUnit must be provided together.',
       );

  final String name;
  final FoodCatalogCategory category;
  final FoodQuantityDefinition baseQuantity;
  final NutritionSnapshot nutrition;
  final String? brand;
  final String? barcodeValue;
  final FoodBarcodeFormat? barcodeFormat;
  final double? packageQuantity;
  final FoodQuantityUnit? packageUnit;
  final FoodVisualKey? visualKey;
  final String? memo;
}

class _FoodCatalogEditorPageState extends State<FoodCatalogEditorPage> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _packageQuantity = TextEditingController();
  final _baseQuantity = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
  final _caloriesFocusNode = FocusNode();
  final _proteinFocusNode = FocusNode();
  final _fatFocusNode = FocusNode();
  final _carbsFocusNode = FocusNode();
  final _memo = TextEditingController();
  FoodCatalogCategory _category = FoodCatalogCategory.packagedFood;
  FoodVisualKey? _visualKey;
  FoodQuantityUnit? _packageUnit;
  FoodQuantityUnit _baseUnit = FoodQuantityUnit.gram;
  bool _saving = false;
  bool _capturing = false;
  bool _nutritionUnitManuallyOverridden = false;
  bool _nutritionBasisManuallyEdited = false;
  double? _rawCalories;
  double? _rawProtein;
  double? _rawFat;
  double? _rawCarbohydrate;
  String? _error;

  FoodInputCaptureGateway get _captureGateway =>
      widget.captureGateway ?? createFoodInputCaptureGateway();

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    final draft = widget.draft;
    if (draft != null) {
      _nutritionUnitManuallyOverridden = true;
      _nutritionBasisManuallyEdited = true;
      _name.text = draft.name;
      _baseQuantity.text = _number(draft.baseQuantity.value);
      _setNutrition(draft.nutrition);
      _brand.text = draft.brand ?? '';
      _barcode.text = draft.barcodeValue ?? '';
      _packageQuantity.text = _number(draft.packageQuantity);
      _memo.text = draft.memo ?? '';
      _category = draft.category;
      _visualKey = draft.visualKey ?? entry?.visualKey;
      _packageUnit = draft.packageUnit;
      _baseUnit = draft.baseQuantity.unit;
    } else if (entry != null) {
      _nutritionUnitManuallyOverridden = true;
      _nutritionBasisManuallyEdited = true;
      _name.text = entry.name;
      _brand.text = entry.brand ?? '';
      _barcode.text = entry.barcodeValue ?? '';
      _packageQuantity.text = _number(entry.packageQuantity);
      _baseQuantity.text = _number(entry.baseQuantity.value);
      _setNutrition(entry.nutrition);
      _memo.text = entry.memo ?? '';
      _category = entry.category;
      _visualKey = entry.visualKey;
      _packageUnit = entry.packageUnit;
      _baseUnit = entry.baseQuantity.unit;
    } else {
      _baseQuantity.text = '100';
    }
  }

  void _packageQuantityChanged(String value) {
    setState(() {});
  }

  void _packageUnitChanged(FoodQuantityUnit? value) {
    setState(() {
      _packageUnit = value;
      if (!_nutritionUnitManuallyOverridden && value != null) {
        _baseUnit = value;
        if (!_nutritionBasisManuallyEdited) {
          _baseQuantity.text = _defaultNutritionBasis(value);
        }
      }
    });
  }

  void _baseQuantityChanged(String _) {
    setState(() => _nutritionBasisManuallyEdited = true);
  }

  void _baseUnitChanged(FoodQuantityUnit? value) {
    if (value == null) return;
    setState(() {
      _baseUnit = value;
      _nutritionUnitManuallyOverridden = true;
    });
  }

  String _defaultNutritionBasis(FoodQuantityUnit unit) => switch (unit) {
    FoodQuantityUnit.gram || FoodQuantityUnit.milliliter => '100',
    FoodQuantityUnit.piece ||
    FoodQuantityUnit.pack ||
    FoodQuantityUnit.serving => '1',
  };

  Future<void> _selectThumbnail() async {
    final selection = await showModalBottomSheet<_FoodVisualSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SELECT THUMBNAIL',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  AppSpacing.gapMD,
                  Flexible(
                    child: GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: constraints.maxWidth < 360 ? 2 : 3,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.18,
                      children: [
                        _FoodVisualChoice(
                          visualKey: null,
                          selected: _visualKey == null,
                          onTap: () => Navigator.pop(
                            context,
                            const _FoodVisualSelection(null),
                          ),
                        ),
                        for (final visualKey in FoodVisualKey.values)
                          _FoodVisualChoice(
                            visualKey: visualKey,
                            selected: _visualKey == visualKey,
                            onTap: () => Navigator.pop(
                              context,
                              _FoodVisualSelection(visualKey),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    if (selection.visualKey == _visualKey) return;
    GlobalTouchRipple.previewFeedback(TouchFeedbackSound.cursor);
    setState(() => _visualKey = selection.visualKey);
  }

  Future<FoodImageSource?> _chooseImageSource() =>
      showModalBottomSheet<FoodImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('CAMERA'),
                onTap: () => Navigator.pop(context, FoodImageSource.camera),
              ).actionableFeedback(enabled: true),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('PHOTO LIBRARY'),
                onTap: () => Navigator.pop(context, FoodImageSource.gallery),
              ).actionableFeedback(enabled: true),
            ],
          ),
        ),
      );

  Future<void> _scanOcr() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final result = await showNutritionLabelScanner(
        context: context,
        gateway: _captureGateway,
      );
      if (!mounted || result == null) return;
      switch (result) {
        case FoodNutritionOcrResult(:final draft):
          _applyNutritionOcr(draft);
        case FoodPackageOcrResult(:final draft):
          _applyPackageOcr(draft);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '栄養成分表示を読み取れませんでした');
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final String? value;
      if (_captureGateway case final FoodLiveCaptureGateway liveGateway) {
        final candidate = await liveGateway.scanBarcodeLive();
        if (candidate == null) return;
        value = candidate.value;
      } else {
        final source = await _chooseImageSource();
        if (source == null || !mounted) return;
        final image = await _captureGateway.selectImage(source);
        if (image == null) return;
        value = await _captureGateway.scanBarcode(image);
      }
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        setState(() => _error = 'バーコードを読み取れませんでした');
      } else {
        setState(() => _barcode.text = value!);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'バーコードの読み取りに失敗しました');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _applyNutritionOcr(NutritionOcrDraft draft) {
    setState(() {
      if (draft.packageQuantity != null && draft.packageUnit != null) {
        _packageQuantity.text = _number(draft.packageQuantity);
        _packageUnit = draft.packageUnit;
        if (!_nutritionUnitManuallyOverridden) {
          _baseUnit = draft.packageUnit!;
          if (!_nutritionBasisManuallyEdited) {
            _baseQuantity.text = _defaultNutritionBasis(draft.packageUnit!);
          }
        }
      }
      if (draft.basisQuantity != null && draft.basisUnit != null) {
        _baseQuantity.text = _number(draft.basisQuantity);
        _baseUnit = draft.basisUnit!;
        _nutritionUnitManuallyOverridden = true;
        _nutritionBasisManuallyEdited = true;
      }
      if (draft.calories != null) {
        _rawCalories = draft.calories;
        _calories.text = FoodNutritionFormatter.calories(draft.calories!);
      }
      if (draft.protein != null) {
        _rawProtein = draft.protein;
        _protein.text = FoodNutritionFormatter.macro(draft.protein!);
      }
      if (draft.fat != null) {
        _rawFat = draft.fat;
        _fat.text = FoodNutritionFormatter.macro(draft.fat!);
      }
      if (draft.carbohydrate != null) {
        _rawCarbohydrate = draft.carbohydrate;
        _carbs.text = FoodNutritionFormatter.macro(draft.carbohydrate!);
      }
    });
  }

  void _applyPackageOcr(PackageOcrDraft draft) {
    setState(() {
      if (draft.name != null) _name.text = draft.name!;
      if (draft.brand != null) _brand.text = draft.brand!;
      if (draft.packageQuantity != null && draft.packageUnit != null) {
        _packageQuantity.text = _number(draft.packageQuantity);
        _packageUnit = draft.packageUnit;
        if (!_nutritionUnitManuallyOverridden) {
          _baseUnit = draft.packageUnit!;
          if (!_nutritionBasisManuallyEdited) {
            _baseQuantity.text = _defaultNutritionBasis(draft.packageUnit!);
          }
        }
      }
    });
  }

  NutritionSnapshot _editableNutrition() => NutritionSnapshot(
    calories: _rawCalories ?? _optionalNumber(_calories),
    protein: _rawProtein ?? _optionalNumber(_protein),
    fat: _rawFat ?? _optionalNumber(_fat),
    carbohydrate: _rawCarbohydrate ?? _optionalNumber(_carbs),
  );

  List<String> _requiredNutritionErrors() {
    final fields = <String, (TextEditingController, double?)>{
      'CALORIES': (_calories, _rawCalories),
      'PROTEIN': (_protein, _rawProtein),
      'FAT': (_fat, _rawFat),
      'CARBOHYDRATE': (_carbs, _rawCarbohydrate),
    };
    final errors = <String>[];
    for (final entry in fields.entries) {
      final text = entry.value.$1.text.trim();
      final value = entry.value.$2 ?? double.tryParse(text);
      if (text.isEmpty && entry.value.$2 == null) {
        errors.add('${entry.key} IS REQUIRED');
      } else if (value == null || !value.isFinite || value < 0) {
        errors.add('${entry.key} MUST BE A VALID NUMBER ZERO OR GREATER');
      }
    }
    return errors;
  }

  String? get _recalculationBlockReason {
    final values = [
      _rawCalories ?? _optionalNumber(_calories),
      _rawProtein ?? _optionalNumber(_protein),
      _rawFat ?? _optionalNumber(_fat),
      _rawCarbohydrate ?? _optionalNumber(_carbs),
    ];
    if (values.any(
      (value) => value != null && (!value.isFinite || value < 0),
    )) {
      return 'NUTRITION VALUES MUST BE ZERO OR GREATER.';
    }
    return FoodNutritionRecalculation.blockedReason(
      packageQuantity: double.tryParse(_packageQuantity.text.trim()),
      packageUnit: _packageUnit,
      basisQuantity: double.tryParse(_baseQuantity.text.trim()),
      basisUnit: _baseUnit,
      nutrition: _editableNutrition(),
    );
  }

  Future<void> _previewNutritionRecalculation() async {
    final preview = FoodNutritionRecalculation.preview(
      packageQuantity: double.tryParse(_packageQuantity.text.trim()),
      packageUnit: _packageUnit,
      basisQuantity: double.tryParse(_baseQuantity.text.trim()),
      basisUnit: _baseUnit,
      nutrition: _editableNutrition(),
    );
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RECALCULATE NUTRITION'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FROM  ${_number(preview.packageQuantity)}${_unit(preview.packageUnit)}',
            ),
            Text(
              'TO  ${_number(preview.basisQuantity)}${_unit(preview.basisUnit)}',
            ),
            AppSpacing.gapMD,
            _NutritionRecalculationRow(
              label: 'CALORIES',
              before: preview.current.calories,
              after: preview.recalculated.calories,
              calories: true,
            ),
            _NutritionRecalculationRow(
              label: 'PROTEIN',
              before: preview.current.protein,
              after: preview.recalculated.protein,
            ),
            _NutritionRecalculationRow(
              label: 'FAT',
              before: preview.current.fat,
              after: preview.recalculated.fat,
            ),
            _NutritionRecalculationRow(
              label: 'CARBOHYDRATE',
              before: preview.current.carbohydrate,
              after: preview.recalculated.carbohydrate,
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('nutrition-recalculation-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ).actionableFeedback(role: ActionableFeedbackRole.exit),
          FilledButton(
            key: const ValueKey('nutrition-recalculation-apply'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('APPLY'),
          ).actionableFeedback(),
        ],
      ),
    );
    if (apply != true || !mounted) return;
    setState(() => _setNutrition(preview.recalculated));
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _brand,
      _barcode,
      _packageQuantity,
      _baseQuantity,
      _calories,
      _protein,
      _fat,
      _carbs,
      _memo,
    ]) {
      controller.dispose();
    }
    for (final node in [
      _caloriesFocusNode,
      _proteinFocusNode,
      _fatFocusNode,
      _carbsFocusNode,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final base = double.tryParse(_baseQuantity.text.trim());
    final package = _packageQuantity.text.trim().isEmpty
        ? null
        : double.tryParse(_packageQuantity.text.trim());
    if (name.isEmpty ||
        base == null ||
        base <= 0 ||
        (_packageQuantity.text.trim().isNotEmpty && package == null) ||
        (package == null) != (_packageUnit == null)) {
      _showSaveFailure('ENTER VALID FOOD AND QUANTITY VALUES');
      return;
    }
    final barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim();
    if (barcode != null) {
      final duplicate = (await widget.repository.list()).where(
        (entry) =>
            entry.foodId != widget.initialEntry?.foodId &&
            entry.barcodeValue == barcode,
      );
      if (duplicate.isNotEmpty) {
        if (!mounted) return;
        _showSaveFailure('EXISTING FOOD FOUND: ${duplicate.first.name}');
        return;
      }
    }
    final nutritionErrors = _requiredNutritionErrors();
    if (nutritionErrors.isNotEmpty) {
      _showSaveFailure(nutritionErrors.join('\n'));
      return;
    }
    final timestamp = DateTime.now().toUtc();
    final existing = widget.initialEntry;
    final nutrition = NutritionSnapshot(
      calories: _rawCalories ?? _optionalNumber(_calories),
      protein: _rawProtein ?? _optionalNumber(_protein),
      fat: _rawFat ?? _optionalNumber(_fat),
      carbohydrate: _rawCarbohydrate ?? _optionalNumber(_carbs),
    );
    // The editor can be saved while a mobile keyboard is open. End that input
    // session before this route pops so the previous FOOD route is rebuilt
    // against the restored viewport rather than stale keyboard metrics.
    FocusScope.of(context).unfocus();
    final entry = FoodCatalogEntry(
      foodId: existing?.foodId ?? FoodMealIdGenerator().generate().substring(5),
      recordVersion: FoodCatalogEntry.recordVersion2,
      name: name,
      category: _category,
      brand: _nullable(_brand.text),
      baseQuantity: FoodQuantityDefinition(value: base, unit: _baseUnit),
      nutrition: nutrition,
      nutritionStatus: nutrition.isEmpty
          ? NutritionStatus.unknown
          : NutritionStatus.declared,
      provenance:
          existing?.provenance ??
          FoodDataProvenance(
            sourceType: FoodProvenanceSourceType.userInput,
            capturedAt: timestamp,
          ),
      isArchived: false,
      memo: _nullable(_memo.text),
      barcodeValue: barcode,
      barcodeFormat: barcode == null ? null : _detectBarcodeFormat(barcode),
      packageQuantity: package,
      packageUnit: _packageUnit,
      visualKey: _visualKey,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (existing == null) {
        await widget.repository.create(entry);
      } else {
        await widget.repository.update(entry);
      }
      final saved = (await widget.repository.list()).singleWhere(
        (candidate) => candidate.foodId == entry.foodId,
      );
      if (!mounted) return;
      ActionableFeedbackRegion.resolveDeferred(
        ActionableFeedbackResult.accepted,
      );
      FoodSavedFloatingHud.showFor(context, label: 'FOOD');
      Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) return;
      _showSaveFailure('食品データベースへの保存に失敗しました', clearSaving: true);
    }
  }

  void _showSaveFailure(String detail, {bool clearSaving = false}) {
    ActionableFeedbackRegion.resolveDeferred(
      ActionableFeedbackResult.unavailable,
    );
    setState(() {
      if (clearSaving) _saving = false;
      // Save failures are presented by the shared HUD. Keep values editable
      // without duplicating the same validation detail inline.
      _error = null;
    });
    FoodSavedFloatingHud.showFor(
      context,
      label: 'FOOD',
      failed: true,
      detail: detail,
    );
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
    onWillPop: () async {
      FocusScope.of(context).unfocus();
      return true;
    },
    child: FoodFeatureScaffold(
      appBar: foodFeatureAppBar(
        leading: const ActionableBackButton(),
        title: widget.initialEntry == null ? 'ADD FOOD' : 'EDIT FOOD',
      ),
      body: FoodFormTheme(
        child: SingleChildScrollView(
          padding: AppSpacing.cardPadding,
          child: OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(icon: Icons.restaurant_menu, title: 'FOOD'),
                FoodFormMetrics.gap,
                OperationButton(
                  key: const ValueKey('food-catalog-ocr'),
                  icon: Icons.document_scanner,
                  text: _capturing
                      ? 'PROCESSING IMAGE'
                      : 'SCAN NUTRITION LABEL',
                  onPressed: _capturing || _saving ? null : _scanOcr,
                ),
                FoodFormMetrics.gap,
                OperationTextField(controller: _name, label: 'NAME'),
                FoodFormMetrics.gap,
                LayoutBuilder(
                  builder: (context, constraints) {
                    final brand = OperationTextField(
                      controller: _brand,
                      label: 'BRAND',
                    );
                    final category = FoodCategoryDropdown<FoodCatalogCategory>(
                      value: _category,
                      values: FoodCatalogCategory.values,
                      labelFor: foodCatalogCategoryLabel,
                      onChanged: (value) {
                        if (value == null) return;
                        if (value == _category) return;
                        GlobalTouchRipple.previewFeedback(
                          TouchFeedbackSound.cursor,
                        );
                        setState(() => _category = value);
                      },
                    );
                    if (constraints.maxWidth < 300) {
                      return Column(
                        key: const ValueKey('food-catalog-attributes-stacked'),
                        children: [brand, FoodFormMetrics.gap, category],
                      );
                    }
                    return Row(
                      key: const ValueKey('food-catalog-attributes-paired'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: brand),
                        FoodFormMetrics.horizontalGap,
                        Expanded(child: category),
                      ],
                    );
                  },
                ),
                FoodFormMetrics.gap,
                _FoodThumbnailField(
                  visualKey: _visualKey,
                  onChange: _selectThumbnail,
                ),
                FoodFormMetrics.gap,
                Row(
                  children: [
                    Expanded(
                      child: OperationTextField(
                        controller: _barcode,
                        label: 'BARCODE / JAN',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    FoodFormMetrics.horizontalGap,
                    OutlinedButton.icon(
                      key: const ValueKey('food-catalog-barcode-scan'),
                      onPressed: _capturing || _saving ? null : _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(_capturing ? '...' : 'SCAN'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: FoodFormMetrics.barcodeButtonSize,
                        padding: FoodFormMetrics.barcodeButtonPadding,
                      ),
                    ).actionableFeedback(),
                  ],
                ),
                if (_barcode.text.trim().isNotEmpty) ...[
                  AppSpacing.gapXS,
                  Text(
                    'FORMAT  ${_detectBarcodeFormat(_barcode.text.trim()).name.toUpperCase()}',
                    key: const ValueKey('food-catalog-barcode-format'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                FoodFormMetrics.gap,
                _quantityRow(
                  controller: _packageQuantity,
                  label: 'PACKAGE QUANTITY',
                  value: _packageUnit,
                  allowNull: true,
                  onTextChanged: _packageQuantityChanged,
                  onChanged: _packageUnitChanged,
                ),
                FoodFormMetrics.gap,
                _quantityRow(
                  controller: _baseQuantity,
                  label: 'NUTRITION BASIS',
                  value: _baseUnit,
                  onTextChanged: _baseQuantityChanged,
                  onChanged: _baseUnitChanged,
                ),
                FoodFormMetrics.gap,
                _nutritionEditorPanel(),
                FoodFormMetrics.gap,
                OperationButton(
                  key: const ValueKey('food-catalog-recalculate-nutrition'),
                  icon: Icons.calculate_outlined,
                  text: 'RECALCULATE NUTRITION',
                  onPressed: _recalculationBlockReason == null
                      ? _previewNutritionRecalculation
                      : null,
                  reportUnavailableTap: _recalculationBlockReason != null,
                ),
                if (_recalculationBlockReason case final reason?) ...[
                  AppSpacing.gapXS,
                  Text(
                    reason,
                    key: const ValueKey('food-catalog-recalculation-reason'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                FoodFormMetrics.gap,
                OperationTextField(controller: _memo, label: 'MEMO'),
                if (_error != null) ...[
                  FoodFormMetrics.gap,
                  Text(
                    _error!,
                    key: const ValueKey('food-catalog-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                AppSpacing.gapXL,
                OperationButton(
                  icon: Icons.save,
                  text: 'SAVE',
                  onPressed: _saving ? null : _save,
                  deferFeedback: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _quantityRow({
    required TextEditingController controller,
    required String label,
    required FoodQuantityUnit? value,
    required ValueChanged<FoodQuantityUnit?> onChanged,
    ValueChanged<String>? onTextChanged,
    bool allowNull = false,
  }) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: FoodFormMetrics.fieldSurface,
      border: Border.all(color: FoodFormMetrics.separator),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: OperationTextField(
            controller: controller,
            label: label,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onTextChanged,
          ),
        ),
        FoodFormMetrics.horizontalGap,
        Expanded(
          flex: 2,
          child: _dropdown<FoodQuantityUnit?>(
            label: 'UNIT',
            value: value,
            values: [if (allowNull) null, ...FoodQuantityUnit.values],
            text: (unit) => unit == null ? 'NOT SET' : _unit(unit),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );

  Widget _nutritionEditorPanel() => Container(
    key: const ValueKey('food-catalog-nutrition-panel'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FoodFormMetrics.nutritionSurface,
      border: Border.all(color: FoodFormMetrics.separator),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'NUTRITION DATA',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: FoodFormMetrics.caption,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _CatalogNutritionFocusField(
                focusNode: _caloriesFocusNode,
                nextFocusNode: _proteinFocusNode,
                child: OperationTextField(
                  controller: _calories,
                  label: 'CALORIES',
                  keyboardType: TextInputType.number,
                  focusNode: _caloriesFocusNode,
                  onChanged: (_) => setState(() => _rawCalories = null),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('kcal', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: FoodFormMetrics.separator),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              _macroNutritionField(
                controller: _protein,
                label: 'PROTEIN',
                color: FoodFormMetrics.protein,
                onChanged: () => setState(() => _rawProtein = null),
                focusNode: _proteinFocusNode,
                previousFocusNode: _caloriesFocusNode,
                nextFocusNode: _fatFocusNode,
              ),
              _macroNutritionField(
                controller: _fat,
                label: 'FAT',
                color: FoodFormMetrics.fat,
                onChanged: () => setState(() => _rawFat = null),
                focusNode: _fatFocusNode,
                previousFocusNode: _proteinFocusNode,
                nextFocusNode: _carbsFocusNode,
              ),
              _macroNutritionField(
                controller: _carbs,
                label: 'CARBOHYDRATE',
                color: FoodFormMetrics.carbohydrate,
                onChanged: () => setState(() => _rawCarbohydrate = null),
                focusNode: _carbsFocusNode,
                previousFocusNode: _fatFocusNode,
              ),
            ];
            if (constraints.maxWidth >= 250) {
              return Row(
                children: [
                  for (var index = 0; index < fields.length; index++) ...[
                    Expanded(child: fields[index]),
                    if (index != fields.length - 1)
                      const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              );
            }
            final width = (constraints.maxWidth - AppSpacing.xs) / 2;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.sm,
              children: [
                for (final field in fields)
                  SizedBox(width: width, child: field),
              ],
            );
          },
        ),
        FoodNutritionFocusToolbar(
          nodes: [
            _caloriesFocusNode,
            _proteinFocusNode,
            _fatFocusNode,
            _carbsFocusNode,
          ],
        ),
      ],
    ),
  );

  Widget _macroNutritionField({
    required TextEditingController controller,
    required String label,
    required Color color,
    required VoidCallback onChanged,
    FocusNode? focusNode,
    FocusNode? previousFocusNode,
    FocusNode? nextFocusNode,
  }) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          labelStyle: theme.inputDecorationTheme.labelStyle?.copyWith(
            color: color,
            fontSize: 9.5,
          ),
          floatingLabelStyle: theme.inputDecorationTheme.floatingLabelStyle
              ?.copyWith(color: color, fontSize: 9.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
        ),
      ),
      child: _CatalogNutritionFocusField(
        focusNode: focusNode,
        previousFocusNode: previousFocusNode,
        nextFocusNode: nextFocusNode,
        child: OperationTextField(
          controller: controller,
          label: label,
          keyboardType: TextInputType.number,
          focusNode: focusNode,
          onChanged: (_) => onChanged(),
        ),
      ),
    );
  }

  void _setNutrition(NutritionSnapshot nutrition) {
    _rawCalories = nutrition.calories;
    _rawProtein = nutrition.protein;
    _rawFat = nutrition.fat;
    _rawCarbohydrate = nutrition.carbohydrate;
    _calories.text = nutrition.calories == null
        ? ''
        : FoodNutritionFormatter.calories(nutrition.calories!);
    _protein.text = nutrition.protein == null
        ? ''
        : FoodNutritionFormatter.macro(nutrition.protein!);
    _fat.text = nutrition.fat == null
        ? ''
        : FoodNutritionFormatter.macro(nutrition.fat!);
    _carbs.text = nutrition.carbohydrate == null
        ? ''
        : FoodNutritionFormatter.macro(nutrition.carbohydrate!);
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    style: Theme.of(context).textTheme.bodyLarge,
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(text(item))),
    ],
    onChanged: (item) {
      if (item != null || values.contains(null)) {
        onChanged(item as T);
      }
    },
  ).inputFeedback();
}

class _CatalogNutritionFocusField extends StatelessWidget {
  const _CatalogNutritionFocusField({
    required this.child,
    this.focusNode,
    this.previousFocusNode,
    this.nextFocusNode,
  });

  final Widget child;
  final FocusNode? focusNode;
  final FocusNode? previousFocusNode;
  final FocusNode? nextFocusNode;

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          nextFocusNode != null) {
        nextFocusNode!.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          previousFocusNode != null) {
        previousFocusNode!.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}

class _NutritionRecalculationRow extends StatelessWidget {
  const _NutritionRecalculationRow({
    required this.label,
    required this.before,
    required this.after,
    this.calories = false,
  });

  final String label;
  final double? before;
  final double? after;
  final bool calories;

  String _value(double? value) {
    if (value == null) return 'NOT AVAILABLE';
    return calories
        ? FoodNutritionFormatter.calories(value)
        : FoodNutritionFormatter.macro(value);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Text('${_value(before)}  →  ${_value(after)}'),
      ],
    ),
  );
}

class _FoodVisualSelection {
  const _FoodVisualSelection(this.visualKey);

  final FoodVisualKey? visualKey;
}

class _FoodThumbnailField extends StatelessWidget {
  const _FoodThumbnailField({required this.visualKey, required this.onChange});

  static const double _horizontalMinimumContentWidth = 280;

  final FoodVisualKey? visualKey;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('food-catalog-thumbnail-field'),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _horizontalMinimumContentWidth) {
          return _buildCompactLayout(context);
        }
        return _buildHorizontalLayout(context);
      },
    ),
  );

  Widget _buildHorizontalLayout(BuildContext context) => Row(
    key: const ValueKey('food-catalog-thumbnail-layout-horizontal'),
    children: [
      FoodThumbnail(visualKey: visualKey, size: 48),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_heading(context), _value()],
        ),
      ),
      _changeButton(),
    ],
  );

  Widget _buildCompactLayout(BuildContext context) => Column(
    key: const ValueKey('food-catalog-thumbnail-layout-compact'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(context),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          FoodThumbnail(visualKey: visualKey, size: 48),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _value()),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(alignment: Alignment.centerRight, child: _changeButton()),
    ],
  );

  Widget _heading(BuildContext context) => Text(
    'THUMBNAIL',
    key: const ValueKey('food-catalog-thumbnail-label'),
    maxLines: 1,
    softWrap: false,
    style: Theme.of(context).textTheme.labelLarge,
  );

  Widget _value() => Text(
    visualKey == null ? 'NOT SET' : foodVisualKeyLabel(visualKey!),
    key: const ValueKey('food-catalog-thumbnail-value'),
  );

  Widget _changeButton() => OutlinedButton(
    key: const ValueKey('food-catalog-thumbnail-change'),
    onPressed: onChange,
    child: const Text('CHANGE'),
  ).actionableFeedback();
}

class _FoodVisualChoice extends StatelessWidget {
  const _FoodVisualChoice({
    required this.visualKey,
    required this.selected,
    required this.onTap,
  });

  final FoodVisualKey? visualKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = visualKey == null
        ? 'NOT SET'
        : foodVisualKeyLabel(visualKey!);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label thumbnail',
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(
            'food-thumbnail-choice-${visualKey?.stableId ?? 'not-set'}',
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FoodThumbnail(visualKey: visualKey, size: 52),
                AppSpacing.gapXS,
                Text(label, maxLines: 1),
              ],
            ),
          ),
        ).actionableFeedback(role: ActionableFeedbackRole.silent),
      ),
    );
  }
}

class FoodCatalogDetailPage extends StatelessWidget {
  const FoodCatalogDetailPage({
    super.key,
    required this.entry,
    required this.repository,
  });

  final FoodCatalogEntry entry;
  final FoodCatalogRepository repository;

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.push<FoodCatalogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FoodCatalogEditorPage(repository: repository, initialEntry: entry),
      ),
    );
    if (saved != null && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この食品を削除しますか？'),
        content: const Text(
          'Food Databaseから削除されます。\n'
          '過去に保存済みの食事記録は変更されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ).actionableFeedback(role: ActionableFeedbackRole.exit),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('削除'),
          ).actionableFeedback(),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.delete(entry.foodId);
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = entry.nutrition;
    final hasChart = FoodPfcBalanceCard.hasBalance(nutrition);
    return FoodFeatureScaffold(
      appBar: foodFeatureAppBar(
        leading: const ActionableBackButton(),
        title: 'FOOD DETAIL',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FoodDetailSurface(
              key: const ValueKey('food-detail-information-card'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xCC172330),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF304659)),
                        ),
                        child: FoodThumbnail(
                          visualKey: entry.visualKey,
                          size: 52,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          entry.name,
                          key: const ValueKey('food-detail-name'),
                          style: const TextStyle(
                            color: Color(0xFFF1F7FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(color: Color(0xFF2A4254), height: 1),
                  if (entry.brand != null) _detail('BRAND', entry.brand!),
                  _detail('CATEGORY', foodCatalogCategoryLabel(entry.category)),
                  _detail(
                    'NUTRITION BASIS',
                    '${_basis(entry.baseQuantity)} PER BASIS',
                  ),
                  if (entry.packageQuantity != null)
                    _detail(
                      'PACKAGE SIZE',
                      '${_format(entry.packageQuantity!)}${_unit(entry.packageUnit!)}',
                    ),
                  if (entry.barcodeValue != null)
                    _detail(
                      'BARCODE / JAN',
                      entry.barcodeValue!,
                      selectable: true,
                    ),
                  if (entry.memo != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _MetadataChip(label: 'MEMO', value: entry.memo!),
                  ],
                ],
              ),
            ),
            if (hasChart) ...[
              AppSpacing.gapMD,
              FoodPfcBalanceCard(
                nutrition: nutrition,
                style: FoodPfcBalanceStyle.foodDetail,
              ),
            ],
            if (!appInitializationController.value.isReadOnly) ...[
              AppSpacing.gapMD,
              _FoodDetailActionButton(
                icon: Icons.edit,
                text: 'EDIT',
                onPressed: () => _edit(context),
                backgroundColor: const Color(0xFF1D3244),
                borderColor: const Color(0xFF3B7A9C),
                foregroundColor: const Color(0xFFF1F7FF),
              ),
              AppSpacing.gapSM,
              _FoodDetailActionButton(
                icon: Icons.delete_outline,
                text: 'DELETE',
                onPressed: () => _delete(context),
                backgroundColor: const Color(0xFF151B24),
                borderColor: const Color(0xFF47323C),
                foregroundColor: const Color(0xFFE7ADB8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value, {bool selectable = false}) =>
      _FoodDetailInformationRow(
        label: label,
        value: value,
        selectable: selectable,
      );
}

class _FoodDetailSurface extends StatelessWidget {
  const _FoodDetailSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xCC101821), Color(0xCC172330)],
      ),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFF304659)),
    ),
    padding: AppSpacing.cardPadding,
    child: child,
  );
}

class _FoodDetailInformationRow extends StatelessWidget {
  const _FoodDetailInformationRow({
    required this.label,
    required this.value,
    required this.selectable,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('food-detail-row-$label'),
    constraints: const BoxConstraints(minHeight: 43),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF273D4B))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7898AB),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .55,
            ),
          ),
        ),
        Expanded(
          child: selectable
              ? SelectableText(value, style: _valueStyle)
              : Text(value, style: _valueStyle),
        ),
      ],
    ),
  );

  static const _valueStyle = TextStyle(
    color: Color(0xFFF1F7FF),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xCC17212C),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF304659)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7898AB),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF91AEB8), fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _FoodDetailActionButton extends StatelessWidget {
  const _FoodDetailActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: foregroundColor),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: borderColor),
        ),
      ),
    ).actionableFeedback(role: ActionableFeedbackRole.command),
  );
}

String _basis(FoodQuantityDefinition quantity) =>
    '${_format(quantity.value)}${_unit(quantity.unit)}';
String _unit(FoodQuantityUnit unit) => switch (unit) {
  FoodQuantityUnit.gram => 'g',
  FoodQuantityUnit.milliliter => 'mL',
  FoodQuantityUnit.piece => ' piece',
  FoodQuantityUnit.pack => ' pack',
  FoodQuantityUnit.serving => ' serving',
};
String _format(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
String _number(double? value) => value == null ? '' : _format(value);

String foodRecipeSummaryLabel(FoodRecipeDefinition recipe) {
  final yield = recipe.yieldQuantity;
  if (yield.unit == FoodQuantityUnit.serving) {
    return FoodNutritionFormatter.servings(recipe.servingCount ?? yield.value);
  }
  final parts = <String>['YIELD ${FoodNutritionFormatter.quantity(yield)}'];
  if (recipe.servingCount case final count?) {
    parts.add(FoodNutritionFormatter.servings(count));
  }
  return parts.join(' · ');
}

String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
double? _optionalNumber(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : double.tryParse(value);
}

String foodCatalogCategoryLabel(FoodCatalogCategory category) =>
    FoodNutritionFormatter.category(category);

FoodBarcodeFormat _detectBarcodeFormat(String barcode) {
  if (!_hasValidGtinCheckDigit(barcode)) return FoodBarcodeFormat.unknown;
  return switch (barcode.length) {
    13 => FoodBarcodeFormat.ean13,
    8 => FoodBarcodeFormat.ean8,
    12 => FoodBarcodeFormat.upc,
    _ => FoodBarcodeFormat.unknown,
  };
}

bool _hasValidGtinCheckDigit(String barcode) {
  if (!RegExp(r'^\d+$').hasMatch(barcode) || barcode.length < 2) return false;
  var sum = 0;
  for (var index = 0; index < barcode.length - 1; index++) {
    final distanceFromRight = barcode.length - 2 - index;
    final weight = distanceFromRight.isEven ? 3 : 1;
    sum += int.parse(barcode[index]) * weight;
  }
  final expected = (10 - sum % 10) % 10;
  return expected == int.parse(barcode[barcode.length - 1]);
}
