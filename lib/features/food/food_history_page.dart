import 'package:flutter/material.dart';

import 'food_nutrition_formatter.dart';
import 'food_edit_page.dart';
import 'services/food_submit_service.dart';

import '../../core/models/meal_data.dart';
import '../../core/models/food_item.dart';
import '../../core/repositories/food_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/state/app_initialization_state.dart';
import '../repositories/app_repository_container.dart';
import 'food_catalog_page.dart';
import 'models/daily_meal_v2_models.dart';
import 'models/food_catalog_models.dart';
import 'models/food_quantity_models.dart';
import 'models/food_unified_read_model.dart';
import 'models/nutrition_models.dart';
import 'models/recipe_models_v2.dart';
import 'widgets/food_thumbnail.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({super.key});

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  bool _isLoading = true;
  List<MealData> _records = const [];
  List<DailyMealV2> _v2Records = const [];
  List<FoodUnifiedReadModel> _historyOrder = const [];
  Map<String, FoodCatalogEntry> _catalogEntries = const {};
  Map<String, FoodRecipeDefinition> _recipeEntries = const {};
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRecords(showLoading: false);
  }

  Future<void> _loadRecords({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    List<MealData>? loadedRecords;
    Object? loadError;
    try {
      loadedRecords = (await FoodRepository.getAll()).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final v2Records = AppRepositoryRegistry.hasContainer
          ? await AppRepositoryRegistry.container.dailyMealsV2.findAll()
          : const <DailyMealV2>[];
      _v2Records = v2Records.reversed.toList(growable: false);
      if (AppRepositoryRegistry.hasContainer) {
        _historyOrder = await AppRepositoryRegistry.container.foodMixedRead
            .readHistory();
        final referenceIds = v2Records
            .expand((meal) => meal.items)
            .map((item) => item.foodReferenceId)
            .whereType<String>()
            .toSet();
        final catalog = await Future.wait(
          referenceIds.map(
            AppRepositoryRegistry.container.foodCatalog.readById,
          ),
        );
        _catalogEntries = {
          for (final entry in catalog.whereType<FoodCatalogEntry>())
            entry.foodId: entry,
        };
        final recipeReferenceIds = v2Records
            .expand((meal) => meal.items)
            .map((item) => item.recipeReferenceId)
            .whereType<String>()
            .toSet();
        final recipes = await Future.wait(
          recipeReferenceIds.map(
            AppRepositoryRegistry.container.foodRecipes.readById,
          ),
        );
        _recipeEntries = {
          for (final recipe in recipes.whereType<FoodRecipeDefinition>())
            recipe.recipeId: recipe,
        };
      } else {
        _historyOrder = const [];
        _catalogEntries = const {};
        _recipeEntries = const {};
      }
    } catch (error) {
      loadError = error;
    } finally {
      if (mounted) {
        setState(() {
          if (loadError == null) {
            _records = List.unmodifiable(loadedRecords!);
          }
          _loadError = loadError;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRecord(MealData data) async {
    final result = await showHistoryDeleteDialog(
      context,
      title: data.isWaterEntry ? 'Water Record' : 'Meal Record',
    );

    if (!result) return;

    try {
      await FoodSubmitService.delete(data);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    }

    await _loadRecords();
  }

  Future<void> _deleteV2Record(DailyMealV2 meal) async {
    final confirmed = await showHistoryDeleteDialog(
      context,
      title: 'Meal Record',
    );
    if (!confirmed) return;
    try {
      await FoodSubmitService.deleteV2(meal);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MEAL DELETE FAILED')));
      }
      return;
    }
    await _loadRecords();
  }

  Widget _buildMealCard(BuildContext context, MealData meal) {
    return OperationCard(
      key: ValueKey('food-history-v1-${meal.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meal.date,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: appInitializationController.value.isReadOnly
                    ? null
                    : () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FoodEditPage(meal: meal),
                          ),
                        );

                        if (updated == true) {
                          await _loadRecords();
                        }
                      },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: appInitializationController.value.isReadOnly
                    ? null
                    : () => _deleteRecord(meal),
              ),
            ],
          ),
          SectionHeader(
            icon: meal.isWaterEntry
                ? Icons.water_drop_outlined
                : Icons.restaurant,
            title: meal.isWaterEntry ? 'Water' : meal.mealType,
          ),
          AppSpacing.gapMD,
          if (meal.isWaterEntry)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.water_drop_outlined),
              title: Text('${meal.waterMl!.toStringAsFixed(0)} ml'),
            )
          else
            ...meal.items.map(
              (item) => Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const FoodThumbnail(visualKey: null),
                    title: Text(
                      item.hasMeasuredAmount
                          ? item.amountMode == FoodAmountMode.baseMultiplier
                                ? '${item.name}  AMOUNT '
                                      '${FoodNutritionFormatter.amount(item.amount!)}'
                                      ' (${FoodNutritionFormatter.amount(item.physicalAmount!)}'
                                      '${item.baseUnit!.label})'
                                : '${item.name}  '
                                      '${FoodNutritionFormatter.amount(item.amount!)}'
                                      '${item.baseUnit!.label}'
                          : item.quantity > 1
                          ? '${item.name} ×${item.quantity}'
                          : item.name,
                    ),
                    subtitle: Text(
                      "${FoodNutritionFormatter.calories(item.totalCalories)} kcal"
                      "  P ${FoodNutritionFormatter.macro(item.totalProtein)}"
                      "  F ${FoodNutritionFormatter.macro(item.totalFat)}"
                      "  C ${FoodNutritionFormatter.macro(item.totalCarbohydrate)}",
                    ),
                  ),
                  if (!appInitializationController.value.isReadOnly)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _addLegacyItemToCatalog(item),
                        icon: const Icon(Icons.add_business),
                        label: const Text('ADD TO FOOD DATABASE'),
                      ),
                    ),
                ],
              ),
            ),
          if (meal.memo.isNotEmpty) ...[
            AppSpacing.gapMD,
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.note_outlined),
              title: Text(meal.memo),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addLegacyItemToCatalog(FoodItem item) async {
    if (!AppRepositoryRegistry.hasContainer) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogEditorPage(
          repository: AppRepositoryRegistry.container.foodCatalog,
          draft: FoodCatalogDraft(
            name: item.name,
            baseQuantity: FoodQuantityDefinition(
              value: item.baseAmount ?? 1,
              unit: item.baseUnit == FoodBaseUnit.ml
                  ? FoodQuantityUnit.milliliter
                  : item.baseUnit == FoodBaseUnit.g
                  ? FoodQuantityUnit.gram
                  : FoodQuantityUnit.serving,
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
  }

  Widget _buildV2MealCard(DailyMealV2 meal) => OperationCard(
    key: ValueKey('food-history-v2-${meal.mealId}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                meal.localDate,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: ValueKey('delete-v2-meal-${meal.mealId}'),
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: appInitializationController.value.isReadOnly
                  ? null
                  : () => _deleteV2Record(meal),
            ),
          ],
        ),
        AppSpacing.gapSM,
        SectionHeader(
          icon: Icons.restaurant,
          title: meal.mealType.stableId.toUpperCase(),
        ),
        AppSpacing.gapSM,
        for (final item in meal.items) ...[
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: FoodThumbnail(
              visualKey: item.foodReferenceId == null
                  ? null
                  : _catalogEntries[item.foodReferenceId!]?.visualKey,
            ),
            title: Text(item.nameSnapshot),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (item.category != null)
                      foodCatalogCategoryLabel(item.category!),
                    FoodNutritionFormatter.compactQuantity(item.quantity),
                  ].join('  '),
                ),
                Text(
                  FoodNutritionFormatter.compactNutrition(
                    item.nutritionConsumed,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
          if (!appInitializationController.value.isReadOnly &&
              !_hasActiveMasterReference(item))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _addV2ItemToCatalog(item),
                icon: const Icon(Icons.add_business),
                label: const Text('ADD TO FOOD DATABASE'),
              ),
            ),
        ],
      ],
    ),
  );

  bool _hasActiveMasterReference(DailyMealItemSnapshot item) {
    final foodReferenceId = item.foodReferenceId;
    if (foodReferenceId != null) {
      final entry = _catalogEntries[foodReferenceId];
      return entry != null && !entry.isArchived;
    }
    final recipeReferenceId = item.recipeReferenceId;
    if (recipeReferenceId != null) {
      final recipe = _recipeEntries[recipeReferenceId];
      return recipe != null && !recipe.isArchived;
    }
    return false;
  }

  Future<void> _addV2ItemToCatalog(DailyMealItemSnapshot item) async {
    if (!AppRepositoryRegistry.hasContainer) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCatalogEditorPage(
          repository: AppRepositoryRegistry.container.foodCatalog,
          draft: FoodCatalogDraft(
            name: item.nameSnapshot,
            category: item.category ?? FoodCatalogCategory.preparedFood,
            baseQuantity: item.quantity,
            nutrition: item.nutritionPerBase,
            memo: item.memo,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FOOD')),
      body: Padding(padding: AppSpacing.cardPadding, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final loadError = _loadError;
    if (loadError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Unable to load food records.',
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapMD,
              Text(
                loadError.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              AppSpacing.gapMD,
              OperationButton(
                icon: Icons.refresh,
                text: 'RETRY',
                onPressed: _loadRecords,
              ),
            ],
          ),
        ),
      );
    }
    if (_records.isEmpty && _v2Records.isEmpty) {
      return const Center(child: Text('No meal records.'));
    }

    final legacyById = {for (final meal in _records) meal.id: meal};
    final v2ById = {for (final meal in _v2Records) meal.mealId: meal};
    final groupedCards = <String, List<Widget>>{};
    for (final record in _historyOrder) {
      final card = switch (record.identity.recordKind) {
        FoodRecordKind.legacyV1 =>
          legacyById[record.identity.recordId] == null
              ? null
              : _buildMealCard(context, legacyById[record.identity.recordId]!),
        FoodRecordKind.dailyMealV2 =>
          v2ById[record.identity.recordId] == null
              ? null
              : _buildV2MealCard(v2ById[record.identity.recordId]!),
      };
      if (card != null) {
        groupedCards.putIfAbsent(record.localDate, () => []).add(card);
      }
    }
    if (groupedCards.isEmpty) {
      for (final meal in _records) {
        groupedCards
            .putIfAbsent(meal.date.substring(0, 10), () => [])
            .add(_buildMealCard(context, meal));
      }
    }
    final sections = [
      for (final group in groupedCards.entries)
        Column(
          key: ValueKey('food-history-date-${group.key}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(icon: Icons.calendar_today, title: group.key),
            AppSpacing.gapMD,
            for (var index = 0; index < group.value.length; index++) ...[
              group.value[index],
              if (index < group.value.length - 1) AppSpacing.gapMD,
            ],
          ],
        ),
    ];
    return ListView.separated(
      itemCount: sections.length,
      separatorBuilder: (_, _) => AppSpacing.gapXL,
      itemBuilder: (context, index) => sections[index],
    );
  }
}
