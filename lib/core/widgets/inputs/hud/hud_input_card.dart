import 'package:flutter/material.dart';

import '../operation_ruler.dart';

class HUDInputCard extends StatefulWidget {
  final String title;
  final String unit;

  final TextEditingController controller;

  final double min;
  final double max;
  final double step;

  final double initialValue;

  const HUDInputCard({
    super.key,
    required this.title,
    required this.unit,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
    required this.initialValue,
  });

  @override
  State<HUDInputCard> createState() => _HUDInputCardState();
}

class _HUDInputCardState extends State<HUDInputCard> {
  bool expanded = true;

  void collapse() {
    FocusScope.of(context).unfocus();

    setState(() {
      expanded = false;
    });
  }

  void expand() {
    setState(() {
      expanded = true;
    });
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
                onPressed: expand,
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
          OperationRuler(
            controller: widget.controller,
            min: widget.min,
            max: widget.max,
            step: widget.step,
            unit: widget.unit,
            initialValue: widget.initialValue,
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: collapse, child: const Text("完了")),
          ),
        ],
      ],
    );
  }
}
