import 'package:flutter/material.dart';

import 'wheel_selector.dart';

class WheelSelectorCard<T> extends StatefulWidget {
  final String title;

  final List<T> values;

  final Map<T, String> labels;

  final T value;

  final ValueChanged<T> onChanged;

  const WheelSelectorCard({
    super.key,
    required this.title,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  @override
  State<WheelSelectorCard<T>> createState() => _WheelSelectorCardState<T>();
}

class _WheelSelectorCardState<T> extends State<WheelSelectorCard<T>> {
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

            if (!expanded)
              TextButton(
                onPressed: () {
                  setState(() {
                    expanded = true;
                  });
                },
                child: Text(
                  widget.labels[widget.value] ?? "",
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
          WheelSelector<T>(
            values: widget.values,
            labels: widget.labels,
            value: widget.value,
            onChanged: widget.onChanged,
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  expanded = false;
                });
              },
              child: const Text("完了"),
            ),
          ),
        ],
      ],
    );
  }
}
