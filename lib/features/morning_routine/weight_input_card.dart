import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';

class WeightInputCard extends StatelessWidget {
  final TextEditingController controller;

  const WeightInputCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.monitor_weight, title: "BODY"),

          const SizedBox(height: 12),

          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 22),
            decoration: const InputDecoration(
              labelText: "体重 (kg)",
              hintText: "例）100.0",
              hintStyle: TextStyle(color: Colors.white38),
              labelStyle: TextStyle(color: Colors.white70),

              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),

              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
