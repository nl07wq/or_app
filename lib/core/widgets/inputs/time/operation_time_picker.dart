import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OperationTimePicker extends StatefulWidget {
  final TextEditingController controller;

  /// 分刻み
  final int minuteStep;

  final int initialHour;
  final int initialMinute;

  const OperationTimePicker({
    super.key,
    required this.controller,
    this.minuteStep = 1,
    this.initialHour = 0,
    this.initialMinute = 0,
  });

  @override
  State<OperationTimePicker> createState() => _OperationTimePickerState();
}

class _OperationTimePickerState extends State<OperationTimePicker> {
  late int hour;
  late int selectedMinute;

  late FixedExtentScrollController hourController;
  late FixedExtentScrollController minuteController;

  @override
  void initState() {
    super.initState();

    _loadFromController();

    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);

    hourController.dispose();
    minuteController.dispose();

    super.dispose();
  }

  void _loadFromController() {
    if (widget.controller.text.contains(":")) {
      final parts = widget.controller.text.split(":");

      hour = int.tryParse(parts[0]) ?? widget.initialHour;

      final minute = int.tryParse(parts[1]) ?? widget.initialMinute;

      selectedMinute = minute ~/ widget.minuteStep;
    } else {
      hour = widget.initialHour;
      selectedMinute = widget.initialMinute ~/ widget.minuteStep;

      widget.controller.text =
          "$hour:${(selectedMinute * widget.minuteStep).toString().padLeft(2, '0')}";
    }

    hourController = FixedExtentScrollController(initialItem: hour);

    minuteController = FixedExtentScrollController(initialItem: selectedMinute);
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (!widget.controller.text.contains(":")) return;

    final parts = widget.controller.text.split(":");

    final newHour = int.tryParse(parts[0]) ?? widget.initialHour;

    final newMinute =
        (int.tryParse(parts[1]) ?? widget.initialMinute) ~/ widget.minuteStep;

    if (newHour == hour && newMinute == selectedMinute) {
      return;
    }

    hour = newHour;
    selectedMinute = newMinute;

    hourController.jumpToItem(hour);
    minuteController.jumpToItem(selectedMinute);

    setState(() {});
  }

  void _updateController() {
    final minute = selectedMinute * widget.minuteStep;

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
              scrollController: hourController,
              selectionOverlay: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.lightBlueAccent, width: 2),
                    bottom: BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
              ),
              onSelectedItemChanged: (value) {
                hour = value;
                _updateController();
              },
              children: List.generate(
                24,
                (index) => Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: index == hour ? 28 : 20,
                      fontWeight: index == hour
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: index == hour ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ),
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
              scrollController: minuteController,
              selectionOverlay: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.lightBlueAccent, width: 2),
                    bottom: BorderSide(color: Colors.lightBlueAccent, width: 2),
                  ),
                ),
              ),
              onSelectedItemChanged: (value) {
                selectedMinute = value;
                _updateController();
              },
              children: List.generate(60 ~/ widget.minuteStep, (index) {
                final displayMinute = index * widget.minuteStep;

                return Center(
                  child: Text(
                    displayMinute.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: index == selectedMinute ? 28 : 20,
                      fontWeight: index == selectedMinute
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: index == selectedMinute
                          ? Colors.white
                          : Colors.white54,
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
