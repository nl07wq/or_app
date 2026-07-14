import 'package:flutter/material.dart';

import 'hud/hud_ruler.dart';

class OperationRuler extends StatefulWidget {
  final TextEditingController controller;

  final double min;
  final double max;
  final double step;

  final String unit;

  const OperationRuler({
    super.key,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
  });

  @override
  State<OperationRuler> createState() => _OperationRulerState();
}

class _OperationRulerState extends State<OperationRuler> {
  late double value;

  @override
  void initState() {
    super.initState();

    value =
        double.tryParse(widget.controller.text) ??
        ((widget.max + widget.min) / 2);

    widget.controller.text = value.toStringAsFixed(1);
  }

  void update(double delta) {
    value += delta;

    if (value < widget.min) value = widget.min;
    if (value > widget.max) value = widget.max;

    value = (value / widget.step).roundToDouble() * widget.step;

    widget.controller.text = value.toStringAsFixed(1);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return HUDRuler(value: value, unit: widget.unit, onDrag: update);
  }
}
