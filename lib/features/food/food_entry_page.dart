import 'package:flutter/material.dart';

import '../../core/models/meal_data.dart';
import '../../core/repositories/food_repository.dart';

import 'services/food_submit_service.dart';

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
    await FoodSubmitService.save(data);

    await loadRecords();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Meal saved")));
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

              FoodSummaryCard(records: records),
            ],
          ),
        ),
      ),
    );
  }
}
