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
import '../models/food_meal_master_models.dart';
import '../models/food_quantity_models.dart';
import '../models/nutrition_models.dart';
import '../models/recipe_models_v2.dart';
import '../food_catalog_page.dart';
import '../../repositories/app_repository_container.dart';
import '../services/food_input_capture_gateway.dart';
import '../services/food_recipe_nutrition.dart';
import '../services/food_meal_master_expander.dart';
import '../services/japanese_nutrition_ocr_parser.dart';
import '../services/japanese_package_ocr_parser.dart';
import 'food_input_fields.dart';
import 'food_item_list.dart';
import 'food_ocr_scanner.dart';
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
  final MealData? initialMeal;
  final FoodInputCaptureGateway? captureGateway;

  const FoodInputForm({
    super.key,
    required this.onSave,
    this.onSaveWithCatalog,
    this.initialMeal,
    this.captureGateway,
  });

  @override
  State<FoodInputForm> createState() => _FoodInputFormState();
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

  MealType mealType = MealType.breakfast;

  final List<FoodItem> items = [];
  final List<FoodCatalogEntry?> _catalogSources = [];
  final List<FoodRecipeDefinition?> _recipeSources = [];
  final List<FoodQuantityUnit> _quantityUnits = [];
  FoodCatalogEntry? _currentCatalogSource;
  FoodRecipeDefinition? _currentRecipeSource;
  FoodCatalogCategory category = FoodCatalogCategory.preparedFood;
  FoodQuantityUnit? packageUnit;

  int? editingIndex;
  bool isWaterEntry = false;
  String? inputError;
  FoodQuantityUnit baseUnit = FoodQuantityUnit.gram;
  double? _lastValidBaseAmount = _defaultBaseAmount;
  double? _rawCalories;
  double? _rawProtein;
  double? _rawFat;
  double? _rawCarbohydrate;
  bool _isSaving = false;
  bool _capturingNutrition = false;
  bool _capturingBarcode = false;
  bool _basisLinkedToPackage = true;

  FoodInputCaptureGateway get _captureGateway =>
      widget.captureGateway ?? createFoodInputCaptureGateway();

  FoodAmountMode get _inputAmountMode {
    final index = editingIndex;
    if (index != null && items[index].hasMeasuredAmount) {
      return items[index].effectiveAmountMode;
    }
    return FoodAmountMode.baseMultiplier;
  }

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
    _catalogSources.addAll(List.filled(meal.items.length, null));
    _recipeSources.addAll(List.filled(meal.items.length, null));
    _quantityUnits.addAll(
      meal.items.map(
        (item) => item.baseUnit == FoodBaseUnit.ml
            ? FoodQuantityUnit.milliliter
            : FoodQuantityUnit.gram,
      ),
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
    super.dispose();
  }

  FoodItem? _currentFoodItem({int quantity = 1}) {
    final name = foodNameController.text.trim();

    if (name.isEmpty) {
      return null;
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
    final editingItem = editingIndex == null ? null : items[editingIndex!];
    final preservesLegacy =
        editingItem != null &&
        !editingItem.hasMeasuredAmount &&
        baseAmountController.text.trim().isEmpty &&
        amountController.text.trim().isEmpty;
    if (!preservesLegacy &&
        (baseAmount == null ||
            !baseAmount.isFinite ||
            baseAmount <= 0 ||
            amount == null ||
            !amount.isFinite ||
            amount <= 0)) {
      return null;
    }

    try {
      final amountMode = editingItem != null && editingItem.hasMeasuredAmount
          ? editingItem.amountMode
          : FoodAmountMode.baseMultiplier;
      return FoodItem(
        name: name,
        calories: calories!,
        protein: protein!,
        fat: fat!,
        carbohydrate: carbohydrate!,
        quantity: quantity,
        amount: preservesLegacy ? null : amount,
        baseAmount: preservesLegacy ? null : baseAmount,
        baseUnit: preservesLegacy
            ? null
            : baseUnit == FoodQuantityUnit.milliliter
            ? FoodBaseUnit.ml
            : FoodBaseUnit.g,
        amountMode: preservesLegacy ? null : amountMode,
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
    _lastValidBaseAmount = _defaultBaseAmount;
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

      final previousBaseAmount = _lastValidBaseAmount;
      if (previousBaseAmount != null &&
          previousBaseAmount.isFinite &&
          previousBaseAmount > 0 &&
          previousBaseAmount != nextBaseAmount) {
        final multiplier = nextBaseAmount / previousBaseAmount;
        _rawCalories = _rescaleNutrition(
          controller: calorieController,
          rawValue: _rawCalories,
          multiplier: multiplier,
          formatter: FoodNutritionFormatter.calories,
        );
        _rawProtein = _rescaleNutrition(
          controller: proteinController,
          rawValue: _rawProtein,
          multiplier: multiplier,
          formatter: FoodNutritionFormatter.macro,
        );
        _rawFat = _rescaleNutrition(
          controller: fatController,
          rawValue: _rawFat,
          multiplier: multiplier,
          formatter: FoodNutritionFormatter.macro,
        );
        _rawCarbohydrate = _rescaleNutrition(
          controller: carbohydrateController,
          rawValue: _rawCarbohydrate,
          multiplier: multiplier,
          formatter: FoodNutritionFormatter.macro,
        );
      }
      _lastValidBaseAmount = nextBaseAmount;
    });
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
      _quantityUnits.clear();
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
      _quantityUnits.add(baseUnit);
      inputError = null;
      _clearFoodInputs();
    });
  }

  void removeFood(int index) {
    setState(() {
      items.removeAt(index);
      _catalogSources.removeAt(index);
      _recipeSources.removeAt(index);
      _quantityUnits.removeAt(index);

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
    final source = _catalogSources[index];
    final recipe = _recipeSources[index];

    setState(() {
      editingIndex = index;
      _currentCatalogSource = source;
      _currentRecipeSource = recipe;
      if (source != null) {
        _setMasterFields(source);
      } else {
        brandController.clear();
        barcodeController.clear();
        packageQuantityController.clear();
        foodMemoController.clear();
        category = FoodCatalogCategory.preparedFood;
        packageUnit = null;
        _basisLinkedToPackage = false;
      }

      foodNameController.text = item.name;
      _setRawNutrition(
        calories: item.calories.toDouble(),
        protein: item.protein,
        fat: item.fat,
        carbohydrate: item.carbohydrate,
      );
      baseAmountController.text = item.baseAmount == null
          ? ''
          : _formatAmount(item.baseAmount!);
      amountController.text = item.amount == null
          ? ''
          : _formatAmount(item.amount!);
      baseUnit = recipe != null
          ? FoodQuantityUnit.serving
          : source?.baseQuantity.unit ?? _quantityUnits[index];
      _lastValidBaseAmount = item.baseAmount;
      inputError = null;
    });
  }

  void updateFood() {
    if (editingIndex == null) return;

    final item = _currentFoodItem(quantity: items[editingIndex!].quantity);

    if (item == null) {
      setState(() {
        inputError =
            'Enter valid food, base amount, quantity, and nutrition values.';
      });
      return;
    }

    setState(() {
      items[editingIndex!] = item;
      _catalogSources[editingIndex!] = _currentCatalogSource;
      _recipeSources[editingIndex!] = _currentRecipeSource;
      _quantityUnits[editingIndex!] = baseUnit;

      editingIndex = null;
      inputError = null;

      _clearFoodInputs();
    });
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
      _capturingNutrition = true;
      inputError = null;
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
        _lastValidBaseAmount = draft.basisQuantity;
        _basisLinkedToPackage = false;
      } else if (_basisLinkedToPackage && packageUnit != null) {
        final source = packageUnit!.isPhysical
            ? packageQuantityController.text
            : '1';
        baseAmountController.text = source;
        baseUnit = packageUnit!;
        _lastValidBaseAmount = double.tryParse(source);
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
          _lastValidBaseAmount = draft.packageUnit!.isPhysical
              ? draft.packageQuantity
              : 1;
        }
      }
      inputError = null;
    });
  }

  Future<void> _selectCatalogFood() async {
    if (!AppRepositoryRegistry.hasContainer) return;
    final selection = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogPage(
          repository: AppRepositoryRegistry.container.foodCatalog,
          selectionMode: true,
        ),
      ),
    );
    if (selection == null || !mounted) return;
    if (selection case final FoodMealMaster meal) {
      try {
        final expansion = await FoodMealMasterExpander(
          foods: AppRepositoryRegistry.container.foodCatalog,
          recipes: AppRepositoryRegistry.container.foodRecipes,
        ).expand(meal);
        if (!mounted) return;
        setState(() {
          items.addAll(expansion.items);
          _catalogSources.addAll(expansion.foodSources);
          _recipeSources.addAll(expansion.recipeSources);
          _quantityUnits.addAll(expansion.quantityUnits);
          inputError = null;
        });
      } on FoodMealMasterExpansionException catch (error) {
        if (mounted) setState(() => inputError = error.toString());
      }
      return;
    }
    if (selection case final FoodRecipeDefinition recipe) {
      final nutrition = FoodRecipeNutrition.perServing(recipe);
      if ([
        nutrition.calories,
        nutrition.protein,
        nutrition.fat,
        nutrition.carbohydrate,
      ].any((value) => value == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RECIPE NUTRITION IS INCOMPLETE')),
        );
        return;
      }
      setState(() {
        _currentCatalogSource = null;
        _currentRecipeSource = recipe;
        foodNameController.text = recipe.name;
        brandController.clear();
        barcodeController.clear();
        packageQuantityController.clear();
        foodMemoController.text = recipe.memo ?? '';
        packageUnit = null;
        _setRawNutrition(
          calories: nutrition.calories,
          protein: nutrition.protein,
          fat: nutrition.fat,
          carbohydrate: nutrition.carbohydrate,
        );
        baseAmountController.text = '1';
        amountController.text = '1';
        baseUnit = FoodQuantityUnit.serving;
        _lastValidBaseAmount = 1;
        _basisLinkedToPackage = false;
        inputError = null;
      });
      return;
    }
    final entry = selection as FoodCatalogEntry;
    final nutrition = entry.nutrition;
    setState(() {
      _currentCatalogSource = entry;
      _currentRecipeSource = null;
      _setMasterFields(entry);
      _setRawNutrition(
        calories: nutrition.calories,
        protein: nutrition.protein,
        fat: nutrition.fat,
        carbohydrate: nutrition.carbohydrate,
      );
      final quantity = entry.baseQuantity;
      baseAmountController.text = _formatAmount(quantity.value);
      baseUnit = quantity.unit;
      amountController.text = '1';
      _lastValidBaseAmount = quantity.value;
      _basisLinkedToPackage = false;
      inputError = null;
    });
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
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogEditorPage(
          repository: AppRepositoryRegistry.container.foodCatalog,
          initialEntry: _currentCatalogSource,
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
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SAVED TO FOOD DATABASE')));
    }
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
    final quantityUnits = List<FoodQuantityUnit>.from(_quantityUnits);
    if (editingIndex == null && _currentFoodItem() != null) {
      sources.add(_currentCatalogSource);
      recipeSources.add(_currentRecipeSource);
      quantityUnits.add(baseUnit);
    }
    final saved =
        (sources.any((entry) => entry != null) ||
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

  Widget _entryTypeControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Entry Type', style: TextStyle(fontWeight: FontWeight.bold)),
      AppSpacing.gapSM,
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
    ],
  );

  Widget _mealTypeControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Meal Type',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isWaterEntry
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
      AppSpacing.gapSM,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: MealType.values.map((type) {
          return ChoiceChip(
            avatar: Icon(type.icon, size: 18),
            label: Text(type.label),
            selected: !isWaterEntry && mealType == type,
            onSelected: isWaterEntry
                ? null
                : (_) => setState(() => mealType = type),
          );
        }).toList(),
      ),
    ],
  );

  Widget _entryAndMealTypeControls() => LayoutBuilder(
    builder: (context, constraints) {
      final useTwoColumns = MediaQuery.sizeOf(context).width >= 390;
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

  @override
  Widget build(BuildContext context) {
    final preview = editingIndex == null ? previewItems : items;
    final previewCatalogSources = List<FoodCatalogEntry?>.from(_catalogSources);
    final previewRecipeSources = List<FoodRecipeDefinition?>.from(
      _recipeSources,
    );
    if (editingIndex == null && _currentFoodItem() != null) {
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
            OperationButton(
              key: const ValueKey('food-catalog-select'),
              icon: Icons.storage_outlined,
              text: 'SELECT FROM FOOD DATABASE',
              onPressed: _isSaving ? null : _selectCatalogFood,
            ),

            AppSpacing.gapXL,

            const SectionHeader(
              icon: Icons.restaurant_menu,
              title: 'Add Food Item',
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
              amountMode: _inputAmountMode,
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

            OperationButton(
              key: const ValueKey('food-save-to-catalog'),
              icon: Icons.add_business,
              text: 'SAVE TO FOOD DATABASE',
              onPressed: _isSaving ? null : _saveCurrentToCatalog,
            ),

            if (inputError != null) ...[
              AppSpacing.gapMD,
              Text(
                inputError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            AppSpacing.gapLG,

            if (preview.isNotEmpty) ...[
              AppSpacing.gapXL,

              FoodItemList(
                items: preview,
                catalogSources: previewCatalogSources,
                recipeSources: previewRecipeSources,
                quantityUnits: [
                  ..._quantityUnits,
                  if (editingIndex == null && _currentFoodItem() != null)
                    baseUnit,
                ],
                onDelete: (index) {
                  if (index < items.length) {
                    removeFood(index);
                  }
                },
                onTap: (index) {
                  if (index < items.length) {
                    editFood(index);
                  }
                },
                onQuantityChanged: updateQuantity,
                editableItemCount: items.length,
                actionIcon: editingIndex == null
                    ? Icons.add_circle_outline
                    : Icons.edit_outlined,
                actionText: editingIndex == null ? 'ADD FOOD' : 'Update Food',
                onAction: editingIndex == null ? addFood : updateFood,
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
                text: widget.initialMeal == null ? 'SAVE MEAL' : 'UPDATE MEAL',
                onPressed: _isSaving ? null : saveMeal,
              ),
            ],
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

  void _setMasterFields(FoodCatalogEntry entry) {
    foodNameController.text = entry.name;
    brandController.text = entry.brand ?? '';
    barcodeController.text = entry.barcodeValue ?? '';
    packageQuantityController.text = entry.packageQuantity == null
        ? ''
        : _formatAmount(entry.packageQuantity!);
    foodMemoController.text = entry.memo ?? '';
    category = entry.category;
    packageUnit = entry.packageUnit;
  }

  void _setRawNutrition({
    required double? calories,
    required double? protein,
    required double? fat,
    required double? carbohydrate,
  }) {
    _rawCalories = calories;
    _rawProtein = protein;
    _rawFat = fat;
    _rawCarbohydrate = carbohydrate;
    calorieController.text = calories == null
        ? ''
        : FoodNutritionFormatter.calories(calories);
    proteinController.text = protein == null
        ? ''
        : FoodNutritionFormatter.macro(protein);
    fatController.text = fat == null ? '' : FoodNutritionFormatter.macro(fat);
    carbohydrateController.text = carbohydrate == null
        ? ''
        : FoodNutritionFormatter.macro(carbohydrate);
  }

  void _clearRawNutrition() {
    _rawCalories = null;
    _rawProtein = null;
    _rawFat = null;
    _rawCarbohydrate = null;
  }

  static double? _rescaleNutrition({
    required TextEditingController controller,
    required double? rawValue,
    required double multiplier,
    required String Function(num) formatter,
  }) {
    final source = rawValue ?? double.tryParse(controller.text.trim());
    if (source == null || !source.isFinite || source < 0) return null;
    final result = source * multiplier;
    controller.text = formatter(result);
    return result;
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
