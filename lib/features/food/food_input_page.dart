import 'package:flutter/material.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_button.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Input')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FOOD',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  
                  TextField(
                    controller: mealController,
                    decoration: const InputDecoration(labelText: 'Meal'),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: calorieController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Calories'),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Protein (g)'),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fat (g)'),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: carbohydrateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Carbohydrate (g)',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: memoController,
                    decoration: const InputDecoration(labelText: 'Memo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
