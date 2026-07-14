import 'package:flutter/material.dart';

import 'wheel_ruler.dart';

class WheelInputCard extends StatefulWidget {
  final String title;
  final String unit;

  final TextEditingController controller;

  final double min;
  final double max;
  final double step;

  const WheelInputCard({
    super.key,
    required this.title,
    required this.unit,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
  });

  @override
  State<WheelInputCard> createState() => _WheelInputCardState();
}

class _WheelInputCardState extends State<WheelInputCard> {
  bool expanded = true;

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
                  "${widget.controller.text} ${widget.unit}",
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
