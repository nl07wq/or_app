import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WheelSelector<T> extends StatefulWidget {
  final List<T> values;
  final Map<T, String> labels;

  final T value;
  final ValueChanged<T> onChanged;

  const WheelSelector({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  @override
  State<WheelSelector<T>> createState() => _WheelSelectorState<T>();
}

class _WheelSelectorState<T> extends State<WheelSelector<T>> {
  late FixedExtentScrollController _controller;

  late int selectedIndex;

  @override
  void initState() {
    super.initState();

    selectedIndex = widget.values.indexOf(widget.value);

    if (selectedIndex < 0) {
      selectedIndex = 0;
    }

    _controller = FixedExtentScrollController(initialItem: selectedIndex);
  }

  @override
  void didUpdateWidget(covariant WheelSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newIndex = widget.values.indexOf(widget.value);

    if (newIndex != selectedIndex && newIndex >= 0) {
      selectedIndex = newIndex;

      _controller.jumpToItem(newIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        scrollController: _controller,

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

          widget.onChanged(widget.values[index]);
        },

        children: List.generate(widget.values.length, (index) {
          final selected = index == selectedIndex;

          final value = widget.values[index];

          return Center(
            child: Text(
              widget.labels[value] ?? value.toString(),
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
