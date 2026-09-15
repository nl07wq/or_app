import 'package:flutter/material.dart';

class OperationTextField extends StatelessWidget {
  final TextEditingController controller;

  final String? label;
  final String? hint;

  final TextInputType keyboardType;
  final int? minLines;
  final int maxLines;
  final FocusNode? focusNode;

  final ValueChanged<String>? onChanged;

  const OperationTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.minLines,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: (label == null || label!.isEmpty) ? null : label,
        hintText: hint,
      ),
    );
  }
}
