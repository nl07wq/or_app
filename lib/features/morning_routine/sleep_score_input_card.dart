import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';

class SleepScoreInputCard extends StatelessWidget {
  final TextEditingController controller;

  const SleepScoreInputCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SLEEP SCORE", style: TextStyle(color: Colors.white70)),

          const SizedBox(height: 12),

          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 22),
            decoration: const InputDecoration(
              labelText: "睡眠スコア",
              hintText: "例）82",
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
