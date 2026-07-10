import 'package:flutter/material.dart';

class RulerInput extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Column(
          children: [
            Text(
              "${value.text.isEmpty ? "--" : value.text} $unit",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: 500,
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
          ],
        );
      },
    );
  }
}
