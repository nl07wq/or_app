import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';

class SleepInputCard extends StatelessWidget {
  const SleepInputCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SLEEP',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
            ),
            decoration: const InputDecoration(
              labelText: '睡眠時間 (時間)',
              labelStyle: TextStyle(
                color: Colors.white70,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white24,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}