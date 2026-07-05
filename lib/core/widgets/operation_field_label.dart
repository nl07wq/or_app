import 'package:flutter/material.dart';

class OperationFieldLabel extends StatelessWidget {
  final String text;

  const OperationFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}
