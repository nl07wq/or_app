import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../food_entry_page.dart';

class FoodManualCard extends StatelessWidget {
  const FoodManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
            child: OperationButton(
              icon: Icons.edit_note,
              text: "Food Entry",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodEntryPage()),
                );
              },
            ),
          );
  }
}
