import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';

class SleepInputCard extends StatelessWidget {
  final TextEditingController controller;

  const SleepInputCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SLEEP', style: TextStyle(color: Colors.white70)),

          const SizedBox(height: 12),

          TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.white, fontSize: 22),
            decoration: const InputDecoration(
              labelText: '睡眠時間',
              hintText: '例：7:30',
              helperText: '時間:分（24時間ではありません）',
              labelStyle: TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white38),
              helperStyle: TextStyle(color: Colors.white54),

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
