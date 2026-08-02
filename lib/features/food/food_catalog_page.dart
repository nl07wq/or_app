import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../repositories/app_repository_container.dart';
import 'models/food_catalog_models.dart';
import 'models/food_provenance_models.dart';
import 'models/food_quantity_models.dart';
import 'models/nutrition_models.dart';
import 'services/food_application_service.dart';

class FoodCatalogPage extends StatefulWidget {
  const FoodCatalogPage({super.key});

  @override
  State<FoodCatalogPage> createState() => _FoodCatalogPageState();
}

class _FoodCatalogPageState extends State<FoodCatalogPage> {
  bool _showArchived = false;
  late Future<List<FoodCatalogEntry>> _future = _load();

  Future<List<FoodCatalogEntry>> _load() =>
      AppRepositoryRegistry.container.foodCatalog.list();

  void _refresh() => setState(() => _future = _load());

  Future<void> _open([FoodCatalogEntry? entry]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FoodCatalogEditorPage(entry: entry)),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FOOD DATABASE')),
    body: FutureBuilder<List<FoodCatalogEntry>>(
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
              text: 'ADD FOOD',
              onPressed: _open,
            ),
            AppSpacing.gapMD,
            SwitchListTile(
              title: const Text('Show archived'),
              value: _showArchived,
              onChanged: (value) => setState(() => _showArchived = value),
            ),
            AppSpacing.gapMD,
            if (values.isEmpty) const Center(child: Text('No food entries.')),
            for (final entry in values) ...[
              OperationCard(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(
                    entry.isArchived ? Icons.archive : Icons.restaurant,
                  ),
                  title: Text(entry.name),
                  subtitle: Text(
                    '${_categoryLabel(entry.category)} · '
                    '${entry.baseQuantity.value} ${_unitLabel(entry.baseQuantity.unit)}'
                    '${entry.isArchived ? ' · Archived' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(entry),
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

class FoodCatalogEditorPage extends StatefulWidget {
  final FoodCatalogEntry? entry;

  const FoodCatalogEditorPage({super.key, this.entry});

  @override
  State<FoodCatalogEditorPage> createState() => _FoodCatalogEditorPageState();
}

class _FoodCatalogEditorPageState extends State<FoodCatalogEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.entry?.name);
  late final _brand = TextEditingController(text: widget.entry?.brand);
  late final _quantity = TextEditingController(
    text: '${widget.entry?.baseQuantity.value ?? 100}',
  );
  late final _basis = TextEditingController(
    text: widget.entry?.baseQuantity.basisValue?.toString(),
  );
  late final _calories = _nutritionController(widget.entry?.nutrition.calories);
  late final _protein = _nutritionController(widget.entry?.nutrition.protein);
  late final _fat = _nutritionController(widget.entry?.nutrition.fat);
  late final _carbohydrate = _nutritionController(
    widget.entry?.nutrition.carbohydrate,
  );
  late final _sourceName = TextEditingController(
    text: widget.entry?.provenance.sourceName,
  );
  late final _sourceReference = TextEditingController(
    text: widget.entry?.provenance.sourceReference,
  );
  late final _notes = TextEditingController(
    text: widget.entry?.provenance.notes,
  );
  late final _memo = TextEditingController(text: widget.entry?.memo);
  late FoodCatalogCategory _category =
      widget.entry?.category ?? FoodCatalogCategory.ingredient;
  late FoodQuantityUnit _unit =
      widget.entry?.baseQuantity.unit ?? FoodQuantityUnit.gram;
  late FoodQuantityUnit _basisUnit =
      widget.entry?.baseQuantity.basisUnit ?? FoodQuantityUnit.gram;
  late NutritionStatus _status =
      widget.entry?.nutritionStatus ?? NutritionStatus.unknown;
  late FoodProvenanceSourceType _sourceType =
      widget.entry?.provenance.sourceType ?? FoodProvenanceSourceType.unknown;
  bool _saving = false;

  static TextEditingController _nutritionController(double? value) =>
      TextEditingController(text: value?.toString() ?? '');
  double? _optional(TextEditingController value) =>
      value.text.trim().isEmpty ? null : double.tryParse(value.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final nutrition = NutritionSnapshot(
        calories: _optional(_calories),
        protein: _optional(_protein),
        fat: _optional(_fat),
        carbohydrate: _optional(_carbohydrate),
      );
      if (nutrition.isEmpty && _status != NutritionStatus.unknown) {
        throw const FormatException('Empty nutrition requires Unknown status.');
      }
      if (!nutrition.isEmpty && _status == NutritionStatus.unknown) {
        throw const FormatException(
          'Choose a nutrition status for entered values.',
        );
      }
      final value = double.parse(_quantity.text.trim());
      final basisValue = _unit.isPhysical ? null : _optional(_basis);
      final now = DateTime.now().toUtc();
      final current = widget.entry;
      final entry = FoodCatalogEntry(
        foodId: current?.foodId ?? FoodApplicationService.newId(),
        name: _name.text.trim(),
        category: _category,
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        baseQuantity: FoodQuantityDefinition(
          value: value,
          unit: _unit,
          basisValue: basisValue,
          basisUnit: basisValue == null ? null : _basisUnit,
        ),
        nutrition: nutrition,
        nutritionStatus: _status,
        provenance: FoodApplicationService.provenance(
          _sourceType,
          sourceName: _sourceName.text,
          sourceReference: _sourceReference.text,
          notes: _notes.text,
        ),
        isArchived: current?.isArchived ?? false,
        memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
      );
      final repository = AppRepositoryRegistry.container.foodCatalog;
      if (current == null) {
        await repository.create(entry);
      } else {
        await repository.update(entry);
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
    await AppRepositoryRegistry.container.foodCatalog.archive(
      widget.entry!.foodId,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.entry == null ? 'ADD FOOD' : 'FOOD DETAIL'),
    ),
    body: Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(icon: Icons.restaurant, title: 'FOOD DETAILS'),
            AppSpacing.gapMD,
            _field(_name, 'Name', required: true),
            _field(_brand, 'Brand'),
            DropdownButtonFormField(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: FoodCatalogCategory.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_categoryLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            AppSpacing.gapMD,
            _field(_quantity, 'Base Quantity', required: true, number: true),
            DropdownButtonFormField(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Quantity Unit'),
              items: FoodQuantityUnit.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_unitLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _unit = value!),
            ),
            if (!_unit.isPhysical) ...[
              _field(_basis, 'Basis Value', number: true),
              DropdownButtonFormField(
                initialValue: _basisUnit,
                decoration: const InputDecoration(labelText: 'Basis Unit'),
                items:
                    const [FoodQuantityUnit.gram, FoodQuantityUnit.milliliter]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_unitLabel(value)),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _basisUnit = value!),
              ),
            ],
            AppSpacing.gapLG,
            const SectionHeader(icon: Icons.monitor_heart, title: 'NUTRITION'),
            AppSpacing.gapMD,
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _sized(_field(_calories, 'Calories', number: true)),
                _sized(_field(_protein, 'Protein', number: true)),
                _sized(_field(_fat, 'Fat', number: true)),
                _sized(_field(_carbohydrate, 'Carbohydrate', number: true)),
              ],
            ),
            DropdownButtonFormField(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Nutrition Status'),
              items: NutritionStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_title(value.stableId)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
            DropdownButtonFormField(
              initialValue: _sourceType,
              decoration: const InputDecoration(
                labelText: 'Provenance Source Type',
              ),
              items: FoodProvenanceSourceType.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_title(value.stableId)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _sourceType = value!),
            ),
            _field(_sourceName, 'Source Name'),
            _field(_sourceReference, 'Source Reference'),
            _field(_notes, 'Provenance Notes'),
            _field(_memo, 'Memo'),
            AppSpacing.gapLG,
            OperationButton(
              text: widget.entry == null ? 'ADD FOOD' : 'UPDATE FOOD',
              icon: Icons.save,
              onPressed: _saving ? null : _save,
            ),
            if (widget.entry != null && !widget.entry!.isArchived) ...[
              AppSpacing.gapMD,
              OperationButton(
                text: 'ARCHIVE FOOD',
                icon: Icons.archive,
                onPressed: _saving ? null : _archive,
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required.'
                : null
          : null,
    ),
  );

  Widget _sized(Widget child) => SizedBox(width: 150, child: child);
}

String _categoryLabel(FoodCatalogCategory value) => _title(value.stableId);
String _unitLabel(FoodQuantityUnit value) => switch (value) {
  FoodQuantityUnit.gram => 'Gram',
  FoodQuantityUnit.milliliter => 'Milliliter',
  FoodQuantityUnit.piece => 'Piece',
  FoodQuantityUnit.pack => 'Pack',
  FoodQuantityUnit.serving => 'Serving',
};
String _title(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .split(' ')
    .where((value) => value.isNotEmpty)
    .map((value) => '${value[0].toUpperCase()}${value.substring(1)}')
    .join(' ');
