import 'package:flutter/material.dart';

class RulerInput extends StatefulWidget {
  final TextEditingController controller;
  final double min;
  final double max;
  final double step;
  final String unit;

  const RulerInput({
    super.key,
    required this.controller,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
  });

  @override
  State<RulerInput> createState() => _RulerInputState();
}

class _RulerInputState extends State<RulerInput> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        return Column(
          children: [
            Text(
              "${value.text.isEmpty ? "--" : value.text} ${widget.unit}",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 70,
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: 1000,
                  itemBuilder: (context, index) {
                    final major = index % 10 == 0;

                    return SizedBox(
                      width: 10,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 2,
                          height: major ? 40 : 20,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
