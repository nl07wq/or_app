import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';

class WeightInputCard extends StatelessWidget {
  final TextEditingController controller;

  const WeightInputCard({
    super.key,
    required this.controller,
  });


  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WEIGHT",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),

          SizedBox(height: 12),

          TextField(
  controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
            ),
            decoration: InputDecoration(
              labelText: "体重 (kg)",
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