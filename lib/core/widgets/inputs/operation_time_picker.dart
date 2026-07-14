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

  int selectedHour = 7;
  int selectedMinute = 30;

  @override
  void initState() {
    super.initState();

    if (widget.controller.text.contains(":")) {
      final parts = widget.controller.text.split(":");

      hour = int.tryParse(parts[0]) ?? 7;
      minute = int.tryParse(parts[1]) ?? 30;
    }

    selectedHour = hour;
    selectedMinute = minute;

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

              useMagnifier: true,
              magnification: 1.15,
              diameterRatio: 1.4,

              selectionOverlay: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.lightBlueAccent, width: 2),
                    bottom: BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
              ),

              scrollController: FixedExtentScrollController(initialItem: hour),

              onSelectedItemChanged: (value) {
                setState(() {
                  hour = value;
                  selectedHour = value;
                  _updateController();
                });
              },

              children: List.generate(24, (index) {
                final selected = index == selectedHour;

                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: selected ? 28 : 20,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selected ? Colors.white : Colors.white54,
                    ),
                  ),
                );
              }),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ":",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,

              useMagnifier: true,
              magnification: 1.15,
              diameterRatio: 1.4,

              selectionOverlay: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.lightBlueAccent, width: 2),
                    bottom: BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
              ),

              scrollController: FixedExtentScrollController(
                initialItem: minute,
              ),

              onSelectedItemChanged: (value) {
                setState(() {
                  minute = value;
                  selectedMinute = value;
                  _updateController();
                });
              },

              children: List.generate(60, (index) {
                final selected = index == selectedMinute;

                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: selected ? 28 : 20,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selected ? Colors.white : Colors.white54,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
