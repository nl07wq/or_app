import 'package:flutter/material.dart';

import 'wheel_ruler.dart';

class WheelInputCard extends StatefulWidget {
  final String title;
  final String unit;

  final TextEditingController controller;

  final double min;
  final double max;
  final double step;

  final double? initialValue;

  /// 数値→表示名
  final Map<int, String>? labels;

  const WheelInputCard({
    super.key,
    required this.title,
    required this.unit,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
    this.initialValue,
    this.labels,
  });

  @override
  State<WheelInputCard> createState() => _WheelInputCardState();
}

class _WheelInputCardState extends State<WheelInputCard> {
  bool expanded = true;

  String _displayValue() {
    if (widget.controller.text.isEmpty) return "";

    final value = double.tryParse(widget.controller.text);

    if (value == null) return widget.controller.text;

    if (widget.labels != null) {
      return widget.labels![value.toInt()] ?? widget.controller.text;
    }

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            if (!expanded && widget.controller.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() => expanded = true);
                },
                child: Text(
                  "${_displayValue()} ${widget.unit}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ),
          ],
        ),

        if (expanded) ...[
          WheelRuler(
            controller: widget.controller,
            min: widget.min,
            max: widget.max,
            step: widget.step,
            unit: widget.unit,
            initialValue: widget.initialValue,
            labels: widget.labels,
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                setState(() => expanded = false);
              },
              child: const Text("完了"),
            ),
          ),
        ],
      ],
    );
  }
}
