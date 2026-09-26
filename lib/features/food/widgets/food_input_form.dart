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

import '../data/water_quick_presets.dart';
import '../food_nutrition_formatter.dart';
import '../models/food_catalog_models.dart';
import '../models/food_entry_sources.dart';
import '../models/food_meal_master_models.dart';
import '../models/food_provenance_models.dart';
import '../models/food_quantity_models.dart';
import '../models/nutrition_models.dart';
import '../models/recipe_models_v2.dart';
import '../food_catalog_page.dart';
import '../../repositories/app_repository_container.dart';
import '../services/food_input_capture_gateway.dart';
import '../services/food_nutrition_recalculation.dart';
import '../services/food_recipe_nutrition.dart';
import '../services/food_meal_master_expander.dart';
import '../services/japanese_nutrition_ocr_parser.dart';
import '../services/japanese_package_ocr_parser.dart';
import 'food_input_fields.dart';
import 'food_item_list.dart';
import 'food_ocr_scanner.dart';
import 'food_thumbnail.dart';
import 'food_total_card.dart';

class FoodInputForm extends StatefulWidget {
  final Future<bool> Function(MealData data) onSave;
  final Future<bool> Function(
    MealData data,
    List<FoodCatalogEntry?> catalogSources,
    List<FoodRecipeDefinition?> recipeSources,
    List<FoodQuantityUnit> quantityUnits,
  )?
  onSaveWithCatalog;
  final Future<bool> Function(MealData data, FoodEntrySources sources)?
  onSaveWithSources;
  final MealData? initialMeal;
  final FoodEntrySources? initialSources;
  final FoodInputCaptureGateway? captureGateway;
  final ScrollController? scrollController;

  const FoodInputForm({
    super.key,
    required this.onSave,
    this.onSaveWithCatalog,
    this.onSaveWithSources,
    this.initialMeal,
    this.initialSources,
    this.captureGateway,
    this.scrollController,
  });

  @override
  State<FoodInputForm> createState() => _FoodInputFormState();
}

enum _FoodEntryInputMode { manual, databaseFood, databaseRecipe, databaseMeal }

class _SelectorOption extends StatelessWidget {
  const _SelectorOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 14)),
    ],
  );
}

class _DatabaseFoodSelection {
  const _DatabaseFoodSelection(this.value, this.mode);

  final Object value;
  final _FoodEntryInputMode mode;
}

class _RecipeIngredientDraft {
  const _RecipeIngredientDraft(this.source, this.quantity);

  final RecipeIngredientV2 source;
  final double quantity;
}

/// Numeric text has an editing phase that is distinct from a committed FOOD
/// value. In particular, Dart accepts `0.` as `0`, even though the user may
/// still be typing `0.5`. Never send anything except a positive, complete
/// value into the Meal calculation model.
enum _FoodNumericTextState { valid, transient, invalid }

class _FoodNumericTextValue {
  const _FoodNumericTextValue._(this.state, this.value);

  final _FoodNumericTextState state;
  final double? value;

  factory _FoodNumericTextValue.parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text == '.' || text.endsWith('.')) {
      return const _FoodNumericTextValue._(
        _FoodNumericTextState.transient,
        null,
      );
    }
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value <= 0) {
      return const _FoodNumericTextValue._(_FoodNumericTextState.invalid, null);
    }
    return _FoodNumericTextValue._(_FoodNumericTextState.valid, value);
  }
}

class _FoodInputFormState extends State<FoodInputForm> {
  static const double _defaultBaseAmount = 100;
  static const double _defaultAmount = 1;

  final foodNameController = TextEditingController();
  final brandController = TextEditingController();
  final barcodeController = TextEditingController();
  final packageQuantityController = TextEditingController();
  final calorieController = TextEditingController();
  final proteinController = TextEditingController();
  final fatController = TextEditingController();
  final carbohydrateController = TextEditingController();
  final baseAmountController = TextEditingController();
  final amountController = TextEditingController();
  final waterVolumeController = TextEditingController();
  final memoController = TextEditingController();
  final foodMemoController = TextEditingController();
  final _pendingQuantityController = TextEditingController();
  final _pendingUsedAmountController = TextEditingController();
  final _foodSearchController = TextEditingController();
  final _foodSearchFocusNode = FocusNode();
  final _recipeSearchController = TextEditingController();
  final _mealSearchController = TextEditingController();
  final _mealItemUsedAmountController = TextEditingController();
  final _mealItemQuantityController = TextEditingController();
  final List<TextEditingController> _recipeIngredientControllers = [];

  MealType mealType = MealType.breakfast;

  final List<FoodItem> items = [];
  final List<FoodCatalogEntry?> _catalogSources = [];
  final List<FoodRecipeDefinition?> _recipeSources = [];
  final List<FoodRecipeDefinition?> _recipeInstanceSnapshots = [];
  final List<FoodQuantityUnit> _quantityUnits = [];
  final List<String?> _foodReferenceIds = [];
  final List<String?> _recipeReferenceIds = [];
  final List<String?> _mealItemIds = [];
  final List<FoodDataProvenance?> _provenanceSnapshots = [];
  final List<NutritionStatus?> _nutritionStatuses = [];
  final List<String?> _brandSnapshots = [];
  final List<FoodCatalogCategory?> _categories = [];
  final List<String?> _itemMemos = [];
  final List<double?> _usageSetAmounts = [];
  final List<double?> _usageSetQuantities = [];
  final List<FoodMealQuantitySemantics?> _quantitySemantics = [];
  FoodCatalogEntry? _currentCatalogSource;
  FoodRecipeDefinition? _currentRecipeSource;
  FoodCatalogCategory category = FoodCatalogCategory.preparedFood;
  FoodQuantityUnit? packageUnit;

  int? _mealItemEditingIndex;
  String? _mealItemEditError;
  bool isWaterEntry = false;
  String? inputError;
  FoodQuantityUnit baseUnit = FoodQuantityUnit.gram;
  double? _rawCalories;
  double? _rawProtein;
  double? _rawFat;
  double? _rawCarbohydrate;
  bool _isSaving = false;
  bool _capturingNutrition = false;
  bool _capturingBarcode = false;
  bool _basisLinkedToPackage = true;
  _FoodEntryInputMode _inputMode = _FoodEntryInputMode.manual;
  _DatabaseFoodSelection? _pendingDatabaseSelection;
  FoodRecipeDefinition? _pendingRecipeSource;
  List<_RecipeIngredientDraft> _pendingRecipeIngredients = const [];
  bool _addingDatabaseItem = false;
  bool _foodListExpanded = false;
  bool _recipeListExpanded = false;
  bool _mealListExpanded = false;
  Future<List<FoodCatalogEntry>>? _foodDiscoveryFuture;
  Future<List<FoodRecipeDefinition>>? _recipeDiscoveryFuture;
  Future<List<FoodMealMaster>>? _mealDiscoveryFuture;
  final _quantityConfirmationKey = GlobalKey();
  double? _databaseListScrollOffset;

  FoodInputCaptureGateway get _captureGateway =>
      widget.captureGateway ?? createFoodInputCaptureGateway();

  @override
  void initState() {
    super.initState();
    _setDefaultMeasurementInputs();

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
    final sources = widget.initialSources;
    if (sources != null && sources.quantityUnits.length != meal.items.length) {
      throw ArgumentError('FOOD editor sources must match initial meal items.');
    }
    _catalogSources.addAll(
      sources?.catalogSources ?? List.filled(meal.items.length, null),
    );
    _recipeSources.addAll(
      sources?.recipeSources ?? List.filled(meal.items.length, null),
    );
    _recipeInstanceSnapshots.addAll(
      sources?.recipeInstanceSnapshots ?? List.filled(meal.items.length, null),
    );
    _quantityUnits.addAll(
      sources?.quantityUnits ??
          meal.items.map(
            (item) => item.baseUnit == FoodBaseUnit.ml
                ? FoodQuantityUnit.milliliter
                : FoodQuantityUnit.gram,
          ),
    );
    _foodReferenceIds.addAll(
      sources?.foodReferenceIds ?? List.filled(meal.items.length, null),
    );
    _recipeReferenceIds.addAll(
      sources?.recipeReferenceIds ?? List.filled(meal.items.length, null),
    );
    _mealItemIds.addAll(
      sources?.mealItemIds ?? List.filled(meal.items.length, null),
    );
    _provenanceSnapshots.addAll(
      sources?.provenanceSnapshots ?? List.filled(meal.items.length, null),
    );
    _nutritionStatuses.addAll(
      sources?.nutritionStatuses ?? List.filled(meal.items.length, null),
    );
    _brandSnapshots.addAll(
      sources?.brandSnapshots ?? List.filled(meal.items.length, null),
    );
    _categories.addAll(
      sources?.categories ?? List.filled(meal.items.length, null),
    );
    _itemMemos.addAll(sources?.memos ?? List.filled(meal.items.length, null));
    _usageSetAmounts.addAll(
      sources?.usageSetAmounts ?? List.filled(meal.items.length, null),
    );
    _usageSetQuantities.addAll(
      sources?.usageSetQuantities ?? List.filled(meal.items.length, null),
    );
    _quantitySemantics.addAll(
      sources?.quantitySemantics ?? List.filled(meal.items.length, null),
    );
  }

