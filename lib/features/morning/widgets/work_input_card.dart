import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class WorkInputCard extends StatelessWidget {
  final TextEditingController controller;

  const WorkInputCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.work, title: "WORK"),
          const SizedBox(height: 12),

          TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.white, fontSize: 22),
            decoration: const InputDecoration(
              labelText: '勤務時間',
              hintText: '例：8:30',
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
