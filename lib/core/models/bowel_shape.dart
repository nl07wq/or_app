import 'package:flutter/material.dart';

enum BowelShape {
  soft(0, "軟便", Icons.water_drop),

  normal(1, "普通便", Icons.check_circle),

  hard(2, "硬便", Icons.hexagon);

  const BowelShape(this.value, this.label, this.icon);

  final int value;
  final String label;
  final IconData icon;

  static BowelShape fromValue(int value) {
    return values.firstWhere((e) => e.value == value, orElse: () => normal);
  }
}
