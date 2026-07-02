import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../food_entry_page.dart';

class FoodManualCard extends StatelessWidget {
  const FoodManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.edit_note, title: "MANUAL ENTRY"),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
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
          ),
        ],
      ),
    );
  }
}
