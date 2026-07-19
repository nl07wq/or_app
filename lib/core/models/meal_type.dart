import 'package:flutter/material.dart';

enum MealType {
  breakfast("朝食", Icons.breakfast_dining),

  lunch("昼食", Icons.bento),

  dinner("夕食", Icons.restaurant),

  snack("間食", Icons.cookie),

  training("補食", Icons.fitness_center);

  const MealType(this.label, this.icon);

  final String label;
  final IconData icon;

  static MealType fromLabel(String label) {
    return MealType.values.firstWhere(
      (e) => e.label == label,
      orElse: () => MealType.breakfast,
    );
  }
}
