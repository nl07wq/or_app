import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OperationPicker extends StatefulWidget {
  final TextEditingController controller;

  final double min;
  final double max;
  final double step;

  final String unit;

  final ValueChanged<double>? onChanged;

  const OperationPicker({
    super.key,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    this.onChanged,
  });

  @override
  State<OperationPicker> createState() => _OperationPickerState();
}

class _OperationPickerState extends State<OperationPicker> {
  late FixedExtentScrollController _scrollController;

  late List<double> values;

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

    _scrollController = FixedExtentScrollController(
      initialItem: index < 0 ? 0 : index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CupertinoPicker(
        itemExtent: 40,
        scrollController: _scrollController,
        onSelectedItemChanged: (index) {
          final value = values[index];

          widget.controller.text = value.toStringAsFixed(1);

          widget.onChanged?.call(value);

          setState(() {});
        },
        children: values
            .map(
              (value) => Center(
                child: Text(
                  "${value.toStringAsFixed(1)} ${widget.unit}",
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
