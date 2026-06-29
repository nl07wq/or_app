import 'package:flutter/material.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/models/food_data.dart';
import '../../core/services/food_record_service.dart';
import '../../core/widgets/operation_button.dart';
import 'widgets/food_record_tile.dart';
import 'widgets/food_history.dart';
import 'widgets/food_input_form.dart';

class FoodInputPage extends StatefulWidget {
  const FoodInputPage({super.key});

  @override
  State<FoodInputPage> createState() => _FoodInputPageState();
}

class _FoodInputPageState extends State<FoodInputPage> {
  final mealController = TextEditingController();

  final calorieController = TextEditingController();

  final proteinController = TextEditingController();

  final fatController = TextEditingController();

  final carbohydrateController = TextEditingController();

  final memoController = TextEditingController();

  String mealType = "朝食";

  List<FoodData> records = [];

  String mealTypeLabel(String type) {
    switch (type) {
      case "朝食":
        return "🌅 朝食";
      case "昼食":
        return "☀️ 昼食";
      case "夕食":
        return "🌙 夕食";
      case "間食":
        return "🍫 間食";
      case "補食":
        return "💪 トレーニング補食";
      default:
        return type;
    }
  }

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    records = await FoodRecordService.load();

    if (mounted) {
      setState(() {});
    }
  }

  int get totalCalories => records.fold(0, (sum, item) => sum + item.calories);

  double get totalProtein =>
      records.fold(0.0, (sum, item) => sum + item.protein);

  double get totalFat => records.fold(0.0, (sum, item) => sum + item.fat);

  double get totalCarbohydrate =>
      records.fold(0.0, (sum, item) => sum + item.carbohydrate);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Input')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              OperationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FOOD',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: mealType,
                      decoration: const InputDecoration(
                        labelText: 'Meal Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '朝食', child: Text('🌅 朝食')),
                        DropdownMenuItem(value: '昼食', child: Text('☀️ 昼食')),
                        DropdownMenuItem(value: '夕食', child: Text('🌙 夕食')),
                        DropdownMenuItem(value: '間食', child: Text('🍫 間食')),
                        DropdownMenuItem(
                          value: '補食',
                          child: Text('💪 トレーニング補食'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          mealType = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: mealController,
                      decoration: const InputDecoration(
                        labelText: 'Meal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: calorieController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calories',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fat (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: carbohydrateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Carbohydrate (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: memoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Memo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    OperationButton(
                      text: "💾 Save Food",
                      onPressed: () {
                        final record = FoodData(
                          date: DateTime.now()
                              .toIso8601String()
                              .split('T')
                              .first,
                          mealType: mealType,
                          meal: mealController.text,
                          calories: int.tryParse(calorieController.text) ?? 0,
                          protein: double.tryParse(proteinController.text) ?? 0,
                          fat: double.tryParse(fatController.text) ?? 0,
                          carbohydrate:
                              double.tryParse(carbohydrateController.text) ?? 0,
                          memo: memoController.text,
                        );

                        FoodRecordService.save(record);

                        loadRecords();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Food saved')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              OperationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Total",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text("🔥 $totalCalories kcal"),
                    Text("💪 P ${totalProtein.toStringAsFixed(1)} g"),
                    Text("🥑 F ${totalFat.toStringAsFixed(1)} g"),
                    Text("🍚 C ${totalCarbohydrate.toStringAsFixed(1)} g"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              FoodHistory(
                records: records,
                onDelete: (record) {
                  FoodRecordService.delete(record);

                  loadRecords();

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Food deleted")));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
