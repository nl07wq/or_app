import 'package:flutter/material.dart';

import 'hud/hud_ruler.dart';

class OperationRuler extends StatefulWidget {
  final TextEditingController controller;

  final double min;
  final double max;
  final double step;

  final String unit;

  final double initialValue;

  const OperationRuler({
    super.key,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.initialValue,
  });

  @override
  State<OperationRuler> createState() => _OperationRulerState();
}

class _OperationRulerState extends State<OperationRuler> {
  late double value;

  String _format(double input) =>
      input.toStringAsFixed(widget.step < 1 ? 1 : 0);

  @override
  void initState() {
    super.initState();

    if (widget.controller.text.isNotEmpty) {
      value = double.tryParse(widget.controller.text) ?? widget.initialValue;
    } else {
      value = widget.initialValue;
      widget.controller.text = _format(value);
    }
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant OperationRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _handleControllerChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final updated = double.tryParse(widget.controller.text);
    if (!mounted || updated == null || updated == value) return;
    setState(() => value = updated.clamp(widget.min, widget.max).toDouble());
  }

  void update(double delta) {
    value += delta;

    if (value < widget.min) value = widget.min;
    if (value > widget.max) value = widget.max;

    value = (value / widget.step).roundToDouble() * widget.step;

    widget.controller.text = _format(value);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return HUDRuler(value: value, unit: widget.unit, onDrag: update);
  }
}
