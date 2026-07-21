import 'package:flutter/material.dart';

import '../../core/models/meal_data.dart';
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

  Future<void> save(MealData data) async {
    try { await FoodSubmitService.save(data); } on ConfirmedDailyLogException catch (error) { if (mounted) showConfirmedLogMessage(context, error); return; }

    await loadRecords();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text(data.isWaterEntry ? 'Water saved' : 'Meal saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FOOD ENTRY")),
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
