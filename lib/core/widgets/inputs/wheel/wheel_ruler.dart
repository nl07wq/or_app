import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WheelRuler extends StatefulWidget {
  final TextEditingController controller;

  final double min;
  final double max;
  final double step;

  final String unit;

  final ValueChanged<double>? onChanged;

  const WheelRuler({
    super.key,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    this.onChanged,
  });

  @override
  State<WheelRuler> createState() => _WheelRulerState();
}

class _WheelRulerState extends State<WheelRuler> {
  late FixedExtentScrollController _scrollController;

  late List<double> values;

  late int selectedIndex;

  @override
  void initState() {
    super.initState();

    values = [];

    for (double v = widget.min; v <= widget.max + 0.0001; v += widget.step) {
      values.add(double.parse(v.toStringAsFixed(1)));
    }

    double initialValue = widget.min;

    if (widget.controller.text.isNotEmpty) {
      initialValue = double.tryParse(widget.controller.text) ?? widget.min;
    }

    final index = values.indexWhere((e) => (e - initialValue).abs() < 0.0001);

    selectedIndex = index < 0 ? 0 : index;

    _scrollController = FixedExtentScrollController(initialItem: selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CupertinoPicker(
        itemExtent: 40,

        useMagnifier: true,
        magnification: 1.15,
        diameterRatio: 1.4,
        scrollController: _scrollController,

        selectionOverlay: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.lightBlueAccent, width: 2),
              bottom: BorderSide(color: Colors.lightBlueAccent, width: 2),
            ),
          ),
        ),
        onSelectedItemChanged: (index) {
          setState(() {
            selectedIndex = index;
          });
          final value = values[index];

          widget.controller.text = value.toStringAsFixed(1);

          widget.onChanged?.call(value);

          setState(() {});
        },
        children: List.generate(values.length, (index) {
          final value = values[index];

          final selected = index == selectedIndex;

          return Center(
            child: Text(
              "${value.toStringAsFixed(1)} ${widget.unit}",
              style: TextStyle(
                fontSize: selected ? 28 : 20,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          );
        }),
      ),
    );
  }
}
