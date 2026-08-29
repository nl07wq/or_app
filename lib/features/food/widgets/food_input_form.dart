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

import '../data/beta_meal_templates.dart';
import '../data/water_quick_presets.dart';
import '../food_nutrition_formatter.dart';
import '../models/meal_template.dart';
import '../models/food_catalog_models.dart';
import '../models/food_quantity_models.dart';
import '../models/nutrition_models.dart';
import '../food_catalog_page.dart';
import '../../repositories/app_repository_container.dart';
import '../services/beta_meal_template_resolver.dart';
import '../services/food_input_capture_gateway.dart';
import '../services/food_live_capture_presenter.dart';
import '../services/japanese_nutrition_ocr_parser.dart';
import 'food_input_fields.dart';
import 'food_item_list.dart';
import 'food_total_card.dart';

class FoodInputForm extends StatefulWidget {
  final Future<bool> Function(MealData data) onSave;
  final Future<bool> Function(
    MealData data,
    List<FoodCatalogEntry?> catalogSources,
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
  FoodCatalogEntry? _currentCatalogSource;
  FoodCatalogCategory category = FoodCatalogCategory.preparedFood;
  FoodQuantityUnit? packageUnit;

  int? editingIndex;
  bool isWaterEntry = false;
  String? selectedTemplateId;
  String? inputError;
  FoodBaseUnit baseUnit = FoodBaseUnit.g;
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
        baseUnit: preservesLegacy ? null : baseUnit,
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
    baseUnit = FoodBaseUnit.g;
    category = FoodCatalogCategory.preparedFood;
    packageUnit = null;
    _basisLinkedToPackage = true;
    _setDefaultMeasurementInputs();
    inputError = null;
    _currentCatalogSource = null;
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
    if (!_basisLinkedToPackage || packageUnit?.isPhysical != true) return;
    baseAmountController.text = source;
    _updateBaseAmount(source);
  }

  void _onPackageUnitChanged(FoodQuantityUnit? unit) {
    setState(() {
      packageUnit = unit;
      inputError = null;
    });
    if (!_basisLinkedToPackage || unit?.isPhysical != true) return;
    baseUnit = unit == FoodQuantityUnit.gram ? FoodBaseUnit.g : FoodBaseUnit.ml;
    final source = packageQuantityController.text;
    baseAmountController.text = source;
    _updateBaseAmount(source);
  }

  void _clearForm() {
    setState(() {
      items.clear();
      _catalogSources.clear();
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
      inputError = null;
      _clearFoodInputs();
    });
  }