  @override
  void dispose() {
    foodNameController.dispose();
    brandController.dispose();
    barcodeController.dispose();
    packageQuantityController.dispose();
    calorieController.dispose();
    proteinController.dispose();
    fatController.dispose();
    carbohydrateController.dispose();
    baseAmountController.dispose();
    amountController.dispose();
    waterVolumeController.dispose();
    memoController.dispose();
    foodMemoController.dispose();
    _pendingQuantityController.dispose();
    _pendingUsedAmountController.dispose();
    _foodSearchController.dispose();
    _foodSearchFocusNode.dispose();
    _recipeSearchController.dispose();
    _mealSearchController.dispose();
    _mealItemUsedAmountController.dispose();
    _mealItemQuantityController.dispose();
    for (final controller in _recipeIngredientControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  FoodItem? _currentFoodItem({int quantity = 1}) {
    final name = foodNameController.text.trim();

    if (name.isEmpty) {
      return null;
    }

    final currentCatalog = _currentCatalogSource;
    if (currentCatalog != null && _currentRecipeSource == null) {
      final usedAmount = double.tryParse(amountController.text.trim());
      if (usedAmount == null || !usedAmount.isFinite || usedAmount <= 0) {
        return null;
      }
      return _databaseFoodItem(
        currentCatalog,
        usedAmount: usedAmount,
        basisQuantity:
            double.tryParse(baseAmountController.text.trim()) ??
            _catalogSourceBaseAmount(currentCatalog),
      );
    }

    final calories =
        _rawCalories ?? double.tryParse(calorieController.text.trim());
    final protein =
        _rawProtein ?? double.tryParse(proteinController.text.trim());
    final fat = _rawFat ?? double.tryParse(fatController.text.trim());
    final carbohydrate =
        _rawCarbohydrate ?? double.tryParse(carbohydrateController.text.trim());
    if ([
      calories,
      protein,
      fat,
      carbohydrate,
    ].any((value) => value == null || !value.isFinite || value < 0)) {
      return null;
    }

    if (_currentRecipeSource != null) {
      final servings = double.tryParse(amountController.text.trim());
      if (servings == null || !servings.isFinite || servings <= 0) return null;
      return FoodItem(
        name: name,
        calories: calories!,
        protein: protein!,
        fat: fat!,
        carbohydrate: carbohydrate!,
        quantity: quantity,
        amount: servings,
        baseAmount: 1,
        baseUnit: FoodBaseUnit.g,
        amountMode: FoodAmountMode.baseMultiplier,
      );
    }

    final baseAmount = double.tryParse(baseAmountController.text.trim());
    final amount = double.tryParse(amountController.text.trim());
    if (baseAmount == null ||
        !baseAmount.isFinite ||
        baseAmount <= 0 ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      return null;
    }

    try {
      return FoodItem(
        name: name,
        calories: calories!,
        protein: protein!,
        fat: fat!,
        carbohydrate: carbohydrate!,
        quantity: quantity,
        amount: amount,
        baseAmount: baseAmount,
        baseUnit: baseUnit == FoodQuantityUnit.milliliter
            ? FoodBaseUnit.ml
            : FoodBaseUnit.g,
        amountMode: FoodAmountMode.physicalAmount,
      );
    } on ArgumentError {
      return null;
    }
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
    brandController.clear();
    barcodeController.clear();
    packageQuantityController.clear();
    foodMemoController.clear();
    calorieController.clear();
    proteinController.clear();
    fatController.clear();
    carbohydrateController.clear();
    _clearRawNutrition();
    baseAmountController.clear();
    amountController.clear();
    baseUnit = FoodQuantityUnit.gram;
    category = FoodCatalogCategory.preparedFood;
    packageUnit = null;
    _basisLinkedToPackage = true;
    _setDefaultMeasurementInputs();
    inputError = null;
    _currentCatalogSource = null;
    _currentRecipeSource = null;
  }

  void _setDefaultMeasurementInputs() {
    baseAmountController.text = _formatAmount(_defaultBaseAmount);
    amountController.text = _formatAmount(_defaultAmount);
  }

  void _onBaseAmountChanged(String source) {
    _basisLinkedToPackage = false;
    _updateBaseAmount(source);
  }

  void _updateBaseAmount(String source) {
    final nextBaseAmount = double.tryParse(source.trim());
    setState(() {
      inputError = null;
      if (nextBaseAmount == null ||
          !nextBaseAmount.isFinite ||
          nextBaseAmount <= 0) {
        return;
      }
    });
  }

  void _recalculateNutrition() {
    final nutrition = _editableNutrition();
    final reason = _recalculationBlockReason;
    if (reason != null) {
      setState(() => inputError = foodManualNutritionValidationMessage(reason));
      return;
    }
    final result = FoodNutritionRecalculation.preview(
      packageQuantity: double.tryParse(packageQuantityController.text.trim()),
      packageUnit: packageUnit,
      basisQuantity: double.tryParse(baseAmountController.text.trim()),
      basisUnit: baseUnit,
      nutrition: nutrition,
    ).recalculated;
    setState(() {
      _rawCalories = result.calories;
      _rawProtein = result.protein;
      _rawFat = result.fat;
      _rawCarbohydrate = result.carbohydrate;
      calorieController.text = result.calories == null
          ? ''
          : FoodNutritionFormatter.calories(result.calories!);
      proteinController.text = result.protein == null
          ? ''
          : FoodNutritionFormatter.macro(result.protein!);
      fatController.text = result.fat == null
          ? ''
          : FoodNutritionFormatter.macro(result.fat!);
      carbohydrateController.text = result.carbohydrate == null
          ? ''
          : FoodNutritionFormatter.macro(result.carbohydrate!);
      inputError = null;
    });
  }

  NutritionSnapshot _editableNutrition() => NutritionSnapshot(
    calories: _rawCalories ?? double.tryParse(calorieController.text.trim()),
    protein: _rawProtein ?? double.tryParse(proteinController.text.trim()),
    fat: _rawFat ?? double.tryParse(fatController.text.trim()),
    carbohydrate:
        _rawCarbohydrate ?? double.tryParse(carbohydrateController.text.trim()),
  );

  String? get _recalculationBlockReason {
    final nutrition = _editableNutrition();
    final values = [
      nutrition.calories,
      nutrition.protein,
      nutrition.fat,
      nutrition.carbohydrate,
    ];
    if (values.any(
      (value) => value != null && (!value.isFinite || value < 0),
    )) {
      return 'NUTRITION VALUES MUST BE ZERO OR GREATER.';
    }
    return FoodNutritionRecalculation.blockedReason(
      packageQuantity: double.tryParse(packageQuantityController.text.trim()),
      packageUnit: packageUnit,
      basisQuantity: double.tryParse(baseAmountController.text.trim()),
      basisUnit: baseUnit,
      nutrition: nutrition,
    );
  }

  void _onPackageQuantityChanged(String source) {
    setState(() => inputError = null);
    if (!_basisLinkedToPackage || packageUnit == null) return;
    if (packageUnit!.isPhysical) {
      baseAmountController.text = source;
      _updateBaseAmount(source);
    }
  }

  void _onPackageUnitChanged(FoodQuantityUnit? unit) {
    setState(() {
      packageUnit = unit;
      inputError = null;
    });
    if (!_basisLinkedToPackage || unit == null) return;
    baseUnit = unit;
    final source = unit.isPhysical ? packageQuantityController.text : '1';
    baseAmountController.text = source;
    _updateBaseAmount(source);
  }

  void _clearForm() {
    setState(() {
      items.clear();
      _catalogSources.clear();
      _recipeSources.clear();
      _recipeInstanceSnapshots.clear();
      _quantityUnits.clear();
      _foodReferenceIds.clear();
      _recipeReferenceIds.clear();
      _mealItemIds.clear();
      _provenanceSnapshots.clear();
      _nutritionStatuses.clear();
      _brandSnapshots.clear();
      _categories.clear();
      _itemMemos.clear();
      mealType = MealType.breakfast;
      memoController.clear();
      waterVolumeController.clear();
      isWaterEntry = false;
      _clearFoodInputs();
    });
  }

  void _addWaterAmount(int amountMl) {
    final input = waterVolumeController.text.trim();
    final currentAmount = input.isEmpty ? 0.0 : double.tryParse(input);
    if (currentAmount == null || !currentAmount.isFinite || currentAmount < 0) {
      return;
    }

    final nextAmount = currentAmount + amountMl;
    waterVolumeController.text = nextAmount == nextAmount.roundToDouble()
        ? nextAmount.toStringAsFixed(0)
        : nextAmount.toString();
  }

  void addFood() {
    final item = _currentFoodItem();

    if (item == null) {
      setState(() {
        inputError =
            'Enter valid food, base amount, quantity, and nutrition values.';
      });
      return;
    }

    setState(() {
      items.add(item);
      _catalogSources.add(_currentCatalogSource);
      _recipeSources.add(_currentRecipeSource);
      _recipeInstanceSnapshots.add(null);
      _quantityUnits.add(baseUnit);
      _foodReferenceIds.add(_currentCatalogSource?.foodId);
      _recipeReferenceIds.add(_currentRecipeSource?.recipeId);
      _mealItemIds.add(null);
      _provenanceSnapshots.add(null);
      _nutritionStatuses.add(null);
      _brandSnapshots.add(_currentCatalogSource?.brand);
      _categories.add(_currentCatalogSource?.category);
      _itemMemos.add(null);
      inputError = null;
      _clearFoodInputs();
    });
  }

  void removeFood(int index) {
    setState(() {
      items.removeAt(index);
      _catalogSources.removeAt(index);
      _recipeSources.removeAt(index);
      _recipeInstanceSnapshots.removeAt(index);
      _quantityUnits.removeAt(index);
      _foodReferenceIds.removeAt(index);
      _recipeReferenceIds.removeAt(index);
      _mealItemIds.removeAt(index);
      _provenanceSnapshots.removeAt(index);
      _nutritionStatuses.removeAt(index);
      _brandSnapshots.removeAt(index);
      _categories.removeAt(index);
      _itemMemos.removeAt(index);
      _usageSetAmounts.removeAt(index);
      _usageSetQuantities.removeAt(index);
      _quantitySemantics.removeAt(index);

      if (_mealItemEditingIndex == index) {
        _cancelMealItemEdit();
      } else if (_mealItemEditingIndex != null &&
          _mealItemEditingIndex! > index) {
        _mealItemEditingIndex = _mealItemEditingIndex! - 1;
      }
    });
  }

  FoodQuantityUnit _sourceUnit(int index) => _catalogSources[index] == null
      ? _quantityUnits[index]
      : _catalogSourceUnit(_catalogSources[index]!);

  void _setMealItemEditText(TextEditingController controller, double value) {
    final text = _formatAmount(value);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _openMealItemEditor(int index) {
    if (_mealItemEditingIndex != null || index >= items.length) return;
    final item = items[index];
    final isRecipe = _recipeSources[index] != null;
    if (!isRecipe && !item.hasMeasuredAmount) {
      setState(() {
        _mealItemEditingIndex = index;
        _mealItemEditError =
            'THIS LEGACY ITEM DOES NOT RETAIN A SAFE EDITABLE AMOUNT.';
      });
      return;
    }
    final isMultiplicative =
        !isRecipe &&
        _quantitySemantics[index] ==
            FoodMealQuantitySemantics.multiplicativeV21;
    final usedAmount = isRecipe
        ? null
        : isMultiplicative
        ? _usageSetAmounts[index]!
        : item.physicalAmount!;
    final quantity = isRecipe
        ? item.multiplier
        : isMultiplicative
        ? _usageSetQuantities[index]!
        : item.baseAmount!;
    setState(() {
      _mealItemEditingIndex = index;
      _mealItemEditError = null;
      if (usedAmount != null) {
        _setMealItemEditText(_mealItemUsedAmountController, usedAmount);
      }
      _setMealItemEditText(_mealItemQuantityController, quantity);
    });
  }

  void _changeMealItemUsedAmount(String text) {
    final index = _mealItemEditingIndex;
    final value = _FoodNumericTextValue.parse(text);
    if (index == null || value.state == _FoodNumericTextState.invalid) {
      setState(() => _mealItemEditError = 'ENTER A VALID USED AMOUNT.');
      return;
    }
    setState(() => _mealItemEditError = null);
  }

  void _changeMealItemQuantity(String text) {
    final index = _mealItemEditingIndex;
    final value = _FoodNumericTextValue.parse(text);
    if (index == null || value.state == _FoodNumericTextState.invalid) {
      setState(() => _mealItemEditError = 'ENTER A VALID QUANTITY.');
      return;
    }
    setState(() => _mealItemEditError = null);
  }

  void _adjustMealItemValue({required bool usedAmount, required double delta}) {
    final controller = usedAmount
        ? _mealItemUsedAmountController
        : _mealItemQuantityController;
    final current = _FoodNumericTextValue.parse(controller.text).value;
    if (current == null || current + delta <= 0) return;
    final next = _formatAmount(current + delta);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    if (usedAmount) {
      _changeMealItemUsedAmount(next);
    } else {
      _changeMealItemQuantity(next);
    }
  }

  FoodItem? _editedMealItem() {
    final index = _mealItemEditingIndex;
    if (index == null) return null;
    final item = items[index];
    final quantity = _FoodNumericTextValue.parse(
      _mealItemQuantityController.text,
    ).value;
    if (quantity == null) return null;
    if (_recipeSources[index] != null) {
      return item.copyWith(
        amount: quantity,
        amountMode: FoodAmountMode.baseMultiplier,
      );
    }
    final usedAmount = _FoodNumericTextValue.parse(
      _mealItemUsedAmountController.text,
    ).value;
    if (usedAmount == null) return null;
    return FoodItem(
      name: item.name,
      calories: item.calories,
      protein: item.protein,
      fat: item.fat,
      carbohydrate: item.carbohydrate,
      quantity: item.quantity,
      amount:
          _quantitySemantics[index] ==
              FoodMealQuantitySemantics.multiplicativeV21
          ? FoodMealUsage.totalUsedUnits(
              usedAmount: usedAmount,
              quantity: quantity,
            )
          : usedAmount,
      baseAmount: item.baseAmount,
      baseUnit: _sourceUnit(index) == FoodQuantityUnit.milliliter
          ? FoodBaseUnit.ml
          : FoodBaseUnit.g,
      amountMode: _catalogSources[index] == null
          ? item.amountMode
          : FoodAmountMode.physicalAmount,
    );
  }

  void _saveMealItemEdit() {
    final index = _mealItemEditingIndex;
    final edited = _editedMealItem();
    if (index == null || edited == null) {
      setState(() => _mealItemEditError = 'ENTER A VALID POSITIVE VALUE.');
      return;
    }
    setState(() {
      items[index] = edited;
      if (_quantitySemantics[index] ==
          FoodMealQuantitySemantics.multiplicativeV21) {
        _usageSetAmounts[index] = _FoodNumericTextValue.parse(
          _mealItemUsedAmountController.text,
        ).value!;
        _usageSetQuantities[index] = _FoodNumericTextValue.parse(
          _mealItemQuantityController.text,
        ).value!;
      }
      _mealItemEditingIndex = null;
      _mealItemEditError = null;
      _mealItemUsedAmountController.clear();
      _mealItemQuantityController.clear();
    });
  }

  void _cancelMealItemEdit() {
    _mealItemEditingIndex = null;
    _mealItemEditError = null;
    _mealItemUsedAmountController.clear();
    _mealItemQuantityController.clear();
  }

  void updateQuantity(int index, int change) {
    if (index >= items.length) return;

    final item = items[index];
    if (item.hasMeasuredAmount) return;
    final quantity = item.quantity + change;

    if (quantity < 1) return;

    setState(() {
      items[index] = item.copyWith(quantity: quantity);
    });
  }

  Future<void> _scanOcr() async {
    setState(() {
      inputError = null;
    });
    try {
      final result = await showNutritionLabelScanner(
        context: context,
        gateway: _captureGateway,
        onProcessingStart: () {
          if (mounted) setState(() => _capturingNutrition = true);
        },
        onProcessingComplete: () {
          if (mounted) setState(() => _capturingNutrition = false);
        },
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
        setState(() => inputError = '栄養成分表示を読み取れませんでした');
      }
    } finally {
      if (mounted) setState(() => _capturingNutrition = false);
    }
  }

  Future<FoodImageSource?> _chooseBarcodeImageSource() =>
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

  Future<void> _scanBarcode() async {
    if (_capturingBarcode) return;
    setState(() {
      _capturingBarcode = true;
      inputError = null;
    });
    try {
      final String? value;
      if (_captureGateway case final FoodLiveCaptureGateway liveGateway) {
        final candidate = await liveGateway.scanBarcodeLive();
        if (candidate == null) return;
        value = candidate.value;
      } else {
        final source = await _chooseBarcodeImageSource();
        if (source == null || !mounted) return;
        final image = await _captureGateway.selectImage(source);
        if (image == null) return;
        value = await _captureGateway.scanBarcode(image);
      }
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        setState(() => inputError = 'バーコードを読み取れませんでした');
        return;
      }
      setState(() {
        barcodeController.text = value!;
        inputError = null;
      });
    } catch (_) {
      if (mounted) setState(() => inputError = 'バーコードの読み取りに失敗しました');
    } finally {
      if (mounted) setState(() => _capturingBarcode = false);
    }
  }

  void _applyNutritionOcr(NutritionOcrDraft draft) {
    setState(() {
      if (draft.packageQuantity != null && draft.packageUnit != null) {
        packageQuantityController.text = _formatAmount(draft.packageQuantity!);
        packageUnit = draft.packageUnit;
      }
      if (draft.basisQuantity != null && draft.basisUnit != null) {
        baseAmountController.text = _formatAmount(draft.basisQuantity!);
        baseUnit = draft.basisUnit!;
        _basisLinkedToPackage = false;
      } else if (_basisLinkedToPackage && packageUnit != null) {
        final source = packageUnit!.isPhysical
            ? packageQuantityController.text
            : '1';
        baseAmountController.text = source;
        baseUnit = packageUnit!;
      }
      if (draft.calories != null) {
        _rawCalories = draft.calories;
        calorieController.text = FoodNutritionFormatter.calories(
          draft.calories!,
        );
      }
      if (draft.protein != null) {
        _rawProtein = draft.protein;
        proteinController.text = FoodNutritionFormatter.macro(draft.protein!);
      }
      if (draft.fat != null) {
        _rawFat = draft.fat;
        fatController.text = FoodNutritionFormatter.macro(draft.fat!);
      }
      if (draft.carbohydrate != null) {
        _rawCarbohydrate = draft.carbohydrate;
        carbohydrateController.text = FoodNutritionFormatter.macro(
          draft.carbohydrate!,
        );
      }
      inputError = null;
    });
  }

  void _applyPackageOcr(PackageOcrDraft draft) {
    setState(() {
      if (draft.name != null) foodNameController.text = draft.name!;
      if (draft.brand != null) brandController.text = draft.brand!;
      if (draft.packageQuantity != null && draft.packageUnit != null) {
        packageQuantityController.text = _formatAmount(draft.packageQuantity!);
        packageUnit = draft.packageUnit;
        if (_basisLinkedToPackage) {
          baseAmountController.text = draft.packageUnit!.isPhysical
              ? packageQuantityController.text
              : '1';
          baseUnit = draft.packageUnit!;
        }
      }
      inputError = null;
    });
  }

  void _selectDatabaseFood(FoodCatalogEntry selection) {
    _rememberDatabaseListScrollOffset();
    setState(() {
      _pendingDatabaseSelection = _DatabaseFoodSelection(
        selection,
        _FoodEntryInputMode.databaseFood,
      );
      _pendingQuantityController.text = '1';
      _pendingUsedAmountController.text = _formatAmount(
        _catalogSourceBaseAmount(selection),
      );
      inputError = null;
    });
    _showQuantityConfirmation();
  }

  void _rememberDatabaseListScrollOffset() {
    final controller = widget.scrollController;
    if (controller?.hasClients ?? false) {
      _databaseListScrollOffset = controller!.position.pixels;
    }
  }

  void _showQuantityConfirmation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final confirmationContext = _quantityConfirmationKey.currentContext;
      if (confirmationContext == null) return;
      Scrollable.ensureVisible(
        confirmationContext,
        alignment: 0.08,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _restoreDatabaseListScrollOffset() {
    final offset = _databaseListScrollOffset;
    final controller = widget.scrollController;
    if (offset == null || !(controller?.hasClients ?? false)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !(controller?.hasClients ?? false)) return;
        final position = controller!.position;
        controller.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
      });
    });
  }

  FoodItem? _databaseFoodItem(
    FoodCatalogEntry entry, {
    required double usedAmount,
    required double basisQuantity,
  }) {
    final nutrition = entry.nutrition;
    if ([
      nutrition.calories,
      nutrition.protein,
      nutrition.fat,
      nutrition.carbohydrate,
    ].any((value) => value == null)) {
      return null;
    }
    return FoodItem(
      name: entry.name,
      calories: nutrition.calories!,
      protein: nutrition.protein!,
      fat: nutrition.fat!,
      carbohydrate: nutrition.carbohydrate!,
      amount: usedAmount,
      baseAmount: basisQuantity,
      baseUnit: entry.baseQuantity.unit == FoodQuantityUnit.milliliter
          ? FoodBaseUnit.ml
          : FoodBaseUnit.g,
      amountMode: FoodAmountMode.physicalAmount,
    );
  }

  // Nutrition is formally registered against baseQuantity.  Package metadata
  // describes the product package, not the immutable nutrition denominator.
  double _catalogSourceBaseAmount(FoodCatalogEntry entry) =>
      entry.baseQuantity.value;

  FoodQuantityUnit _catalogSourceUnit(FoodCatalogEntry entry) =>
      entry.baseQuantity.unit;

  FoodItem? _databaseRecipeItem(FoodRecipeDefinition recipe, double servings) {
    final nutrition = FoodRecipeNutrition.perServing(recipe);
    if ([
      nutrition.calories,
      nutrition.protein,
      nutrition.fat,
      nutrition.carbohydrate,
    ].any((value) => value == null)) {
      return null;
    }
    return FoodItem(
      name: recipe.name,
      calories: nutrition.calories!,
      protein: nutrition.protein!,
      fat: nutrition.fat!,
      carbohydrate: nutrition.carbohydrate!,
      amount: servings,
      baseAmount: 1,
      baseUnit: FoodBaseUnit.g,
      amountMode: FoodAmountMode.baseMultiplier,
    );
  }

  void _resetDatabaseDiscovery(_FoodEntryInputMode mode) {
    switch (mode) {
      case _FoodEntryInputMode.databaseFood:
        // FOOD search is a temporary Entry-session concern. It intentionally
        // survives a quantity confirmation so several matching catalog items
        // can be added without recreating the search.
        return;
      case _FoodEntryInputMode.databaseRecipe:
        _recipeSearchController.clear();
        _recipeListExpanded = false;
        return;
      case _FoodEntryInputMode.databaseMeal:
        _mealSearchController.clear();
        _mealListExpanded = false;
        return;
      case _FoodEntryInputMode.manual:
        return;
    }
  }

  void _selectDatabaseRecipe(FoodRecipeDefinition recipe) {
    _rememberDatabaseListScrollOffset();
    for (final controller in _recipeIngredientControllers) {
      controller.dispose();
    }
    final drafts = recipe.ingredients
        .map(
          (ingredient) =>
              _RecipeIngredientDraft(ingredient, ingredient.quantity.value),
        )
        .toList(growable: false);
    setState(() {
      _pendingRecipeSource = recipe;
      _pendingRecipeIngredients = drafts;
      _recipeIngredientControllers
        ..clear()
        ..addAll(
          drafts.map(
            (draft) =>
                TextEditingController(text: _formatAmount(draft.quantity)),
          ),
        );
      inputError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _quantityConfirmationKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.08,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  RecipeIngredientV2 _recipeIngredientInstance(_RecipeIngredientDraft draft) {
    final source = draft.source;
    final ratio = draft.quantity / source.quantity.value;
    return RecipeIngredientV2(
      ingredientId: source.ingredientId,
      foodReferenceId: source.foodReferenceId,
      nameSnapshot: source.nameSnapshot,
      quantity: FoodQuantityDefinition(
        value: draft.quantity,
        unit: source.quantity.unit,
      ),
      nutritionSnapshot: FoodRecipeNutrition.scale(
        source.nutritionSnapshot,
        ratio,
      ),
      nutritionStatus: source.nutritionStatus,
      provenanceSnapshot: source.provenanceSnapshot,
      sortOrder: source.sortOrder,
    );
  }

  FoodRecipeDefinition _recipeInstance(FoodRecipeDefinition source) {
    final ingredients = _pendingRecipeIngredients
        .map(_recipeIngredientInstance)
        .toList(growable: false);
    return FoodRecipeDefinition(
      recipeId: source.recipeId,
      name: source.name,
      ingredients: ingredients,
      yieldQuantity: source.yieldQuantity,
      servingCount: source.servingCount,
      nutrition: FoodRecipeNutrition.total(ingredients),
      nutritionStatus: source.nutritionStatus,
      provenance: source.provenance,
      memo: source.memo,
      isArchived: source.isArchived,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
    );
  }

  void _changeRecipeIngredient(int index, String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => inputError = 'ENTER A VALID INGREDIENT AMOUNT.');
      return;
    }
    setState(() {
      final next = List<_RecipeIngredientDraft>.from(_pendingRecipeIngredients);
      next[index] = _RecipeIngredientDraft(next[index].source, value);
      _pendingRecipeIngredients = next;
      inputError = null;
    });
  }

  void _adjustRecipeIngredient(int index, double delta) {
    final controller = _recipeIngredientControllers[index];
    final current = double.tryParse(controller.text.trim()) ?? 0;
    final next = current + delta;
    if (next <= 0) return;
    controller.text = _formatAmount(next);
    _changeRecipeIngredient(index, controller.text);
  }

  void _confirmRecipeInstance() {
    final source = _pendingRecipeSource;
    if (source == null || _addingDatabaseItem) return;
    try {
      final instance = _recipeInstance(source);
      final item = _databaseRecipeItem(instance, 1);
      if (item == null) {
        throw const FormatException('RECIPE NUTRITION IS INCOMPLETE');
      }
      setState(() {
        _appendItems(
          newItems: [item],
          foodSources: [null],
          recipeSources: [source],
          recipeInstanceSnapshots: [instance],
          units: [FoodQuantityUnit.serving],
        );
        _clearRecipeInstanceDraft();
        inputError = null;
      });
    } on FormatException catch (error) {
      setState(() => inputError = error.message);
    }
  }

  void _clearRecipeInstanceDraft() {
    for (final controller in _recipeIngredientControllers) {
      controller.dispose();
    }
    _recipeIngredientControllers.clear();
    _pendingRecipeSource = null;
    _pendingRecipeIngredients = const [];
  }

  void _cancelRecipeInstance() {
    setState(() {
      _clearRecipeInstanceDraft();
      inputError = null;
    });
    _restoreDatabaseListScrollOffset();
  }

  Future<void> _addMealDirect(FoodMealMaster meal) async {
    if (_addingDatabaseItem) return;
    setState(() => _addingDatabaseItem = true);
    try {
      final expansion = await FoodMealMasterExpander(
        foods: AppRepositoryRegistry.container.foodCatalog,
        recipes: AppRepositoryRegistry.container.foodRecipes,
      ).expand(meal);
      if (!mounted) return;
      setState(() {
        _appendItems(
          newItems: expansion.items,
          foodSources: expansion.foodSources,
          recipeSources: expansion.recipeSources,
          units: expansion.quantityUnits,
        );
        _resetDatabaseDiscovery(_FoodEntryInputMode.databaseMeal);
        inputError = null;
      });
    } on FoodMealMasterExpansionException catch (error) {
      if (mounted) setState(() => inputError = error.toString());
    } finally {
      if (mounted) setState(() => _addingDatabaseItem = false);
    }
  }

  void _appendItems({
    required List<FoodItem> newItems,
    required List<FoodCatalogEntry?> foodSources,
    required List<FoodRecipeDefinition?> recipeSources,
    List<FoodRecipeDefinition?>? recipeInstanceSnapshots,
    required List<FoodQuantityUnit> units,
    List<double?>? usageSetAmounts,
    List<double?>? usageSetQuantities,
    List<FoodMealQuantitySemantics?>? quantitySemantics,
  }) {
    items.addAll(newItems);
    _catalogSources.addAll(foodSources);
    _recipeSources.addAll(recipeSources);
    _recipeInstanceSnapshots.addAll(
      recipeInstanceSnapshots ?? List.filled(newItems.length, null),
    );
    _quantityUnits.addAll(units);
    _foodReferenceIds.addAll(foodSources.map((value) => value?.foodId));
    _recipeReferenceIds.addAll(recipeSources.map((value) => value?.recipeId));
    _mealItemIds.addAll(List.filled(newItems.length, null));
    _provenanceSnapshots.addAll(List.filled(newItems.length, null));
    _nutritionStatuses.addAll(List.filled(newItems.length, null));
    _brandSnapshots.addAll(foodSources.map((value) => value?.brand));
    _categories.addAll(foodSources.map((value) => value?.category));
    _itemMemos.addAll(List.filled(newItems.length, null));
    _usageSetAmounts.addAll(
      usageSetAmounts ?? List<double?>.filled(newItems.length, null),
    );
    _usageSetQuantities.addAll(
      usageSetQuantities ?? List<double?>.filled(newItems.length, null),
    );
    _quantitySemantics.addAll(
      quantitySemantics ??
          List<FoodMealQuantitySemantics?>.filled(newItems.length, null),
    );
  }

  Future<void> _addPendingDatabaseSelection() async {
    final pending = _pendingDatabaseSelection;
    final quantity = _FoodNumericTextValue.parse(
      _pendingQuantityController.text,
    ).value;
    final usedAmount = _FoodNumericTextValue.parse(
      _pendingUsedAmountController.text,
    ).value;
    if (pending == null ||
        quantity == null ||
        (pending.value is FoodCatalogEntry && usedAmount == null)) {
      setState(() => inputError = 'ENTER A VALID QUANTITY.');
      return;
    }
    try {
      if (pending.value case final FoodCatalogEntry entry) {
        final item = _databaseFoodItem(
          entry,
          usedAmount: FoodMealUsage.totalUsedUnits(
            usedAmount: usedAmount!,
            quantity: quantity,
          ),
          basisQuantity: _catalogSourceBaseAmount(entry),
        );
        if (item == null) {
          throw const FormatException('FOOD NUTRITION IS INCOMPLETE');
        }
        setState(() {
          _appendItems(
            newItems: [item],
            foodSources: [entry],
            recipeSources: [null],
            units: [_catalogSourceUnit(entry)],
            usageSetAmounts: [usedAmount],
            usageSetQuantities: [quantity],
            quantitySemantics: [FoodMealQuantitySemantics.multiplicativeV21],
          );
          _pendingDatabaseSelection = null;
          _pendingQuantityController.clear();
          _pendingUsedAmountController.clear();
          _resetDatabaseDiscovery(_FoodEntryInputMode.databaseFood);
          inputError = null;
        });
      } else if (pending.value case final FoodRecipeDefinition recipe) {
        final item = _databaseRecipeItem(recipe, quantity);
        if (item == null) {
          throw const FormatException('RECIPE NUTRITION IS INCOMPLETE');
        }
        setState(() {
          _appendItems(
            newItems: [item],
            foodSources: [null],
            recipeSources: [recipe],
            units: [FoodQuantityUnit.serving],
          );
          _pendingDatabaseSelection = null;
          _pendingQuantityController.clear();
          _pendingUsedAmountController.clear();
          inputError = null;
        });
      } else if (pending.value case final FoodMealMaster meal) {
        final expansion = await FoodMealMasterExpander(
          foods: AppRepositoryRegistry.container.foodCatalog,
          recipes: AppRepositoryRegistry.container.foodRecipes,
        ).expand(meal);
        if (!mounted) return;
        final scaled = expansion.items
            .map((item) => item.copyWith(amount: (item.amount ?? 1) * quantity))
            .toList(growable: false);
        setState(() {
          _appendItems(
            newItems: scaled,
            foodSources: expansion.foodSources,
            recipeSources: expansion.recipeSources,
            units: expansion.quantityUnits,
          );
          _pendingDatabaseSelection = null;
          _pendingQuantityController.clear();
          _pendingUsedAmountController.clear();
          inputError = null;
        });
      }
    } on FoodMealMasterExpansionException catch (error) {
      if (mounted) setState(() => inputError = error.toString());
    } on FormatException catch (error) {
      if (mounted) setState(() => inputError = error.message);
    }
  }

  void _cancelPendingDatabaseSelection() {
    setState(() {
      _pendingDatabaseSelection = null;
      _pendingQuantityController.clear();
      _pendingUsedAmountController.clear();
      inputError = null;
    });
    _restoreDatabaseListScrollOffset();
  }

  Future<void> _saveCurrentToCatalog() async {
    if (!AppRepositoryRegistry.hasContainer) return;
    final item = _currentFoodItem();
    if (item == null) {
      setState(() => inputError = 'Enter valid food and nutrition values.');
      return;
    }
    final packageText = packageQuantityController.text.trim();
    final packageQuantity = _optionalPositiveNumber(packageQuantityController);
    if ((packageText.isNotEmpty && packageQuantity == null) ||
        (packageQuantity == null) != (packageUnit == null)) {
      setState(() => inputError = 'ENTER VALID PACKAGE QUANTITY AND UNIT.');
      return;
    }
    final consumedAmount = item.physicalAmount;
    if (consumedAmount == null) {
      setState(() => inputError = 'ENTER A VALID USED AMOUNT.');
      return;
    }
    final saved = await Navigator.push<FoodCatalogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogEditorPage(
          repository: AppRepositoryRegistry.container.foodCatalog,
          initialEntry: _currentCatalogSource,
          requireCompleteNutrition: true,
          draft: FoodCatalogDraft(
            name: item.name,
            category: category,
            brand: _nullableText(brandController.text),
            barcodeValue: _nullableText(barcodeController.text),
            packageQuantity: packageQuantity,
            packageUnit: packageUnit,
            memo: _nullableText(foodMemoController.text),
            baseQuantity: FoodQuantityDefinition(
              value: item.baseAmount ?? 1,
              unit: baseUnit,
            ),
            nutrition: NutritionSnapshot(
              calories: item.calories.toDouble(),
              protein: item.protein,
              fat: item.fat,
              carbohydrate: item.carbohydrate,
            ),
          ),
        ),
      ),
    );
    if (saved != null && mounted) {
      _bindCurrentItemToCatalog(saved, consumedAmount);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SAVED · DB LINKED')));
    }
  }

  void _bindCurrentItemToCatalog(
    FoodCatalogEntry entry,
    double consumedAmount,
  ) {
    setState(() {
      _currentCatalogSource = entry;
      _currentRecipeSource = null;
      foodNameController.text = entry.name;
      brandController.text = entry.brand ?? '';
      barcodeController.text = entry.barcodeValue ?? '';
      packageQuantityController.text = entry.packageQuantity == null
          ? ''
          : _formatAmount(entry.packageQuantity!);
      packageUnit = entry.packageUnit;
      baseAmountController.text = _formatAmount(entry.baseQuantity.value);
      baseUnit = entry.baseQuantity.unit;
      amountController.text = _formatAmount(consumedAmount);
      foodMemoController.text = entry.memo ?? '';
      category = entry.category;
      _basisLinkedToPackage = false;
      _rawCalories = entry.nutrition.calories;
      _rawProtein = entry.nutrition.protein;
      _rawFat = entry.nutrition.fat;
      _rawCarbohydrate = entry.nutrition.carbohydrate;
      calorieController.text = entry.nutrition.calories == null
          ? ''
          : FoodNutritionFormatter.calories(entry.nutrition.calories!);
      proteinController.text = entry.nutrition.protein == null
          ? ''
          : FoodNutritionFormatter.macro(entry.nutrition.protein!);
      fatController.text = entry.nutrition.fat == null
          ? ''
          : FoodNutritionFormatter.macro(entry.nutrition.fat!);
      carbohydrateController.text = entry.nutrition.carbohydrate == null
          ? ''
          : FoodNutritionFormatter.macro(entry.nutrition.carbohydrate!);
      inputError = null;
    });
  }

  /// A catalog source carries the persisted FOOD master identity.  Do not use
  /// draft nutrition or text fields as an identity proxy: an active source is
  /// already a reusable database record, while an archived source is not.
  bool get _hasActiveCatalogReference {
    final source = _currentCatalogSource;
    return source != null && source.foodId.isNotEmpty && !source.isArchived;
  }

  Future<void> saveMeal() async {
    if (_isSaving) return;
    final waterMl = double.tryParse(waterVolumeController.text.trim());

    if (isWaterEntry && (waterMl == null || waterMl <= 0)) {
      return;
    }

    if (!isWaterEntry && previewItems.isEmpty) {
      return;
    }
    if (!isWaterEntry &&
        foodNameController.text.trim().isNotEmpty &&
        _currentFoodItem() == null) {
      setState(() {
        inputError =
            'Enter valid food, base amount, quantity, and nutrition values.';
      });
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

    setState(() => _isSaving = true);
    final sources = List<FoodCatalogEntry?>.from(_catalogSources);
    final recipeSources = List<FoodRecipeDefinition?>.from(_recipeSources);
    final recipeInstances = List<FoodRecipeDefinition?>.from(
      _recipeInstanceSnapshots,
    );
    final quantityUnits = List<FoodQuantityUnit>.from(_quantityUnits);
    final foodReferenceIds = List<String?>.from(_foodReferenceIds);
    final recipeReferenceIds = List<String?>.from(_recipeReferenceIds);
    final mealItemIds = List<String?>.from(_mealItemIds);
    final provenanceSnapshots = List<FoodDataProvenance?>.from(
      _provenanceSnapshots,
    );
    final nutritionStatuses = List<NutritionStatus?>.from(_nutritionStatuses);
    final brandSnapshots = List<String?>.from(_brandSnapshots);
    final categories = List<FoodCatalogCategory?>.from(_categories);
    final itemMemos = List<String?>.from(_itemMemos);
    final usageSetAmounts = List<double?>.from(_usageSetAmounts);
    final usageSetQuantities = List<double?>.from(_usageSetQuantities);
    final quantitySemantics = List<FoodMealQuantitySemantics?>.from(
      _quantitySemantics,
    );
    if (_currentFoodItem() != null) {
      sources.add(_currentCatalogSource);
      recipeSources.add(_currentRecipeSource);
      recipeInstances.add(null);
      quantityUnits.add(baseUnit);
      foodReferenceIds.add(_currentCatalogSource?.foodId);
      recipeReferenceIds.add(_currentRecipeSource?.recipeId);
      mealItemIds.add(null);
      provenanceSnapshots.add(null);
      nutritionStatuses.add(null);
      brandSnapshots.add(_currentCatalogSource?.brand);
      categories.add(_currentCatalogSource?.category);
      itemMemos.add(null);
      usageSetAmounts.add(null);
      usageSetQuantities.add(null);
      quantitySemantics.add(null);
    }
    final entrySources = FoodEntrySources(
      catalogSources: sources,
      recipeSources: recipeSources,
      recipeInstanceSnapshots: recipeInstances,
      quantityUnits: quantityUnits,
      foodReferenceIds: foodReferenceIds,
      recipeReferenceIds: recipeReferenceIds,
      mealItemIds: mealItemIds,
      provenanceSnapshots: provenanceSnapshots,
      nutritionStatuses: nutritionStatuses,
      brandSnapshots: brandSnapshots,
      categories: categories,
      memos: itemMemos,
      usageSetAmounts: usageSetAmounts,
      usageSetQuantities: usageSetQuantities,
      quantitySemantics: quantitySemantics,
    );
    final saved = widget.onSaveWithSources != null
        ? await widget.onSaveWithSources!(meal, entrySources)
        : (sources.any((entry) => entry != null) ||
                  recipeSources.any((entry) => entry != null) ||
                  quantityUnits.any((unit) => !unit.isPhysical)) &&
              widget.onSaveWithCatalog != null
        ? await widget.onSaveWithCatalog!(
            meal,
            sources,
            recipeSources,
            quantityUnits,
          )
        : await widget.onSave(meal);

    if (!mounted) return;

    setState(() => _isSaving = false);
    if (!saved) return;
    _clearForm();
  }

  void _switchInputMode(_FoodEntryInputMode mode) {
    if (_inputMode == mode || !_canSwitchInputMode) return;
    setState(() {
      _inputMode = mode;
      inputError = null;
    });
  }

  bool get _canSwitchInputMode =>
      !_isSaving &&
      _pendingDatabaseSelection == null &&
      _mealItemEditingIndex == null;

  Widget _entryTypeControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'ENTRY TYPE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: .6,
        ),
      ),
      DropdownButtonFormField<bool>(
        key: const ValueKey('food-entry-type-selector'),
        initialValue: isWaterEntry,
        items: const [
          DropdownMenuItem(
            value: false,
            child: _SelectorOption(icon: Icons.restaurant, label: 'MEAL'),
          ),
          DropdownMenuItem(
            value: true,
            child: _SelectorOption(icon: Icons.water_drop, label: 'WATER'),
          ),
        ],
        selectedItemBuilder: (_) => const [
          _SelectorOption(icon: Icons.restaurant, label: 'MEAL'),
          _SelectorOption(icon: Icons.water_drop, label: 'WATER'),
        ],
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onChanged: _isSaving
            ? null
            : (value) => setState(() {
                isWaterEntry = value ?? false;
                if (isWaterEntry) {
                  _pendingDatabaseSelection = null;
                  _pendingQuantityController.clear();
                }
              }),
      ),
    ],
  );

  Widget _mealTypeControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'MEAL TYPE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: .6,
          color: isWaterEntry
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
      DropdownButtonFormField<MealType>(
        key: const ValueKey('food-meal-type-selector'),
        initialValue: isWaterEntry ? null : mealType,
        hint: const Text('—'),
        items: MealType.values
            .map(
              (type) => DropdownMenuItem(
                value: type,
                child: _SelectorOption(
                  icon: _mealTypeIcon(type),
                  label: type.label,
                ),
              ),
            )
            .toList(growable: false),
        selectedItemBuilder: (_) => MealType.values
            .map(
              (type) =>
                  _SelectorOption(icon: _mealTypeIcon(type), label: type.label),
            )
            .toList(growable: false),
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onChanged: isWaterEntry || _isSaving
            ? null
            : (value) => setState(() => mealType = value ?? mealType),
      ),
    ],
  );

  Widget _entryAndMealTypeControls() => LayoutBuilder(
    builder: (context, constraints) {
      final useTwoColumns = MediaQuery.sizeOf(context).width >= 360;
      if (!useTwoColumns) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _entryTypeControls(),
            AppSpacing.gapMD,
            _mealTypeControls(),
          ],
        );
      }
      return Row(
        key: const ValueKey('food-entry-type-two-column'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: _entryTypeControls()),
          AppSpacing.gapMD,
          Expanded(flex: 6, child: _mealTypeControls()),
        ],
      );
    },
  );

  IconData _mealTypeIcon(MealType type) => switch (type) {
    MealType.breakfast => Icons.breakfast_dining,
    MealType.lunch => Icons.lunch_dining,
    MealType.dinner => Icons.dinner_dining,
    MealType.snack => Icons.cookie,
    MealType.training => Icons.fitness_center,
  };

  Widget _inputModeTabs() => LayoutBuilder(
    builder: (context, constraints) {
      final textStyle =
          (constraints.maxWidth >= 300
                  ? Theme.of(context).textTheme.labelLarge
                  : Theme.of(context).textTheme.labelMedium)
              ?.copyWith(fontSize: constraints.maxWidth >= 300 ? 14 : 12);
      final colors = Theme.of(context).colorScheme;
      return Row(
        key: const ValueKey('food-entry-input-mode-tabs'),
        children: [
          for (final mode in _FoodEntryInputMode.values)
            Expanded(
              child: InkWell(
                key: ValueKey('food-entry-tab-${mode.name}'),
                onTap: _canSwitchInputMode
                    ? () => _switchInputMode(mode)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _inputModeLabel(mode),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: textStyle?.copyWith(
                          color: _inputMode == mode
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: _inputMode == mode
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 2,
                        color: _inputMode == mode
                            ? colors.primary
                            : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  String _inputModeLabel(_FoodEntryInputMode mode) => switch (mode) {
    _FoodEntryInputMode.manual => 'MANUAL',
    _FoodEntryInputMode.databaseFood => 'FOOD',
    _FoodEntryInputMode.databaseRecipe => 'RECIPE',
    _FoodEntryInputMode.databaseMeal => 'MEAL',
  };

  String _pendingName(_DatabaseFoodSelection pending) =>
      switch (pending.value) {
        FoodCatalogEntry(:final name) => name,
        FoodRecipeDefinition(:final name) => name,
        FoodMealMaster(:final name) => name,
        _ => '',
      };

  String _pendingUnit(_DatabaseFoodSelection pending) =>
      switch (pending.value) {
        final FoodCatalogEntry entry =>
          '× ${_formatAmount(_catalogSourceBaseAmount(entry))} '
              '${_catalogSourceUnit(entry).stableId}',
        FoodRecipeDefinition() => 'serving',
        FoodMealMaster() => 'meal',
        _ => '',
      };

  void _adjustPendingQuantity(double delta) {
    final current =
        _FoodNumericTextValue.parse(_pendingQuantityController.text).value ??
        _defaultAmount;
    final next = current + delta;
    if (next <= 0) return;
    setState(() {
      _pendingQuantityController.text = _formatAmount(next);
      inputError = null;
    });
  }

  void _adjustPendingUsedAmount(double delta) {
    final current =
        _FoodNumericTextValue.parse(_pendingUsedAmountController.text).value ??
        _defaultAmount;
    final next = current + delta;
    if (next <= 0) return;
    setState(() {
      _pendingUsedAmountController.text = _formatAmount(next);
      inputError = null;
    });
  }

  void _swipeInputMode(double velocity) {
    if (!_canSwitchInputMode) return;
    final index = _inputMode.index + (velocity < 0 ? 1 : -1);
    if (velocity == 0 ||
        index < 0 ||
        index >= _FoodEntryInputMode.values.length) {
      return;
    }
    _switchInputMode(_FoodEntryInputMode.values[index]);
  }

  static const _compactMasterListLimit = 5;

  TextEditingController _searchControllerFor(_FoodEntryInputMode mode) =>
      switch (mode) {
        _FoodEntryInputMode.databaseFood => _foodSearchController,
        _FoodEntryInputMode.databaseRecipe => _recipeSearchController,
        _FoodEntryInputMode.databaseMeal => _mealSearchController,
        _FoodEntryInputMode.manual => _foodSearchController,
      };

  bool _isMasterListExpanded(_FoodEntryInputMode mode) => switch (mode) {
    _FoodEntryInputMode.databaseFood => _foodListExpanded,
    _FoodEntryInputMode.databaseRecipe => _recipeListExpanded,
    _FoodEntryInputMode.databaseMeal => _mealListExpanded,
    _FoodEntryInputMode.manual => false,
  };

  void _setMasterListExpanded(_FoodEntryInputMode mode, bool expanded) {
    setState(() {
      switch (mode) {
        case _FoodEntryInputMode.databaseFood:
          _foodListExpanded = expanded;
          break;
        case _FoodEntryInputMode.databaseRecipe:
          _recipeListExpanded = expanded;
          break;
        case _FoodEntryInputMode.databaseMeal:
          _mealListExpanded = expanded;
          break;
        case _FoodEntryInputMode.manual:
          break;
      }
    });
  }

  bool _matchesSearch(String query, Iterable<String?> values) {
    final normalizedQuery = query.trim().toLowerCase();
    return normalizedQuery.isEmpty ||
        values.any(
          (value) =>
              (value ?? '').trim().toLowerCase().contains(normalizedQuery),
        );
  }

  Widget _masterSearch({
    required _FoodEntryInputMode mode,
    required String hint,
    FocusNode? focusNode,
    VoidCallback? onClear,
  }) {
    final controller = _searchControllerFor(mode);
    return SizedBox(
      height: 40,
      child: TextField(
        key: ValueKey('food-entry-search-${mode.name}'),
        controller: controller,
        focusNode: focusNode,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  key: ValueKey('food-entry-clear-search-${mode.name}'),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'CLEAR SEARCH',
                  onPressed: onClear ?? () => setState(controller.clear),
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _clearFoodSearchSession() {
    setState(() {
      _foodSearchController.clear();
      _foodListExpanded = false;
    });
    _foodSearchFocusNode.requestFocus();
  }

  Widget _masterListDisclosure({
    required _FoodEntryInputMode mode,
    required int total,
    required bool searching,
  }) {
    if (searching || total <= _compactMasterListLimit) {
      return const SizedBox.shrink();
    }
    final expanded = _isMasterListExpanded(mode);
    return Center(
      child: TextButton(
        key: ValueKey(
          'food-entry-${expanded ? 'collapse' : 'expand'}-${mode.name}',
        ),
        onPressed: () => _setMasterListExpanded(mode, !expanded),
        child: Text(expanded ? '折りたたむ' : 'さらに表示'),
      ),
    );
  }

  List<T> _visibleMasterEntries<T>(
    List<T> entries,
    _FoodEntryInputMode mode,
    bool searching,
  ) => searching || _isMasterListExpanded(mode)
      ? entries
      : entries.take(_compactMasterListLimit).toList(growable: false);

  Widget _inlineFoodList() => FutureBuilder<List<FoodCatalogEntry>>(
    future: _foodDiscoveryFuture ??= AppRepositoryRegistry.container.foodCatalog
        .list(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final entries =
          snapshot.data
              ?.where((entry) => !entry.isArchived)
              .where(
                (entry) => _matchesSearch(_foodSearchController.text, [
                  entry.name,
                  entry.brand,
                ]),
              )
              .toList(growable: false) ??
          const <FoodCatalogEntry>[];
      final searching = _foodSearchController.text.trim().isNotEmpty;
      final visible = _visibleMasterEntries(
        entries,
        _FoodEntryInputMode.databaseFood,
        searching,
      );
      return Column(
        key: const ValueKey('food-entry-inline-food-list'),
        children: [
          _masterSearch(
            mode: _FoodEntryInputMode.databaseFood,
            hint: '食品を検索',
            focusNode: _foodSearchFocusNode,
            onClear: _clearFoodSearchSession,
          ),
          AppSpacing.gapSM,
          if (entries.isEmpty)
            const Text('食品が見つかりません')
          else
            for (final entry in visible)
              ListTile(
                key: ValueKey('food-entry-inline-food-${entry.foodId}'),
                leading: FoodThumbnail(visualKey: entry.visualKey, size: 40),
                title: Text(entry.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.brand?.trim().isNotEmpty ?? false)
                      Text(
                        entry.brand!.trim(),
                        key: ValueKey('food-entry-brand-${entry.foodId}'),
                      ),
                    Text(
                      FoodNutritionFormatter.compactQuantity(
                        entry.baseQuantity,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _addingDatabaseItem
                    ? null
                    : () => _selectDatabaseFood(entry),
              ),
          _masterListDisclosure(
            mode: _FoodEntryInputMode.databaseFood,
            total: entries.length,
            searching: searching,
          ),
        ],
      );
    },
  );

  Widget _inlineRecipeList() => FutureBuilder<List<FoodRecipeDefinition>>(
    future: _recipeDiscoveryFuture ??= AppRepositoryRegistry
        .container
        .foodRecipes
        .list(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final recipes =
          snapshot.data
              ?.where((recipe) => !recipe.isArchived)
              .where(
                (recipe) =>
                    _matchesSearch(_recipeSearchController.text, [recipe.name]),
              )
              .toList(growable: false) ??
          const <FoodRecipeDefinition>[];
      final searching = _recipeSearchController.text.trim().isNotEmpty;
      final visible = _visibleMasterEntries(
        recipes,
        _FoodEntryInputMode.databaseRecipe,
        searching,
      );
      return Column(
        key: const ValueKey('food-entry-inline-recipe-list'),
        children: [
          _masterSearch(
            mode: _FoodEntryInputMode.databaseRecipe,
            hint: 'レシピを検索',
          ),
          AppSpacing.gapSM,
          if (recipes.isEmpty)
            const Text('RECIPE NOT FOUND')
          else
            for (final recipe in visible)
              ListTile(
                key: ValueKey('food-entry-inline-recipe-${recipe.recipeId}'),
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(recipe.name),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: _addingDatabaseItem
                    ? null
                    : () => _selectDatabaseRecipe(recipe),
              ),
          _masterListDisclosure(
            mode: _FoodEntryInputMode.databaseRecipe,
            total: recipes.length,
            searching: searching,
          ),
        ],
      );
    },
  );

  Widget _inlineMealList() => FutureBuilder<List<FoodMealMaster>>(
    future: _mealDiscoveryFuture ??= AppRepositoryRegistry
        .container
        .foodMealMasters
        .list(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final meals =
          snapshot.data
              ?.where((meal) => !meal.isArchived)
              .where(
                (meal) =>
                    _matchesSearch(_mealSearchController.text, [meal.name]),
              )
              .toList(growable: false) ??
          const <FoodMealMaster>[];
      final searching = _mealSearchController.text.trim().isNotEmpty;
      final visible = _visibleMasterEntries(
        meals,
        _FoodEntryInputMode.databaseMeal,
        searching,
      );
      return Column(
        key: const ValueKey('food-entry-inline-meal-list'),
        children: [
          _masterSearch(
            mode: _FoodEntryInputMode.databaseMeal,
            hint: '食事セットを検索',
          ),
          AppSpacing.gapSM,
          if (meals.isEmpty)
            const Text('MEAL NOT FOUND')
          else
            for (final meal in visible)
              ListTile(
                key: ValueKey('food-entry-inline-meal-${meal.mealMasterId}'),
                leading: const Icon(Icons.view_list_outlined),
                title: Text(meal.name),
                subtitle: Text('${meal.components.length} ITEMS'),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: _addingDatabaseItem ? null : () => _addMealDirect(meal),
              ),
          _masterListDisclosure(
            mode: _FoodEntryInputMode.databaseMeal,
            total: meals.length,
            searching: searching,
          ),
        ],
      );
    },
  );

  Widget _databaseInput() {
    final recipe = _pendingRecipeSource;
    if (recipe != null) return _recipeInstanceConfirmation(recipe);
    final pending = _pendingDatabaseSelection;
    if (pending != null) return _foodQuantityConfirmation(pending);
    if (!AppRepositoryRegistry.hasContainer) return const SizedBox.shrink();
    return switch (_inputMode) {
      _FoodEntryInputMode.databaseFood => _inlineFoodList(),
      _FoodEntryInputMode.databaseRecipe => _inlineRecipeList(),
      _FoodEntryInputMode.databaseMeal => _inlineMealList(),
      _FoodEntryInputMode.manual => const SizedBox.shrink(),
    };
  }

  Widget _recipeInstanceConfirmation(FoodRecipeDefinition recipe) {
    final instance = _recipeInstance(recipe);
    final nutrition = FoodRecipeNutrition.perServing(instance);
    return KeyedSubtree(
      key: _quantityConfirmationKey,
      child: OperationCard(
        key: const ValueKey('food-recipe-instance-confirmation'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              icon: Icons.tune_outlined,
              title: 'RECIPE CONFIRM / ADJUST',
            ),
            AppSpacing.gapSM,
            Text(recipe.name, style: Theme.of(context).textTheme.titleMedium),
            AppSpacing.gapSM,
            for (
              var index = 0;
              index < _pendingRecipeIngredients.length;
              index++
            ) ...[
              Text(_pendingRecipeIngredients[index].source.nameSnapshot),
              FoodNumericStepperRow(
                key: ValueKey('food-recipe-ingredient-$index'),
                inputKey: ValueKey('food-recipe-ingredient-input-$index'),
                controller: _recipeIngredientControllers[index],
                label: FoodNutritionFormatter.quantityUnit(
                  _pendingRecipeIngredients[index].source.quantity.unit,
                ),
                onChanged: (value) => _changeRecipeIngredient(index, value),
                incrementKey: ValueKey(
                  'food-recipe-ingredient-increment-$index',
                ),
                incrementTooltip: 'Increase ingredient amount',
                onIncrement: () => _adjustRecipeIngredient(index, 1),
                decrementKey: ValueKey(
                  'food-recipe-ingredient-decrement-$index',
                ),
                decrementTooltip: 'Decrease ingredient amount',
                onDecrement: () => _adjustRecipeIngredient(index, -1),
              ),
              AppSpacing.gapSM,
            ],
            Text(
              '${FoodNutritionFormatter.calories(nutrition.calories ?? 0)}kcal'
              '  P ${FoodNutritionFormatter.macro(nutrition.protein ?? 0)}g'
              '  F ${FoodNutritionFormatter.macro(nutrition.fat ?? 0)}g'
              '  C ${FoodNutritionFormatter.macro(nutrition.carbohydrate ?? 0)}g',
              key: const ValueKey('food-recipe-instance-nutrition'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                Expanded(
                  child: OperationButton(
                    key: const ValueKey('food-recipe-instance-add'),
                    icon: Icons.add,
                    text: 'ADD',
                    onPressed: _isSaving ? null : _confirmRecipeInstance,
                  ),
                ),
                AppSpacing.gapSM,
                OutlinedButton(
                  key: const ValueKey('food-recipe-instance-cancel'),
                  onPressed: _isSaving ? null : _cancelRecipeInstance,
                  child: const Text('CANCEL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _foodQuantityConfirmation(
    _DatabaseFoodSelection pending,
  ) => KeyedSubtree(
    key: _quantityConfirmationKey,
    child: OperationCard(
      key: const ValueKey('food-db-quantity-confirmation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.fact_check_outlined,
            title: 'CONFIRM QUANTITY',
          ),
          AppSpacing.gapSM,
          Text(
            _pendingName(pending),
            key: const ValueKey('food-db-pending-name'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(_pendingUnit(pending)),
          AppSpacing.gapMD,
          if (pending.value is FoodCatalogEntry) ...[
            FoodNumericStepperRow(
              key: const ValueKey('food-db-used-amount-stepper-row'),
              inputKey: const ValueKey('food-db-pending-used-amount'),
              controller: _pendingUsedAmountController,
              label:
                  'USED AMOUNT (${FoodNutritionFormatter.quantityUnit(_catalogSourceUnit(pending.value as FoodCatalogEntry))})',
              onChanged: (_) => setState(() => inputError = null),
              incrementKey: const ValueKey('food-db-used-amount-increment'),
              incrementTooltip: 'Increase used amount',
              onIncrement: () => _adjustPendingUsedAmount(1),
              decrementKey: const ValueKey('food-db-used-amount-decrement'),
              decrementTooltip: 'Decrease used amount',
              onDecrement: () => _adjustPendingUsedAmount(-1),
            ),
            AppSpacing.gapSM,
          ],
          FoodNumericStepperRow(
            key: const ValueKey('food-db-quantity-stepper-row'),
            inputKey: const ValueKey('food-db-pending-quantity'),
            controller: _pendingQuantityController,
            label: pending.value is FoodCatalogEntry ? 'QUANTITY' : 'Quantity',
            onChanged: (_) => setState(() => inputError = null),
            incrementKey: const ValueKey('food-db-quantity-increment'),
            incrementTooltip: 'Increase quantity',
            onIncrement: () => _adjustPendingQuantity(1),
            decrementKey: const ValueKey('food-db-quantity-decrement'),
            decrementTooltip: 'Decrease quantity',
            onDecrement: () => _adjustPendingQuantity(-1),
          ),
          if (pending.value is FoodCatalogEntry) ...[
            AppSpacing.gapXS,
            Builder(
              builder: (context) {
                final entry = pending.value as FoodCatalogEntry;
                final used = _FoodNumericTextValue.parse(
                  _pendingUsedAmountController.text,
                ).value;
                final quantity = _FoodNumericTextValue.parse(
                  _pendingQuantityController.text,
                ).value;
                final unit = FoodNutritionFormatter.quantityUnit(
                  _catalogSourceUnit(entry),
                );
                final total = used == null || quantity == null
                    ? null
                    : FoodMealUsage.totalUsedUnits(
                        usedAmount: used,
                        quantity: quantity,
                      );
                final preview = total == null
                    ? null
                    : _databaseFoodItem(
                        entry,
                        usedAmount: total,
                        basisQuantity: _catalogSourceBaseAmount(entry),
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BASIS ${_formatAmount(_catalogSourceBaseAmount(entry))}$unit\n'
                      'USED ${used == null ? '—' : _formatAmount(used)}$unit × '
                      'QUANTITY ${quantity == null ? '—' : _formatAmount(quantity)}\n'
                      '= TOTAL ${total == null ? '—' : _formatAmount(total)}$unit',
                      key: const ValueKey('food-db-usage-summary'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      preview == null
                          ? '— kcal  P —  F —  C —'
                          : '${FoodNutritionFormatter.calories(preview.totalCalories)}kcal'
                                '  P ${FoodNutritionFormatter.macro(preview.totalProtein)}g'
                                '  F ${FoodNutritionFormatter.macro(preview.totalFat)}g'
                                '  C ${FoodNutritionFormatter.macro(preview.totalCarbohydrate)}g',
                      key: const ValueKey('food-db-usage-nutrition-preview'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
          AppSpacing.gapMD,
          Row(
            children: [
              Expanded(
                child: OperationButton(
                  key: const ValueKey('food-db-add'),
                  icon: Icons.add,
                  text: 'ADD',
                  onPressed: _isSaving ? null : _addPendingDatabaseSelection,
                ),
              ),
              AppSpacing.gapSM,
              OutlinedButton(
                key: const ValueKey('food-db-cancel'),
                onPressed: _isSaving ? null : _cancelPendingDatabaseSelection,
                child: const Text('CANCEL'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _mealItemEditor() {
    final index = _mealItemEditingIndex!;
    final item = items[index];
    final recipe = _recipeSources[index];
    final catalog = _catalogSources[index];
    final editable = recipe != null || item.hasMeasuredAmount;
    final isRecipe = recipe != null;
    final unit = isRecipe ? FoodQuantityUnit.serving : _sourceUnit(index);
    final usedAmount = _FoodNumericTextValue.parse(
      _mealItemUsedAmountController.text,
    ).value;
    final quantity = _FoodNumericTextValue.parse(
      _mealItemQuantityController.text,
    ).value;
    final candidate = editable ? _editedMealItem() : null;
    return OperationCard(
      key: const ValueKey('food-meal-item-editor'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.edit_outlined,
            title: 'EDIT MEAL ITEM',
          ),
          AppSpacing.gapSM,
          Text(item.name, style: Theme.of(context).textTheme.titleMedium),
          Text(
            isRecipe
                ? 'RECIPE'
                : catalog == null
                ? 'MANUAL'
                : 'FOOD',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AppSpacing.gapMD,
          if (!editable)
            Text(
              _mealItemEditError ??
                  'THIS ITEM DOES NOT RETAIN A SAFE EDITABLE AMOUNT.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (isRecipe) ...[
            FoodNumericStepperRow(
              key: const ValueKey('meal-item-serving-stepper'),
              inputKey: const ValueKey('meal-item-serving-input'),
              controller: _mealItemQuantityController,
              label: 'SERVINGS',
              onChanged: _changeMealItemQuantity,
              incrementKey: const ValueKey('meal-item-serving-increment'),
              incrementTooltip: 'Increase servings',
              onIncrement: () =>
                  _adjustMealItemValue(usedAmount: false, delta: 1),
              decrementKey: const ValueKey('meal-item-serving-decrement'),
              decrementTooltip: 'Decrease servings',
              onDecrement: () =>
                  _adjustMealItemValue(usedAmount: false, delta: -1),
            ),
          ] else ...[
            FoodNumericStepperRow(
              key: const ValueKey('meal-item-used-amount-stepper'),
              inputKey: const ValueKey('meal-item-used-amount-input'),
              controller: _mealItemUsedAmountController,
              label:
                  'USED AMOUNT (${FoodNutritionFormatter.quantityUnit(unit)})',
              onChanged: _changeMealItemUsedAmount,
              incrementKey: const ValueKey('meal-item-used-amount-increment'),
              incrementTooltip: 'Increase used amount',
              onIncrement: () =>
                  _adjustMealItemValue(usedAmount: true, delta: 1),
              decrementKey: const ValueKey('meal-item-used-amount-decrement'),
              decrementTooltip: 'Decrease used amount',
              onDecrement: () =>
                  _adjustMealItemValue(usedAmount: true, delta: -1),
            ),
            AppSpacing.gapSM,
            FoodNumericStepperRow(
              key: const ValueKey('meal-item-quantity-stepper'),
              inputKey: const ValueKey('meal-item-quantity-input'),
              controller: _mealItemQuantityController,
              label: 'QUANTITY',
              onChanged: _changeMealItemQuantity,
              incrementKey: const ValueKey('meal-item-quantity-increment'),
              incrementTooltip: 'Increase quantity',
              onIncrement: () =>
                  _adjustMealItemValue(usedAmount: false, delta: 1),
              decrementKey: const ValueKey('meal-item-quantity-decrement'),
              decrementTooltip: 'Decrease quantity',
              onDecrement: () =>
                  _adjustMealItemValue(usedAmount: false, delta: -1),
            ),
            AppSpacing.gapXS,
            Text(
              _quantitySemantics[index] ==
                      FoodMealQuantitySemantics.multiplicativeV21
                  ? 'BASIS ${_formatAmount(item.baseAmount!)}${FoodNutritionFormatter.quantityUnit(unit)}\n'
                        'USED ${usedAmount == null ? '—' : _formatAmount(usedAmount)}${FoodNutritionFormatter.quantityUnit(unit)} × '
                        'QUANTITY ${quantity == null ? '—' : _formatAmount(quantity)}\n'
                        '= TOTAL ${usedAmount == null || quantity == null ? '—' : _formatAmount(FoodMealUsage.totalUsedUnits(usedAmount: usedAmount, quantity: quantity))}${FoodNutritionFormatter.quantityUnit(unit)}'
                  : 'LEGACY USED ${usedAmount == null ? '—' : _formatAmount(usedAmount)}${FoodNutritionFormatter.quantityUnit(unit)} / '
                        'QUANTITY ${quantity == null ? '—' : _formatAmount(quantity)}${FoodNutritionFormatter.quantityUnit(unit)}',
              key: const ValueKey('meal-item-edit-basis'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_mealItemEditError != null && editable) ...[
            AppSpacing.gapSM,
            Text(
              _mealItemEditError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (editable) ...[
            AppSpacing.gapSM,
            Text(
              candidate == null
                  ? '— kcal  P —  F —  C —'
                  : '${FoodNutritionFormatter.calories(candidate.totalCalories)}kcal'
                        '  P ${FoodNutritionFormatter.macro(candidate.totalProtein)}g'
                        '  F ${FoodNutritionFormatter.macro(candidate.totalFat)}g'
                        '  C ${FoodNutritionFormatter.macro(candidate.totalCarbohydrate)}g',
              key: const ValueKey('meal-item-edit-nutrition-preview'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          AppSpacing.gapMD,
          Row(
            children: [
              Expanded(
                child: OperationButton(
                  key: const ValueKey('meal-item-edit-save'),
                  icon: Icons.check,
                  text: 'SAVE',
                  onPressed: editable ? _saveMealItemEdit : null,
                ),
              ),
              AppSpacing.gapSM,
              OutlinedButton(
                key: const ValueKey('meal-item-edit-cancel'),
                onPressed: () => setState(_cancelMealItemEdit),
                child: const Text('CANCEL'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = previewItems;
    final previewCatalogSources = List<FoodCatalogEntry?>.from(_catalogSources);
    final previewRecipeSources = List<FoodRecipeDefinition?>.from(
      _recipeSources,
    );
    if (_currentFoodItem() != null) {
      previewCatalogSources.add(_currentCatalogSource);
      previewRecipeSources.add(_currentRecipeSource);
    }

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

          _entryAndMealTypeControls(),

          AppSpacing.gapXL,

          if (isWaterEntry) ...[
            const SectionHeader(
              icon: Icons.water_drop_outlined,
              title: 'Water Entry',
            ),

            AppSpacing.gapMD,

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WaterQuickPresets.valuesMl
                  .map(
                    (amount) => OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _addWaterAmount(amount),
                      child: Text('+$amount ml'),
                    ),
                  )
                  .toList(),
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
              onPressed: _isSaving ? null : saveMeal,
            ),
          ] else ...[
            AppSpacing.gapMD,
            GestureDetector(
              key: const ValueKey('food-entry-input-mode-page-surface'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _canSwitchInputMode
                  ? (details) => _swipeInputMode(details.primaryVelocity ?? 0)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _inputModeTabs(),
                  AppSpacing.gapMD,
                  if (_inputMode == _FoodEntryInputMode.manual) ...[
                    const SectionHeader(
                      icon: Icons.restaurant_menu,
                      title: 'ADD FOOD ITEM',
                    ),
                    AppSpacing.gapMD,
                    FoodInputFields(
                      foodNameController: foodNameController,
                      brandController: brandController,
                      barcodeController: barcodeController,
                      packageQuantityController: packageQuantityController,
                      calorieController: calorieController,
                      proteinController: proteinController,
                      fatController: fatController,
                      carbohydrateController: carbohydrateController,
                      baseAmountController: baseAmountController,
                      amountController: amountController,
                      foodMemoController: foodMemoController,
                      category: category,
                      packageUnit: packageUnit,
                      baseUnit: baseUnit,
                      recipeSelected: _currentRecipeSource != null,
                      onBaseAmountChanged: _onBaseAmountChanged,
                      onCategoryChanged: (value) => setState(() {
                        category = value;
                        inputError = null;
                      }),
                      onPackageQuantityChanged: _onPackageQuantityChanged,
                      onPackageUnitChanged: _onPackageUnitChanged,
                      onCaloriesChanged: () => _rawCalories = null,
                      onProteinChanged: () => _rawProtein = null,
                      onFatChanged: () => _rawFat = null,
                      onCarbohydrateChanged: () => _rawCarbohydrate = null,
                      onScanBarcode: _isSaving || _capturingBarcode
                          ? null
                          : _scanBarcode,
                      barcodeScanInProgress: _capturingBarcode,
                      onReadNutrition: _isSaving || _capturingNutrition
                          ? null
                          : _scanOcr,
                      nutritionCaptureInProgress: _capturingNutrition,
                      onRecalculateNutrition: _recalculateNutrition,
                      recalculationBlockReason: _recalculationBlockReason,
                      onChanged: (_) {
                        setState(() {
                          inputError = null;
                        });
                      },
                      onBaseUnitChanged: (unit) {
                        setState(() {
                          baseUnit = unit;
                          _basisLinkedToPackage = false;
                          inputError = null;
                        });
                      },
                    ),

                    if (_currentCatalogSource != null) ...[
                      AppSpacing.gapSM,
                      Text(
                        'CATALOG · ${_currentCatalogSource!.name} · '
                        '${_formatAmount(_currentCatalogSource!.baseQuantity.value)} '
                        '${_currentCatalogSource!.baseQuantity.unit.stableId}',
                        key: const ValueKey('food-catalog-selection'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    if (_currentRecipeSource != null) ...[
                      AppSpacing.gapSM,
                      Text(
                        'RECIPE · ${_currentRecipeSource!.name}',
                        key: const ValueKey('food-recipe-selection'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    AppSpacing.gapMD,

                    if (!_hasActiveCatalogReference)
                      OperationButton(
                        key: const ValueKey('food-save-to-catalog'),
                        icon: Icons.add_business,
                        text: 'SAVE TO DATABASE',
                        onPressed: _isSaving ? null : _saveCurrentToCatalog,
                      ),
                  ] else
                    _databaseInput(),

                  if (inputError != null) ...[
                    AppSpacing.gapMD,
                    Text(
                      inputError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  AppSpacing.gapXL,

                  if (_inputMode == _FoodEntryInputMode.manual ||
                      items.isNotEmpty)
                    FoodItemList(
                      items: preview,
                      catalogSources: previewCatalogSources,
                      recipeSources: previewRecipeSources,
                      quantityUnits: [
                        ..._quantityUnits,
                        if (_currentFoodItem() != null) baseUnit,
                      ],
                      onDelete: (index) {
                        if (index < items.length &&
                            _mealItemEditingIndex == null) {
                          removeFood(index);
                        }
                      },
                      onTap: (index) {
                        if (index < items.length &&
                            _mealItemEditingIndex == null) {
                          _openMealItemEditor(index);
                        }
                      },
                      onQuantityChanged: updateQuantity,
                      editableItemCount: items.length,
                      actionIcon: Icons.add_circle_outline,
                      actionText: 'ADD FOOD',
                      onAction: addFood,
                      showPrimaryAction:
                          _inputMode == _FoodEntryInputMode.manual,
                    ),

                  if (_mealItemEditingIndex != null) ...[
                    AppSpacing.gapMD,
                    _mealItemEditor(),
                  ],

                  if (preview.isNotEmpty) ...[
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
                      text: widget.initialMeal == null
                          ? 'SAVE MEAL'
                          : 'UPDATE MEAL',
                      onPressed: _isSaving ? null : saveMeal,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value
        .toStringAsFixed(12)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _clearRawNutrition() {
    _rawCalories = null;
    _rawProtein = null;
    _rawFat = null;
    _rawCarbohydrate = null;
  }
}

String? _nullableText(String source) {
  final value = source.trim();
  return value.isEmpty ? null : value;
}

double? _optionalPositiveNumber(TextEditingController controller) {
  final source = controller.text.trim();
  if (source.isEmpty) return null;
  final value = double.tryParse(source);
  return value != null && value.isFinite && value > 0 ? value : null;
}
