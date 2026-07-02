import 'package:flutter/material.dart';

import 'widgets/food_sync_card.dart';
import 'widgets/food_manual_card.dart';
import 'widgets/food_history_button.dart';

class FoodPage extends StatelessWidget {
  const FoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FOOD")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            FoodSyncCard(),

            SizedBox(height: 16),

            FoodManualCard(),

            SizedBox(height: 16),

            FoodHistoryButton(),
          ],
        ),
      ),
    );
  }
}
