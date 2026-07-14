import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OperationTimePicker extends StatefulWidget {
  final TextEditingController controller;

  const OperationTimePicker({super.key, required this.controller});

  @override
  State<OperationTimePicker> createState() => _OperationTimePickerState();
}

class _OperationTimePickerState extends State<OperationTimePicker> {
  int hour = 7;
  int minute = 30;

  @override
  void initState() {
    super.initState();

    if (widget.controller.text.contains(":")) {
      final parts = widget.controller.text.split(":");

      hour = int.tryParse(parts[0]) ?? 7;
      minute = int.tryParse(parts[1]) ?? 30;
    }

    _updateController();
  }

  void _updateController() {
    widget.controller.text = "$hour:${minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(initialItem: hour),
              onSelectedItemChanged: (value) {
                setState(() {
                  hour = value;
                  _updateController();
                });
              },
              children: List.generate(
                24,
                (index) => Center(
                  child: Text(
                    index.toString(),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          const Text(":", style: TextStyle(fontSize: 28)),
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: minute,
              ),
              onSelectedItemChanged: (value) {
                setState(() {
                  minute = value;
                  _updateController();
                });
              },
              children: List.generate(
                60,
                (index) => Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
