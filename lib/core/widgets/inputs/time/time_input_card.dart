import 'package:flutter/material.dart';

import 'operation_time_picker.dart';

class TimeInputCard extends StatefulWidget {
  final String title;
  final TextEditingController controller;

  /// 分刻み
  final int minuteStep;

  const TimeInputCard({
    super.key,
    required this.title,
    required this.controller,
    this.minuteStep = 1,
  });

  @override
  State<TimeInputCard> createState() => _TimeInputCardState();
}

class _TimeInputCardState extends State<TimeInputCard> {
  bool expanded = true;

  void collapse() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!mounted) return;

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
                  widget.controller.text,
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
          OperationTimePicker(
            controller: widget.controller,
            minuteStep: widget.minuteStep,
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
