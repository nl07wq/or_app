import 'package:flutter/material.dart';

enum BowelAmount {
  none(0, "なし", Icons.block),

  small(1, "少", Icons.lens),

  normal(2, "普通", Icons.radio_button_checked),

  much(3, "多", Icons.circle);

  const BowelAmount(this.value, this.label, this.icon);

  final int value;
  final String label;
  final IconData icon;

  static BowelAmount fromValue(int value) {
    return values.firstWhere((e) => e.value == value, orElse: () => normal);
  }
}
