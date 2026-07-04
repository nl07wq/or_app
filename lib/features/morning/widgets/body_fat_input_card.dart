import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';

class BodyFatInputCard extends StatelessWidget {
  final TextEditingController controller;

  const BodyFatInputCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BODY FAT", style: TextStyle(color: Colors.white70)),

          const SizedBox(height: 12),

          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 22),
            decoration: const InputDecoration(
              labelText: "体脂肪率 (%)",
              hintText: "例）34.8",
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
