import 'package:flutter/material.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/models/food_data.dart';
import '../../core/services/food_record_service.dart';
import '../../core/widgets/operation_button.dart';
import 'widgets/food_history.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/operation_dropdown.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/operation_description.dart';

class FoodEntryPage extends StatefulWidget {
  const FoodEntryPage({super.key});

  @override
  State<FoodEntryPage> createState() => _FoodEntryPageState();
}

class _FoodEntryPageState extends State<FoodEntryPage> {
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
      appBar: AppBar(title: const Text("FOOD ENTRY")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              OperationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      icon: Icons.restaurant,
                      title: "FOOD ENTRY",
                    ),

                    const SizedBox(height: 8),

                    const OperationDescription(
                      text:
                          "食事内容と栄養情報を記録します。\n"
                          "手入力またはSync機能から登録できます。",
                    ),

                    const SizedBox(height: 20),

                    OperationDropdown<String>(
                      label: "Meal Type",
                      value: mealType,
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

                    OperationTextField(
                      controller: mealController,
                      label: "Meal",
                    ),
                    const SizedBox(height: 16),

                    OperationTextField(
                      controller: calorieController,
                      label: "Calories",
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    OperationTextField(
                      controller: proteinController,
                      label: "Protein (g)",
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    OperationTextField(
                      controller: fatController,
                      label: "Fat (g)",
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    OperationTextField(
                      controller: carbohydrateController,
                      label: "Carbohydrate (g)",
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    OperationTextField(
                      controller: memoController,
                      label: "Memo",
                      maxLines: 3,
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
                    const SectionHeader(
                      icon: Icons.calculate,
                      title: "TODAY'S TOTAL",
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
