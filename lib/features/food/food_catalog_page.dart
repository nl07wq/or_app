import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/state/app_initialization_state.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/section_header.dart';
import '../repositories/app_repository_container.dart';
import 'models/food_catalog_models.dart';
import 'models/food_provenance_models.dart';
import 'models/food_quantity_models.dart';
import 'models/nutrition_models.dart';
import 'food_nutrition_formatter.dart';
import 'repository/food_catalog_repository.dart';
import 'repository/food_meal_id_generator.dart';
import 'services/food_input_capture_gateway.dart';
import 'services/japanese_nutrition_ocr_parser.dart';

class FoodCatalogPage extends StatefulWidget {
  const FoodCatalogPage({
    super.key,
    this.repository,
    this.selectionMode = false,
  });

  final FoodCatalogRepository? repository;
  final bool selectionMode;

  @override
  State<FoodCatalogPage> createState() => _FoodCatalogPageState();
}

class _FoodCatalogPageState extends State<FoodCatalogPage> {
  final _search = TextEditingController();
  List<FoodCatalogEntry> _entries = const [];
  Object? _error;
  bool _loading = true;

  FoodCatalogRepository get _repository =>
      widget.repository ?? AppRepositoryRegistry.container.foodCatalog;

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.selectionMode ? 'SELECT FOOD' : 'FOOD DATABASE'),
    ),
    floatingActionButton:
        widget.selectionMode || appInitializationController.value.isReadOnly
        ? null
        : FloatingActionButton.extended(
            key: const ValueKey('food-catalog-add'),
            onPressed: _openEditor,
            icon: const Icon(Icons.add),
            label: const Text('ADD FOOD'),
          ),
    body: Padding(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          OperationTextField(
            key: const ValueKey('food-catalog-search'),
            controller: _search,
            label: 'SEARCH NAME / BRAND / BARCODE',
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
          onPressed: _load,
        ),
      );
    }
    final entries = _visible;
    if (entries.isEmpty) return const Center(child: Text('NO FOOD FOUND'));
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => AppSpacing.gapSM,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return OperationCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restaurant_menu),
            title: Text(entry.name),
            subtitle: Text(
              [
                if (entry.brand != null) entry.brand!,
                foodCatalogCategoryLabel(entry.category),
                _basis(entry.baseQuantity),
                if (entry.barcodeValue != null) entry.barcodeValue!,
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openEntry(entry),
          ),
        );
      },
    );
  }
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
  final _memo = TextEditingController();
  FoodCatalogCategory _category = FoodCatalogCategory.packagedFood;
  FoodQuantityUnit? _packageUnit;
  FoodQuantityUnit _baseUnit = FoodQuantityUnit.gram;
  bool _saving = false;
  bool _capturing = false;
  bool _basisLinkedToPackage = true;
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
      _basisLinkedToPackage = false;
      _name.text = draft.name;
      _baseQuantity.text = _number(draft.baseQuantity.value);
      _setNutrition(draft.nutrition);
      _brand.text = draft.brand ?? '';
      _barcode.text = draft.barcodeValue ?? '';
      _packageQuantity.text = _number(draft.packageQuantity);
      _memo.text = draft.memo ?? '';
      _category = draft.category;
      _packageUnit = draft.packageUnit;
      _baseUnit = draft.baseQuantity.unit;
    } else if (entry != null) {
      _basisLinkedToPackage = false;
      _name.text = entry.name;
      _brand.text = entry.brand ?? '';
      _barcode.text = entry.barcodeValue ?? '';
      _packageQuantity.text = _number(entry.packageQuantity);
      _baseQuantity.text = _number(entry.baseQuantity.value);
      _setNutrition(entry.nutrition);
      _memo.text = entry.memo ?? '';
      _category = entry.category;
      _packageUnit = entry.packageUnit;
      _baseUnit = entry.baseQuantity.unit;
    } else {
      _baseQuantity.text = '100';
    }
  }

  void _packageQuantityChanged(String value) {
    if (!_basisLinkedToPackage || _packageUnit?.isPhysical != true) return;
    _baseQuantity.text = value;
  }

  void _packageUnitChanged(FoodQuantityUnit? value) {
    setState(() {
      _packageUnit = value;
      if (_basisLinkedToPackage && value?.isPhysical == true) {
        _baseUnit = value!;
        _baseQuantity.text = _packageQuantity.text;
      }
    });
  }

  void _baseQuantityChanged(String _) {
    _basisLinkedToPackage = false;
  }

  void _baseUnitChanged(FoodQuantityUnit? value) {
    if (value == null) return;
    setState(() {
      _baseUnit = value;
      _basisLinkedToPackage = false;
    });
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

  Future<void> _readNutrition() async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final image = await _captureGateway.selectImage(source);
      if (image == null) return;
      final rawText = await _captureGateway.recognizeJapaneseText(image);
      final draft = const JapaneseNutritionOcrParser().parse(rawText);
      if (!mounted) return;
      if (draft.isEmpty) {
        setState(() => _error = 'NUTRITION VALUES COULD NOT BE READ');
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
                _previewValue(
                  'NUTRITION BASIS',
                  draft.basisQuantity,
                  draft.basisUnit,
                ),
                _previewValue('CALORIES', draft.calories, null, suffix: 'kcal'),
                _previewValue('PROTEIN', draft.protein, null, suffix: 'g'),
                _previewValue('FAT', draft.fat, null, suffix: 'g'),
                _previewValue(
                  'CARBOHYDRATE',
                  draft.carbohydrate,
                  null,
                  suffix: 'g',
                ),
                _previewValue(
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
      if (apply == true && mounted) _applyOcr(draft);
    } catch (_) {
      if (mounted) setState(() => _error = 'OCR PROCESSING FAILED');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _scanBarcode() async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final image = await _captureGateway.selectImage(source);
      if (image == null) return;
      final value = await _captureGateway.scanBarcode(image);
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        setState(() => _error = 'BARCODE COULD NOT BE READ');
      } else {
        setState(() => _barcode.text = value);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'BARCODE SCAN FAILED');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Widget _previewValue(
    String label,
    double? value,
    FoodQuantityUnit? unit, {
    String suffix = '',
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      '$label  ${value == null ? 'NEEDS REVIEW' : '${unit != null
                ? _number(value)
                : label == 'CALORIES'
                ? FoodNutritionFormatter.calories(value)
                : FoodNutritionFormatter.macro(value)}${unit == null ? suffix : _unit(unit)}'}',
    ),
  );

  void _applyOcr(NutritionOcrDraft draft) {
    setState(() {
      if (draft.packageQuantity != null && draft.packageUnit != null) {
        _packageQuantity.text = _number(draft.packageQuantity);
        _packageUnit = draft.packageUnit;
      }
      if (draft.basisQuantity != null && draft.basisUnit != null) {
        _baseQuantity.text = _number(draft.basisQuantity);
        _baseUnit = draft.basisUnit!;
        _basisLinkedToPackage = false;
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
          _error = 'FOOD DATABASE SAVE FAILED';
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
              text: _capturing ? 'PROCESSING IMAGE' : 'READ NUTRITION LABEL',
              onPressed: _capturing || _saving ? null : _readNutrition,
            ),
            AppSpacing.gapMD,
            OperationTextField(controller: _name, label: 'NAME'),
            AppSpacing.gapMD,
            OperationTextField(controller: _brand, label: 'BRAND'),
            AppSpacing.gapMD,
            _dropdown(
              label: 'CATEGORY',
              value: _category,
              values: FoodCatalogCategory.values,
              text: foodCatalogCategoryLabel,
              onChanged: (value) => setState(() => _category = value),
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
                const SizedBox(width: AppSpacing.md),
                IconButton.filledTonal(
                  key: const ValueKey('food-catalog-barcode-scan'),
                  tooltip: 'SCAN BARCODE',
                  onPressed: _capturing || _saving ? null : _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
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
                    onChanged: (_) => _rawCalories = null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OperationTextField(
                    controller: _protein,
                    label: 'PROTEIN',
                    onChanged: (_) => _rawProtein = null,
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
                    onChanged: (_) => _rawFat = null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OperationTextField(
                    controller: _carbs,
                    label: 'CARBOHYDRATE',
                    onChanged: (_) => _rawCarbohydrate = null,
                  ),
                ),
              ],
            ),
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

  Future<void> _archive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ARCHIVE FOOD?'),
        content: const Text(
          'Past food logs and nutrition snapshots remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ARCHIVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.archive(entry.foodId);
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = entry.nutrition;
    final hasChart =
        nutrition.protein != null &&
        nutrition.fat != null &&
        nutrition.carbohydrate != null &&
        nutrition.protein! * 4 +
                nutrition.fat! * 9 +
                nutrition.carbohydrate! * 4 >
            0;
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
            if (hasChart) ...[AppSpacing.gapMD, _PfcCard(nutrition: nutrition)],
            if (!appInitializationController.value.isReadOnly) ...[
              AppSpacing.gapMD,
              OperationButton(
                icon: Icons.edit,
                text: 'EDIT',
                onPressed: () => _edit(context),
              ),
              AppSpacing.gapSM,
              OperationButton(
                icon: Icons.archive_outlined,
                text: 'ARCHIVE',
                onPressed: () => _archive(context),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        AppSpacing.gapXS,
        Text(value),
      ],
    ),
  );
}

class _PfcCard extends StatelessWidget {
  const _PfcCard({required this.nutrition});
  final NutritionSnapshot nutrition;

  @override
  Widget build(BuildContext context) {
    final values = [
      nutrition.protein! * 4,
      nutrition.fat! * 9,
      nutrition.carbohydrate! * 4,
    ];
    final total = values.reduce((a, b) => a + b);
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.secondary,
    ];
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(icon: Icons.donut_large, title: 'PFC BALANCE'),
          AppSpacing.gapSM,
          Row(
            key: const ValueKey('food-detail-pfc-horizontal'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                key: const ValueKey('food-detail-pfc-donut'),
                width: 104,
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _PfcPainter(values, colors)),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            nutrition.calories == null
                                ? 'N/A'
                                : '${FoodNutritionFormatter.calories(nutrition.calories!)} kcal',
                            key: const ValueKey(
                              'food-detail-pfc-center-calories',
                            ),
                            maxLines: 1,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    for (var index = 0; index < values.length; index++) ...[
                      _PfcMetricRow(
                        label: const ['PROTEIN', 'FAT', 'CARBOHYDRATE'][index],
                        grams: [
                          nutrition.protein!,
                          nutrition.fat!,
                          nutrition.carbohydrate!,
                        ][index],
                        percent: (values[index] / total * 100).round(),
                        color: colors[index],
                      ),
                      if (index < values.length - 1) AppSpacing.gapSM,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PfcMetricRow extends StatelessWidget {
  const _PfcMetricRow({
    required this.label,
    required this.grams,
    required this.percent,
    required this.color,
  });

  final String label;
  final double grams;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: ValueKey('food-detail-pfc-$label'),
    builder: (context, constraints) {
      final style = TextStyle(color: color, fontWeight: FontWeight.bold);
      final values = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${FoodNutritionFormatter.macro(grams)} g', style: style),
          const SizedBox(width: AppSpacing.sm),
          Text('$percent%', style: style),
        ],
      );
      if (constraints.maxWidth < 190) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: style),
            values,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: Text(label, style: style)),
          values,
        ],
      );
    },
  );
}

class _PfcPainter extends CustomPainter {
  const _PfcPainter(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.reduce((a, b) => a + b);
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      canvas.drawArc(
        rect.deflate(16),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PfcPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
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
String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
double? _optionalNumber(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : double.tryParse(value);
}

String foodCatalogCategoryLabel(FoodCatalogCategory category) =>
    switch (category) {
      FoodCatalogCategory.ingredient => '食材',
      FoodCatalogCategory.preparedFood => '調理済み食品',
      FoodCatalogCategory.packagedFood => '市販・包装食品',
      FoodCatalogCategory.beverage => '飲料',
    };

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
