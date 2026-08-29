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
import 'repository/food_catalog_repository.dart';
import 'repository/food_meal_id_generator.dart';

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
  });

  final FoodCatalogRepository repository;
  final FoodCatalogEntry? initialEntry;
  final FoodCatalogDraft? draft;

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
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    final draft = widget.draft;
    if (entry != null) {
      _name.text = entry.name;
      _brand.text = entry.brand ?? '';
      _barcode.text = entry.barcodeValue ?? '';
      _packageQuantity.text = _number(entry.packageQuantity);
      _baseQuantity.text = _number(entry.baseQuantity.value);
      _calories.text = _number(entry.nutrition.calories);
      _protein.text = _number(entry.nutrition.protein);
      _fat.text = _number(entry.nutrition.fat);
      _carbs.text = _number(entry.nutrition.carbohydrate);
      _memo.text = entry.memo ?? '';
      _category = entry.category;
      _packageUnit = entry.packageUnit;
      _baseUnit = entry.baseQuantity.unit;
    } else if (draft != null) {
      _name.text = draft.name;
      _baseQuantity.text = _number(draft.baseQuantity.value);
      _calories.text = _number(draft.nutrition.calories);
      _protein.text = _number(draft.nutrition.protein);
      _fat.text = _number(draft.nutrition.fat);
      _carbs.text = _number(draft.nutrition.carbohydrate);
      _brand.text = draft.brand ?? '';
      _barcode.text = draft.barcodeValue ?? '';
      _packageQuantity.text = _number(draft.packageQuantity);
      _memo.text = draft.memo ?? '';
      _category = draft.category;
      _packageUnit = draft.packageUnit;
      _baseUnit = draft.baseQuantity.unit;
    } else {
      _baseQuantity.text = '100';
    }
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
      calories: _optionalNumber(_calories),
      protein: _optionalNumber(_protein),
      fat: _optionalNumber(_fat),
      carbohydrate: _optionalNumber(_carbs),
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
            OperationTextField(controller: _barcode, label: 'BARCODE / JAN'),
            AppSpacing.gapMD,
            _quantityRow(
              controller: _packageQuantity,
              label: 'PACKAGE QUANTITY',
              value: _packageUnit,
              allowNull: true,
              onChanged: (value) => setState(() => _packageUnit = value),
            ),
            AppSpacing.gapMD,
            _quantityRow(
              controller: _baseQuantity,
              label: 'NUTRITION BASIS',
              value: _baseUnit,
              onChanged: (value) => setState(() => _baseUnit = value!),
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                Expanded(
                  child: OperationTextField(
                    controller: _calories,
                    label: 'CALORIES',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OperationTextField(
                    controller: _protein,
                    label: 'PROTEIN',
                  ),
                ),
              ],
            ),
            AppSpacing.gapMD,
            Row(
              children: [
                Expanded(
                  child: OperationTextField(controller: _fat, label: 'FAT'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OperationTextField(
                    controller: _carbs,
                    label: 'CARBOHYDRATE',
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
    bool allowNull = false,
  }) => Row(
    children: [
      Expanded(
        child: OperationTextField(controller: controller, label: label),
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
                  if (nutrition.calories != null)
                    _detail('CALORIES', '${_format(nutrition.calories!)} kcal'),
                  if (nutrition.protein != null)
                    _detail('PROTEIN', '${_format(nutrition.protein!)} g'),
                  if (nutrition.fat != null)
                    _detail('FAT', '${_format(nutrition.fat!)} g'),
                  if (nutrition.carbohydrate != null)
                    _detail(
                      'CARBOHYDRATE',
                      '${_format(nutrition.carbohydrate!)} g',
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
        children: [
          const SectionHeader(icon: Icons.donut_large, title: 'PFC BALANCE'),
          AppSpacing.gapMD,
          SizedBox(
            width: 144,
            height: 144,
            child: CustomPaint(painter: _PfcPainter(values, colors)),
          ),
          AppSpacing.gapMD,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              for (var index = 0; index < values.length; index++)
                Text(
                  '${const ['P', 'F', 'C'][index]} ${(values[index] / total * 100).round()}%',
                  style: TextStyle(
                    color: colors[index],
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
