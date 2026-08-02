import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';
import '../food_entry_page.dart';

class FoodManualCard extends StatelessWidget {
  const FoodManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.edit_note,
        text: "FOOD ENTRY",
        onPressed: appInitializationController.value.isReadOnly
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodEntryPage()),
                );
              },
      ),
    );
  }
}
