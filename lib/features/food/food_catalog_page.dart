import 'package:flutter/material.dart';

import '../../core/state/app_initialization_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/section_header.dart';
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

class FoodCatalogPage extends StatefulWidget {
  const FoodCatalogPage({
    super.key,
    this.repository,
    this.recipeRepository,
    this.mealRepository,
    this.selectionMode = false,
    this.recipesEnabled = true,
    this.mealsEnabled = true,
  });

  final FoodCatalogRepository? repository;
  final FoodRecipeRepository? recipeRepository;
  final FoodMealMasterRepository? mealRepository;
  final bool selectionMode;
  final bool recipesEnabled;
  final bool mealsEnabled;

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
  _FoodDatabaseView _view = _FoodDatabaseView.food;

  FoodCatalogRepository get _repository =>
      widget.repository ?? AppRepositoryRegistry.container.foodCatalog;
  FoodRecipeRepository get _recipeRepository =>
      widget.recipeRepository ?? AppRepositoryRegistry.container.foodRecipes;
  FoodMealMasterRepository get _mealRepository =>
      widget.mealRepository ?? AppRepositoryRegistry.container.foodMealMasters;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (query.isEmpty) return _entries;
    return _entries
        .where(
          (entry) =>
              entry.name.toLowerCase().contains(query) ||
              (entry.brand?.toLowerCase().contains(query) ?? false) ||
              (entry.barcodeValue?.toLowerCase().contains(query) ?? false),
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
    setState(() {
      _view = view;
      _search.clear();
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
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FoodCatalogEditorPage(repository: _repository, initialEntry: entry),
      ),
    );
    if (changed == true) await _load();
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.selectionMode
            ? widget.recipesEnabled
                  ? widget.mealsEnabled
                        ? 'SELECT FOOD / RECIPE / MEAL'
                        : 'SELECT FOOD / RECIPE'
                  : 'SELECT FOOD'
            : 'FOOD DATABASE',
      ),
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
          ),
    body: Padding(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          if (widget.recipesEnabled) ...[
            SegmentedButton<_FoodDatabaseView>(
              key: const ValueKey('food-database-type'),
              segments: [
                const ButtonSegment(
                  value: _FoodDatabaseView.food,
                  icon: Icon(Icons.restaurant_outlined),
                  label: Text('FOOD'),
                ),
                const ButtonSegment(
                  value: _FoodDatabaseView.recipe,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('RECIPE'),
                ),
                if (widget.mealsEnabled)
                  const ButtonSegment(
                    value: _FoodDatabaseView.meal,
                    icon: Icon(Icons.view_list_outlined),
                    label: Text('MEAL'),
                  ),
              ],
              selected: {_view},
              onSelectionChanged: (value) => _selectView(value.single),
            ),
            AppSpacing.gapMD,
          ],
          OperationTextField(
            key: const ValueKey('food-catalog-search'),
            controller: _search,
            label: switch (_view) {
              _FoodDatabaseView.food => 'SEARCH NAME / BRAND / BARCODE',
              _FoodDatabaseView.recipe => 'SEARCH RECIPE NAME',
              _FoodDatabaseView.meal => 'SEARCH MEAL NAME',
            },
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapMD,
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: OperationButton(
          icon: Icons.refresh,
          text: 'RETRY',
          onPressed: switch (_view) {
            _FoodDatabaseView.food => _load,
            _FoodDatabaseView.recipe => _loadRecipes,
            _FoodDatabaseView.meal => _loadMeals,
          },
        ),
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
        return OperationCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FoodThumbnail(visualKey: entry.visualKey),
            title: Text(
              entry.name,
              key: ValueKey('food-catalog-name-${entry.foodId}'),
              style: _databaseListPrimaryStyle(context),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (entry.brand != null) '${entry.brand!} ·',
                    foodCatalogCategoryLabel(entry.category),
                    FoodNutritionFormatter.compactQuantity(entry.baseQuantity),
                    if (entry.barcodeValue != null) entry.barcodeValue!,
                  ].join('  '),
                  key: ValueKey('food-catalog-metadata-${entry.foodId}'),
                  style: _databaseListMetadataStyle(context),
                ),
                Text(
                  FoodNutritionFormatter.compactNutrition(entry.nutrition),
                  key: ValueKey('food-catalog-nutrition-${entry.foodId}'),
                  style: _databaseListMetadataStyle(context),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openEntry(entry),
          ),
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
          ),
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
          ),
        );
      },
    );
  }
}

