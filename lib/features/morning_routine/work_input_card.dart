import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';

class WorkInputCard extends StatelessWidget {
  const WorkInputCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WORK',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
            ),
            decoration: const InputDecoration(
              labelText: '勤務メモ',
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