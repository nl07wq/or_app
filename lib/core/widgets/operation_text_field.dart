import 'package:flutter/material.dart';

class OperationTextField extends StatelessWidget {
  final TextEditingController controller;

  final String? label;
  final String? hint;

  final TextInputType keyboardType;
  final int maxLines;

  const OperationTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: (label == null || label!.isEmpty) ? null : label,
        hintText: hint,
      ),
    );
  }
}