enum _FoodDatabaseView { food, recipe, meal }

TextStyle? _databaseListPrimaryStyle(BuildContext context) => Theme.of(
  context,
).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

TextStyle? _databaseListMetadataStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.2,
    );

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
  static const double _pairedAttributeMinimumWidth = 344;

  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _packageQuantity = TextEditingController();
  final _baseQuantity = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
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
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('PHOTO LIBRARY'),
                onTap: () => Navigator.pop(context, FoodImageSource.gallery),
              ),
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
          ),
          FilledButton(
            key: const ValueKey('nutrition-recalculation-apply'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('APPLY'),
          ),
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
      setState(() => _error = 'ENTER VALID FOOD AND QUANTITY VALUES');
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
        setState(() => _error = 'EXISTING FOOD FOUND: ${duplicate.first.name}');
        return;
      }
    }
    final timestamp = DateTime.now().toUtc();
    final existing = widget.initialEntry;
    final nutrition = NutritionSnapshot(
      calories: _rawCalories ?? _optionalNumber(_calories),
      protein: _rawProtein ?? _optionalNumber(_protein),
      fat: _rawFat ?? _optionalNumber(_fat),
      carbohydrate: _rawCarbohydrate ?? _optionalNumber(_carbs),
    );
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
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '食品データベースへの保存に失敗しました';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initialEntry == null ? 'ADD FOOD' : 'EDIT FOOD'),
    ),
    body: SingleChildScrollView(
      padding: AppSpacing.cardPadding,
      child: OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(icon: Icons.restaurant_menu, title: 'FOOD'),
            AppSpacing.gapMD,
            OperationButton(
              key: const ValueKey('food-catalog-ocr'),
              icon: Icons.document_scanner,
              text: _capturing ? 'PROCESSING IMAGE' : 'SCAN NUTRITION LABEL',
              onPressed: _capturing || _saving ? null : _scanOcr,
            ),
            AppSpacing.gapMD,
            OperationTextField(controller: _name, label: 'NAME'),
            AppSpacing.gapMD,
            OperationTextField(controller: _brand, label: 'BRAND'),
            AppSpacing.gapMD,
            LayoutBuilder(
              builder: (context, constraints) {
                final category = _dropdown(
                  label: 'CATEGORY',
                  value: _category,
                  values: FoodCatalogCategory.values,
                  text: foodCatalogCategoryLabel,
                  onChanged: (value) => setState(() => _category = value),
                );
                final thumbnail = _FoodThumbnailField(
                  visualKey: _visualKey,
                  onChange: _selectThumbnail,
                  dense: constraints.maxWidth >= _pairedAttributeMinimumWidth,
                );
                if (constraints.maxWidth < _pairedAttributeMinimumWidth) {
                  return Column(
                    key: const ValueKey('food-catalog-attributes-stacked'),
                    children: [category, AppSpacing.gapMD, thumbnail],
                  );
                }
                return Row(
                  key: const ValueKey('food-catalog-attributes-paired'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: category),
                    AppSpacing.gapSM,
                    Expanded(flex: 9, child: thumbnail),
                  ],
                );
              },
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                Expanded(
                  child: OperationTextField(
                    controller: _barcode,
                    label: 'BARCODE / JAN',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('food-catalog-barcode-scan'),
                  onPressed: _capturing || _saving ? null : _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_capturing ? '...' : 'SCAN'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(96, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
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
            AppSpacing.gapMD,
            _quantityRow(
              controller: _packageQuantity,
              label: 'PACKAGE QUANTITY',
              value: _packageUnit,
              allowNull: true,
              onTextChanged: _packageQuantityChanged,
              onChanged: _packageUnitChanged,
            ),
            AppSpacing.gapMD,
            _quantityRow(
              controller: _baseQuantity,
              label: 'NUTRITION BASIS',
              value: _baseUnit,
              onTextChanged: _baseQuantityChanged,
              onChanged: _baseUnitChanged,
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                Expanded(
                  child: OperationTextField(
                    controller: _calories,
                    label: 'CALORIES',
                    onChanged: (_) => setState(() => _rawCalories = null),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OperationTextField(
                    controller: _protein,
                    label: 'PROTEIN',
                    onChanged: (_) => setState(() => _rawProtein = null),
                  ),
                ),
              ],
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                Expanded(
                  child: OperationTextField(
                    controller: _fat,
                    label: 'FAT',
                    onChanged: (_) => setState(() => _rawFat = null),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OperationTextField(
                    controller: _carbs,
                    label: 'CARBOHYDRATE',
                    onChanged: (_) => setState(() => _rawCarbohydrate = null),
                  ),
                ),
              ],
            ),
            AppSpacing.gapMD,
            OperationButton(
              key: const ValueKey('food-catalog-recalculate-nutrition'),
              icon: Icons.calculate_outlined,
              text: 'RECALCULATE NUTRITION',
              onPressed: _recalculationBlockReason == null
                  ? _previewNutritionRecalculation
                  : null,
            ),
            if (_recalculationBlockReason case final reason?) ...[
              AppSpacing.gapXS,
              Text(
                reason,
                key: const ValueKey('food-catalog-recalculation-reason'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            AppSpacing.gapMD,
            OperationTextField(controller: _memo, label: 'MEMO'),
            if (_error != null) ...[
              AppSpacing.gapMD,
              Text(
                _error!,
                key: const ValueKey('food-catalog-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            AppSpacing.gapXL,
            OperationButton(
              icon: Icons.save,
              text: 'SAVE',
              onPressed: _saving ? null : _save,
            ),
          ],
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
  }) => Row(
    children: [
      Expanded(
        child: OperationTextField(
          controller: controller,
          label: label,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onTextChanged,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: _dropdown<FoodQuantityUnit?>(
          label: 'UNIT',
          value: value,
          values: [if (allowNull) null, ...FoodQuantityUnit.values],
          text: (unit) => unit == null ? 'NOT SET' : _unit(unit),
          onChanged: onChanged,
        ),
      ),
    ],
  );

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
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(text(item))),
    ],
    onChanged: (item) {
      if (item != null || values.contains(null)) {
        onChanged(item as T);
      }
    },
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
  const _FoodThumbnailField({
    required this.visualKey,
    required this.onChange,
    this.dense = false,
  });

  static const double _horizontalMinimumContentWidth = 280;

  final FoodVisualKey? visualKey;
  final VoidCallback onChange;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('food-catalog-thumbnail-field'),
    padding: EdgeInsets.all(dense ? AppSpacing.sm : AppSpacing.md),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (dense) return _buildDenseLayout(context);
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

  Widget _buildDenseLayout(BuildContext context) => Column(
    key: const ValueKey('food-catalog-thumbnail-layout-dense'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: _heading(context)),
          TextButton(
            key: const ValueKey('food-catalog-thumbnail-change'),
            onPressed: onChange,
            style: TextButton.styleFrom(
              minimumSize: const Size(52, 40),
              padding: EdgeInsets.zero,
            ),
            child: const Text('CHANGE'),
          ),
        ],
      ),
      Row(
        children: [
          FoodThumbnail(visualKey: visualKey, size: 32),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: _value()),
        ],
      ),
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
  );
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
        ),
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
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FoodCatalogEditorPage(repository: repository, initialEntry: entry),
      ),
    );
    if (changed == true && context.mounted) Navigator.pop(context, true);
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
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('削除'),
          ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('FOOD DETAIL')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OperationCard(
              key: const ValueKey('food-detail-information-card'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(icon: Icons.restaurant_menu, title: entry.name),
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
                    _detail('BARCODE / JAN', entry.barcodeValue!),
                  if (entry.memo != null) _detail('MEMO', entry.memo!),
                ],
              ),
            ),
            if (hasChart) ...[
              AppSpacing.gapMD,
              FoodPfcBalanceCard(nutrition: nutrition),
            ],
            if (!appInitializationController.value.isReadOnly) ...[
              AppSpacing.gapMD,
              OperationButton(
                icon: Icons.edit,
                text: 'EDIT',
                onPressed: () => _edit(context),
              ),
              AppSpacing.gapSM,
              OperationButton(
                icon: Icons.delete_outline,
                text: 'DELETE',
                role: OperationActionRole.danger,
                onPressed: () => _delete(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        AppSpacing.gapXS,
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
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