  void removeFood(int index) {
    setState(() {
      items.removeAt(index);
      _catalogSources.removeAt(index);

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

    setState(() {
      editingIndex = index;
      _currentCatalogSource = source;
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
      baseUnit = item.baseUnit ?? FoodBaseUnit.g;
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

  void _applyTemplate(MealTemplate template) {
    final resolution = BetaMealTemplateResolver.resolve(template);

    setState(() {
      isWaterEntry = false;
      mealType = switch (template.mealType) {
        MealTemplateMealType.breakfast => MealType.breakfast,
        MealTemplateMealType.lunch => MealType.lunch,
        MealTemplateMealType.dinner => MealType.dinner,
      };
      selectedTemplateId = template.id;
      inputError = null;
      items
        ..clear()
        ..addAll(resolution.items);
      _catalogSources
        ..clear()
        ..addAll(List.filled(resolution.items.length, null));
      editingIndex = null;
      _clearFoodInputs();
    });

    if (resolution.skippedEntryCount > 0 && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('一部のテンプレート項目を反映できませんでした。')));
    }
  }

  Future<FoodNutritionCaptureMode?> _chooseNutritionCaptureMode() =>
      showModalBottomSheet<FoodNutritionCaptureMode>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.center_focus_strong),
                title: const Text('LIVE SCAN'),
                onTap: () =>
                    Navigator.pop(context, FoodNutritionCaptureMode.live),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('CAMERA'),
                onTap: () =>
                    Navigator.pop(context, FoodNutritionCaptureMode.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('PHOTO LIBRARY'),
                onTap: () =>
                    Navigator.pop(context, FoodNutritionCaptureMode.gallery),
              ),
            ],
          ),
        ),
      );

  Future<void> _readNutritionLabel() async {
    final mode = await _chooseNutritionCaptureMode();
    if (mode == null || !mounted) return;
    setState(() {
      _capturingNutrition = true;
      inputError = null;
    });
    try {
      final rawText = switch (mode) {
        FoodNutritionCaptureMode.live =>
          _captureGateway is FoodLiveCaptureGateway
              ? await (_captureGateway as FoodLiveCaptureGateway)
                    .recognizeNutritionLive(describeNutritionCandidate)
              : throw UnsupportedError('Live nutrition capture unavailable.'),
        FoodNutritionCaptureMode.camera ||
        FoodNutritionCaptureMode.gallery => await _recognizeSelectedImage(
          mode == FoodNutritionCaptureMode.camera
              ? FoodImageSource.camera
              : FoodImageSource.gallery,
        ),
      };
      if (rawText == null) return;
      final draft = const JapaneseNutritionOcrParser().parse(rawText);
      if (!mounted) return;
      if (draft.isEmpty) {
        setState(() => inputError = 'NUTRITION VALUES COULD NOT BE READ');
        return;
      }
      final apply = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('OCR PREVIEW'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ocrPreviewValue(
                  'NUTRITION BASIS',
                  draft.basisQuantity,
                  draft.basisUnit,
                ),
                _ocrPreviewValue(
                  'CALORIES',
                  draft.calories,
                  null,
                  suffix: 'kcal',
                  calories: true,
                ),
                _ocrPreviewValue('PROTEIN', draft.protein, null, suffix: 'g'),
                _ocrPreviewValue('FAT', draft.fat, null, suffix: 'g'),
                _ocrPreviewValue(
                  'CARBOHYDRATE',
                  draft.carbohydrate,
                  null,
                  suffix: 'g',
                ),
                _ocrPreviewValue(
                  'PACKAGE',
                  draft.packageQuantity,
                  draft.packageUnit,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('APPLY TO FORM'),
            ),
          ],
        ),
      );
      if (apply == true && mounted) _applyNutritionOcr(draft);
    } catch (_) {
      if (mounted) setState(() => inputError = 'OCR PROCESSING FAILED');
    } finally {
      if (mounted) setState(() => _capturingNutrition = false);
    }
  }

  Future<String?> _recognizeSelectedImage(FoodImageSource source) async {
    final image = await _captureGateway.selectImage(source);
    if (image == null) return null;
    return _captureGateway.recognizeJapaneseText(image);
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
        setState(() => inputError = 'BARCODE COULD NOT BE READ');
        return;
      }
      setState(() {
        barcodeController.text = value!;
        inputError = null;
      });
    } catch (_) {
      if (mounted) setState(() => inputError = 'BARCODE SCAN FAILED');
    } finally {
      if (mounted) setState(() => _capturingBarcode = false);
    }
  }

  Widget _ocrPreviewValue(
    String label,
    double? value,
    FoodQuantityUnit? unit, {
    String suffix = '',
    bool calories = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Text(
      '$label  ${value == null ? 'NEEDS REVIEW' : '${calories ? FoodNutritionFormatter.calories(value) : FoodNutritionFormatter.macro(value)}${unit == null ? suffix : _quantityUnitLabel(unit)}'}',
    ),
  );

  void _applyNutritionOcr(NutritionOcrDraft draft) {
    setState(() {
      if (draft.packageQuantity != null && draft.packageUnit != null) {
        packageQuantityController.text = _formatAmount(draft.packageQuantity!);
        packageUnit = draft.packageUnit;
      }
      if (draft.basisQuantity != null && draft.basisUnit != null) {
        baseAmountController.text = _formatAmount(draft.basisQuantity!);
        baseUnit = draft.basisUnit == FoodQuantityUnit.gram
            ? FoodBaseUnit.g
            : FoodBaseUnit.ml;
        _lastValidBaseAmount = draft.basisQuantity;
        _basisLinkedToPackage = false;
      } else if (_basisLinkedToPackage && packageUnit?.isPhysical == true) {
        final source = packageQuantityController.text;
        baseAmountController.text = source;
        baseUnit = packageUnit == FoodQuantityUnit.gram
            ? FoodBaseUnit.g
            : FoodBaseUnit.ml;
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

  Future<void> _selectCatalogFood() async {
    if (!AppRepositoryRegistry.hasContainer) return;
    final entry = await Navigator.push<FoodCatalogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogPage(
          repository: AppRepositoryRegistry.container.foodCatalog,
          selectionMode: true,
        ),
      ),
    );
    if (entry == null || !mounted) return;
    final nutrition = entry.nutrition;
    setState(() {
      _currentCatalogSource = entry;
      _setMasterFields(entry);
      _setRawNutrition(
        calories: nutrition.calories,
        protein: nutrition.protein,
        fat: nutrition.fat,
        carbohydrate: nutrition.carbohydrate,
      );
      final quantity = entry.baseQuantity;
      if (quantity.unit.isPhysical) {
        baseAmountController.text = _formatAmount(quantity.value);
        baseUnit = quantity.unit == FoodQuantityUnit.gram
            ? FoodBaseUnit.g
            : FoodBaseUnit.ml;
        _lastValidBaseAmount = quantity.value;
      } else {
        baseAmountController.text = '1';
        amountController.text = '1';
        _lastValidBaseAmount = 1;
      }
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
              unit: item.baseUnit == FoodBaseUnit.ml
                  ? FoodQuantityUnit.milliliter
                  : FoodQuantityUnit.gram,
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
    if (editingIndex == null && _currentFoodItem() != null) {
      sources.add(_currentCatalogSource);
    }
    final saved =
        sources.any((entry) => entry != null) &&
            widget.onSaveWithCatalog != null
        ? await widget.onSaveWithCatalog!(meal, sources)
        : await widget.onSave(meal);

    if (!mounted) return;

    setState(() => _isSaving = false);
    if (!saved) return;
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
                      selectedTemplateId = null;
                    });
                  },
                );
              }).toList(),
            ),

            AppSpacing.gapXL,

            OperationButton(
              key: const ValueKey('food-catalog-select'),
              icon: Icons.storage_outlined,
              text: 'SELECT FROM FOOD DATABASE',
              onPressed: _isSaving ? null : _selectCatalogFood,
            ),

            AppSpacing.gapMD,

            OperationButton(
              key: const ValueKey('food-entry-ocr'),
              icon: Icons.document_scanner,
              text: _capturingNutrition
                  ? 'PROCESSING IMAGE'
                  : 'READ NUTRITION LABEL',
              onPressed: _isSaving || _capturingNutrition
                  ? null
                  : _readNutritionLabel,
            ),

            AppSpacing.gapMD,

            if (widget.initialMeal == null) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Meal Template',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              AppSpacing.gapMD,

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: betaMealTemplates.map((template) {
                  return ChoiceChip(
                    label: Text(template.name),
                    selected: selectedTemplateId == template.id,
                    onSelected: (_) => _applyTemplate(template),
                  );
                }).toList(),
              ),

              AppSpacing.gapXL,
            ],

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
              onChanged: (_) {
                setState(() {
                  inputError = null;
                });
              },
              onBaseUnitChanged: (unit) {
                setState(() {
                  baseUnit = unit;
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

String _quantityUnitLabel(FoodQuantityUnit unit) => switch (unit) {
  FoodQuantityUnit.gram => 'g',
  FoodQuantityUnit.milliliter => 'mL',
  FoodQuantityUnit.piece => 'piece',
  FoodQuantityUnit.pack => 'pack',
  FoodQuantityUnit.serving => 'serving',
};
