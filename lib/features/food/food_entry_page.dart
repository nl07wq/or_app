import 'package:flutter/material.dart';

import '../../core/models/meal_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../operation_date/services/operation_date_service.dart';

import 'services/food_submit_service.dart';
import '../repositories/app_repository_container.dart';
import 'models/food_catalog_models.dart';
import 'models/recipe_models_v2.dart';
import 'repository/food_meal_id_generator.dart';
import 'models/food_summary_state.dart';
import 'services/food_catalog_meal_mapper.dart';

import 'widgets/food_input_form.dart';
import 'widgets/food_summary_card.dart';

class FoodEntryPage extends StatefulWidget {
  final OperationDateService operationDateService;

  const FoodEntryPage({
    super.key,
    this.operationDateService = const OperationDateService(),
  });

  @override
  State<FoodEntryPage> createState() => _FoodEntryPageState();
}

class _FoodEntryPageState extends State<FoodEntryPage> {
  String? _localDate;
  Object? _dateLoadError;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    try {
      final localDate = (await widget.operationDateService.current()).value;
      _localDate = localDate;
      await refreshFoodSummary(localDate: localDate);
      _dateLoadError = null;
    } catch (error) {
      _dateLoadError = error;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> save(MealData data) async {
    final localDate = _localDate;
    if (localDate == null) return false;
    try {
      await FoodSubmitService.save(data, operationLocalDate: localDate);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MEALの保存に失敗しました')));
      }
      return false;
    }

    if (!mounted) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(data.isWaterEntry ? 'Water saved' : 'MEALを保存しました'),
      ),
    );

    if (!data.isWaterEntry) {
      Navigator.popUntil(context, ModalRoute.withName(AppRoutes.food));
    }
    return true;
  }

  Future<bool> saveWithCatalog(
    MealData data,
    List<FoodCatalogEntry?> catalogSources,
    List<FoodRecipeDefinition?> recipeSources,
  ) async {
    final localDate = _localDate;
    if (localDate == null || catalogSources.length != data.items.length) {
      return false;
    }
    try {
      await DailyLogMutationGuard.assertDateMutable(DateTime.parse(localDate));
      final timestamp = DateTime.now().toUtc();
      final idGenerator = FoodMealIdGenerator();
      await AppRepositoryRegistry.container.dailyMealsV2.create(
        FoodCatalogMealMapper.map(
          meal: data,
          catalogSources: catalogSources,
          recipeSources: recipeSources,
          localDate: localDate,
          timestamp: timestamp,
          idGenerator: idGenerator,
        ),
      );
      await refreshFoodSummary(localDate: localDate);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MEAL SAVE FAILED')));
      }
      return false;
    }
    if (!mounted) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('MEAL SAVED')));
    Navigator.popUntil(context, ModalRoute.withName(AppRoutes.food));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FOOD")),
      body: _localDate == null && _dateLoadError == null
          ? const Center(child: CircularProgressIndicator())
          : _dateLoadError != null
          ? const Center(child: Text('Operation Dateを取得できませんでした。'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FoodInputForm(
                      onSave: save,
                      onSaveWithCatalog: saveWithCatalog,
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder(
                      valueListenable: foodSummaryNotifier,
                      builder: (context, summary, _) => summary == null
                          ? const SizedBox.shrink()
                          : FoodSummaryCard(summary: summary),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
