import 'package:flutter/material.dart';

import '../../core/models/meal_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/repositories/food_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';

import 'services/food_submit_service.dart';
import 'services/food_summary_service.dart';

import 'widgets/food_input_form.dart';
import 'widgets/food_summary_card.dart';

class FoodEntryPage extends StatefulWidget {
  const FoodEntryPage({super.key});

  @override
  State<FoodEntryPage> createState() => _FoodEntryPageState();
}

class _FoodEntryPageState extends State<FoodEntryPage> {
  List<MealData> records = [];

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    records = await FoodRepository.getAll();

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> save(MealData data) async {
    try {
      await FoodSubmitService.save(data);
      await loadRecords();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FOOD")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              FoodInputForm(onSave: save),
              const SizedBox(height: 20),

              FoodSummaryCard(summary: FoodSummaryService.today(records)),
            ],
          ),
        ),
      ),
    );
  }
}
